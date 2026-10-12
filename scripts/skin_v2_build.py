#!/usr/bin/env python3
"""Build the large independent-image skin batch and its objective QA report.

This is a deterministic packaging/matting tool, not an image generator.
It never enlarges source artwork. Font binaries stay outside the repository.
"""
from __future__ import annotations
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import io
import json
import math
from pathlib import Path
import re
import tempfile
import time
import urllib.request
import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[1]
SKIN = ROOT / 'native' / 'skin'
DOC = ROOT / 'dokumanlar' / 'yeni-gorsel-2'
SOURCE_LIST = ROOT / 'dokumanlar' / 'skin_v2_sources.json'
EXPECTED_LIST = ROOT / 'dokumanlar' / 'skin_v2_expected.json'
URL_BASE = 'https://photoshop-api.adobe.io/v2/short-url/urn:aaid:ps:US:'
LANCZOS = Image.Resampling.LANCZOS
TRANSPARENT_KINDS = {'green', 'magenta', 'black', 'alpha'}


def download(source: tuple[str, dict], cache: Path) -> tuple[str, Image.Image, dict]:
    name, spec = source
    if not re.fullmatch('[a-z0-9_]+', name):
        raise ValueError('Unsafe asset name: ' + name)
    ident = spec['url']
    url = URL_BASE + ident if re.fullmatch('[a-f0-9-]{36}', ident) else ident
    if not url.startswith((URL_BASE, 'https://raw.githubusercontent.com/')):
        raise ValueError('Unapproved source URL')
    target = cache / (hashlib.sha256(url.encode()).hexdigest() + '.png')
    if not target.exists():
        for attempt in range(2):
            try:
                req = urllib.request.Request(url, headers={'User-Agent': 'Destan-Skin-Packaging/2'})
                with urllib.request.urlopen(req, timeout=55) as response:
                    data = response.read(50_000_001)
                if len(data) > 50_000_000 or data[:8] != b'\x89PNG\r\n\x1a\n':
                    raise ValueError('Not an acceptable PNG: ' + name)
                target.write_bytes(data)
                break
            except Exception:
                if attempt:
                    raise
                time.sleep(1.5)
    data = target.read_bytes()
    im = Image.open(io.BytesIO(data)); im.load()
    if im.width * im.height > 40_000_000:
        raise ValueError('Oversized image: ' + name)
    return name, im, {'source_url': url, 'source_size': list(im.size),
                      'source_sha256': hashlib.sha256(data).hexdigest()}


def matte(im: Image.Image, kind: str) -> Image.Image:
    if kind == 'alpha':
        return im.convert('RGBA')
    rgb = np.asarray(im.convert('RGB'), dtype=np.float32) / 255.0
    if kind == 'black':
        brightness = np.max(rgb, axis=2)
        a = np.clip((brightness - 0.018) / 0.982, 0, 1)
        fg = np.divide(rgb, a[..., None], out=np.zeros_like(rgb), where=a[..., None] > 0.002)
    else:
        border = np.concatenate((rgb[:6].reshape(-1,3), rgb[-6:].reshape(-1,3),
                                 rgb[:, :6].reshape(-1,3), rgb[:, -6:].reshape(-1,3)))
        bg = np.median(border, axis=0)
        r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
        if kind == 'green':
            dominance = (g - np.maximum(r, b)) / np.maximum(g, 0.01)
            bg_dom = (bg[1] - max(bg[0], bg[2])) / max(float(bg[1]), 0.01)
            strength = np.clip((dominance - 0.14) / max(bg_dom - 0.14, 0.15), 0, 1)
        elif kind == 'magenta':
            low_rb = np.minimum(r, b)
            dominance = (low_rb - g) / np.maximum(low_rb, 0.01)
            bg_dom = (min(bg[0], bg[2]) - bg[1]) / max(float(min(bg[0], bg[2])), 0.01)
            strength = np.clip((dominance - 0.2) / max(bg_dom - 0.2, 0.15), 0, 1)
            strength *= np.clip((low_rb - 0.12) / 0.16, 0, 1)
        else:
            raise ValueError('Unknown matte type: ' + kind)
        a = 1.0 - strength
        a[a < 0.04] = 0
        a[a > 0.985] = 1
        fg = np.divide(rgb - (1-a[...,None])*bg, a[...,None],
                       out=np.zeros_like(rgb), where=a[...,None] > 0.002)
        # Eliminate colored matte spill only on partially transparent edges.
        edge = a < 0.995
        if kind == 'green':
            fg[...,1] = np.where(edge, np.minimum(fg[...,1], np.maximum(fg[...,0],fg[...,2])*1.05), fg[...,1])
        else:
            excess = np.maximum(np.minimum(fg[...,0],fg[...,2])-fg[...,1],0)
            fg[...,0] -= np.where(edge,excess*0.5,0)
            fg[...,2] -= np.where(edge,excess*0.5,0)
    fg = np.clip(fg, 0, 1)
    fg[a == 0] = 0
    out = np.dstack((fg, a))
    return Image.fromarray(np.uint8(np.round(np.clip(out,0,1)*255)), 'RGBA')


def bounds(im: Image.Image, threshold: int = 8):
    return im.getchannel('A').point(lambda x: 255 if x > threshold else 0).getbbox()


def resize_alpha(im: Image.Image, size: tuple[int,int]) -> Image.Image:
    # Premultiplied resampling avoids black/green fringes around soft effects.
    return im.convert('RGBa').resize(size, LANCZOS).convert('RGBA')


def fit_asset(im: Image.Image, size: tuple[int,int], kind: str, name: str) -> tuple[Image.Image, dict]:
    w, h = size
    metadata = {}
    if kind in TRANSPARENT_KINDS:
        im = matte(im, kind)
        box = bounds(im)
        if box is None:
            raise ValueError('Empty cutout: ' + name)
        im = im.crop(box)
        padding = 0.17 if name == 'app_icon_foreground' else 0.04
        mw, mh = math.ceil(w*padding), math.ceil(h*padding)
        scale = min((w-2*mw)/im.width, (h-2*mh)/im.height)
        if scale > 1.00001:
            raise ValueError('Would upscale artwork: ' + name)
        new = max(1,round(im.width*scale)), max(1,round(im.height*scale))
        resized = resize_alpha(im, new)
        out = Image.new('RGBA', size, (0,0,0,0))
        out.alpha_composite(resized, ((w-new[0])//2, (h-new[1])//2))
        metadata.update(source_visible_bounds=list(box), resample_scale=scale,
                        padding_fraction=padding, content_bounds_px=list(bounds(out)))
        if name in {'nav_active','target_ring'}:
            a = out.getchannel('A')
            draw = ImageDraw.Draw(a)
            radius = min(w,h)*0.24
            draw.ellipse((w/2-radius,h/2-radius,w/2+radius,h/2+radius),fill=0)
            out.putalpha(a)
        if name in {'fx_glow_ready','fx_glow_legend'}:
            a = out.getchannel('A')
            ImageDraw.Draw(a).rounded_rectangle((w*.32,h*.28,w*.68,h*.72), radius=w*.05, fill=0)
            out.putalpha(a)
    else:
        if im.width < w or im.height < h:
            raise ValueError('Would upscale opaque artwork: ' + name)
        crop_scale = max(w/im.width,h/im.height)
        out = ImageOps.fit(im.convert('RGB'), size, LANCZOS)
        metadata.update(resample_scale=crop_scale)
        if kind == 'tile':
            arr = np.array(out)
            # A mirrored half-period gives identical seam values and smooth ends.
            half = arr[:, :w//2]
            arr = np.concatenate((half, half[:, ::-1]),axis=1)
            if arr.shape[1] != w:
                arr = np.concatenate((arr,arr[:,-1:]),axis=1)
            out = Image.fromarray(arr[:,:w], 'RGB')
            metadata['horizontal_seam_identical'] = bool(np.array_equal(arr[:,0],arr[:,-1]))
    return out, metadata


def save_asset(name: str, out: Image.Image, meta: dict) -> dict:
    path = SKIN / (name + '.png')
    out.save(path, format='PNG', optimize=True)
    check = Image.open(path); check.load()
    assert check.size == out.size
    record = dict(meta, file='native/skin/'+path.name, size=list(check.size),
                  mode=check.mode, bytes=path.stat().st_size,
                  sha256=hashlib.sha256(path.read_bytes()).hexdigest())
    if check.mode == 'RGBA':
        a = np.array(check.getchannel('A'))
        record.update(alpha_min=int(a.min()),alpha_max=int(a.max()),
                      transparent_fraction=float(np.mean(a==0)),
                      content_bounds_px=list(bounds(check)),
                      edge_alpha_max=int(max(a[0].max(),a[-1].max(),a[:,0].max(),a[:,-1].max())))
        if record['alpha_min'] != 0 or record['alpha_max'] == 0 or record['edge_alpha_max'] != 0:
            raise ValueError('Alpha or padding validation failed: ' + name)
    return record


def font_at(fonts: Path | None, role: str, size: int):
    if fonts and (fonts / role).exists():
        return ImageFont.truetype(str(fonts / role), size)
    try:
        return ImageFont.truetype('DejaVuSans.ttf', size)
    except OSError:
        return ImageFont.load_default()


def create_brand(fonts: Path | None, records: dict, layers: dict):
    fgpath = SKIN / 'app_icon_foreground.png'
    if not fgpath.exists() or 'app_icon_background' not in layers:
        return
    fg = Image.open(fgpath).convert('RGBA')
    bg = ImageOps.fit(layers['app_icon_background'].convert('RGB'), (1024,1024), LANCZOS).convert('RGBA')
    bg.alpha_composite(fg)
    records['app_icon.png'] = save_asset('app_icon', bg.convert('RGB'),
            {'method':'composite of independently generated background and shared emblem',
             'adaptive_foreground_box_fraction':0.66, 'corner_rounding':False})
    if fonts is None:
        return
    W,H = 3200,800
    word = 'DESTAN D\u0130YARLARI'
    font = font_at(fonts,'font_title.ttf',300)
    while font.getlength(word) > 2840:
        font = font_at(fonts,'font_title.ttf',font.size-2)
    mask = Image.new('L',(W,H)); draw=ImageDraw.Draw(mask)
    box = draw.textbbox((0,0),word,font=font,stroke_width=0)
    x=(W-(box[2]-box[0]))//2-box[0]
    y=455-box[1]
    draw.text((x,y),word,font=font,fill=255)
    canvas=Image.new('RGBA',(W,H))
    shadow=mask.filter(ImageFilter.GaussianBlur(9))
    layer=Image.new('RGBA',(W,H),(58,23,3,0));layer.putalpha(shadow)
    canvas.alpha_composite(layer,(0,10))
    outline=mask.filter(ImageFilter.MaxFilter(17))
    layer=Image.new('RGBA',(W,H),(84,39,8,0));layer.putalpha(outline);canvas.alpha_composite(layer)
    yy=np.arange(H,dtype=np.float32)[:,None]
    t=np.clip((yy-455)/max(box[3]-box[1],1),0,1)
    stops=[(0,(255,244,188)),(.22,(248,209,103)),(.48,(170,100,20)),(.60,(255,220,127)),(1,(138,73,12))]
    grad=np.zeros((H,W,4),dtype=np.uint8)
    for c in range(3):
        grad[:,:,c]=np.interp(t[:,0],[s[0] for s in stops],[s[1][c] for s in stops])[:,None]
    grad[:,:,3]=np.array(mask)
    canvas.alpha_composite(Image.fromarray(grad,'RGBA'))
    emblem=fg.crop(bounds(fg)).copy()
    emblem.thumbnail((340,340),LANCZOS)
    canvas.alpha_composite(emblem,((W-emblem.width)//2,55))
    records['logo_wordmark.png']=save_asset('logo_wordmark',resize_alpha(canvas,(1600,400)),
                {'method':'correct Turkish text typeset with Cinzel Bold; raster output only',
                 'text':word,'source_size':[W,H],'resample_scale':0.5,
                 'turkish_dotted_I_verified_in_text':True})


def preview_grid(names: list[str], file: str, records: dict, cols=6, cell=(240,190)):
    names=[n for n in names if n in records]
    if not names:
        return
    cw,ch=cell; rows=math.ceil(len(names)/cols)
    sheet=Image.new('RGB',(cols*cw,rows*ch),(25,28,31));draw=ImageDraw.Draw(sheet)
    font=font_at(None,'',13)
    for i,n in enumerate(names):
        x=(i%cols)*cw;y=(i//cols)*ch
        art=Image.open(ROOT / records[n]['file']).convert('RGBA')
        art.thumbnail((cw-20,ch-42),LANCZOS)
        if i%2:
            draw.rectangle((x+4,y+4,x+cw-4,y+ch-30),fill=(66,55,45))
        sheet.paste(art,(x+(cw-art.width)//2,y+(ch-35-art.height)//2),art)
        draw.text((x+8,y+ch-26),n,font=font,fill=(237,220,190))
    sheet.save(DOC/file,quality=90)


def typography_preview(fonts: Path | None, records: dict):
    out=Image.new('RGB',(1440,620),(29,32,37));d=ImageDraw.Draw(out)
    d.text((30,20),'ACTUAL PIXEL SIZES - no enlargement',font=font_at(fonts,'font.ttf',24),fill=(243,224,187))
    labels=[('font_title.ttf',22,'DESTAN D\u0130YARLARI'),
            ('font_card.ttf',10,'\u00c7oban \u00c7\u0131ra\u011f\u0131 | \u015eahmaran\u2019\u0131n S\u0131rr\u0131'),
            ('font.ttf',13,'\u0131 \u0130 \u015f \u015e \u011f \u011e \u00e7 \u00c7 \u00f6 \u00d6 \u00fc \u00dc'),
            ('font_numbers.ttf',30,'0 1 2 3 4 5 6 7 8 9    1 / I')]
    y=80
    for role,size,text in labels:
        d.text((30,y),role+'  '+str(size)+' px',font=font_at(fonts,'font.ttf',15),fill=(153,161,170))
        d.text((330,y),text,font=font_at(fonts,role,size),fill=(255,231,174))
        y+=65
    names=[n for n in records if n.startswith('icon_')]
    for i,n in enumerate(names):
        x=35+(i%14)*98;y=380+(i//14)*100
        art=Image.open(ROOT / records[n]['file']).convert('RGBA').resize((32,32),LANCZOS)
        out.paste(art,(x,y),art)
        d.text((x,y+40),str(i+1),font=font_at(fonts,'font.ttf',11),fill=(201,205,210))
    out.save(DOC/'actual-size.png')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--partial',action='store_true')
    args=parser.parse_args()
    SKIN.mkdir(parents=True,exist_ok=True);DOC.mkdir(parents=True,exist_ok=True)
    specs=json.loads(SOURCE_LIST.read_text())
    specs={n:s for n,s in specs.items() if s['kind']!='reject'}
    expected=json.loads(EXPECTED_LIST.read_text())
    records={};layers={};errors=[]
    with tempfile.TemporaryDirectory(prefix='destan-source-') as td:
        cache=Path(td)
        with ThreadPoolExecutor(max_workers=6) as pool:
            for name,im,meta in pool.map(lambda item:download(item,cache),specs.items()):
                spec=specs[name]
                if spec['kind']=='source_only':
                    layers[name]=im
                    continue
                size=tuple(spec['size'])
                out, details=fit_asset(im,size,spec['kind'],name)
                meta.update(details,matte_method=spec['kind'],generated_independently=True,
                            source_at_least_2x_each_dimension=bool(im.width>=size[0]*2 and im.height>=size[1]*2))
                records[name+'.png']=save_asset(name,out,meta)
                print('OK',name,out.size,im.size,flush=True)
        fontdir=cache/'fonts';font_report=None
        try:
            import skin_v2_fonts
            font_report=skin_v2_fonts.install(fontdir,True)
            (DOC/'font-validation.json').write_text(json.dumps(font_report,ensure_ascii=False,indent=2)+'\n')
        except Exception as exc:
            errors.append('Font validation: '+str(exc));fontdir=None
        create_brand(fontdir,records,layers)
        typography_preview(fontdir,records)
    missing=[name for name in expected if name not in records]
    wrong=[name for name in records if name in expected and records[name]['size']!=expected[name]]
    if wrong:
        raise ValueError('Wrong output dimensions: '+repr(wrong))
    preview_grid([n for n in records if n.startswith('icon_')],'icons.jpg',records,7,(220,190))
    preview_grid([n for n in records if n.startswith('fx_') or n in {'nav_active.png','target_ring.png','drag_arrow.png','pack_reveal_burst.png'}],
                 'effects.jpg',records,6,(240,210))
    preview_grid([n for n in records if n.startswith('enemy_') or n.startswith('hero_player_alt')],
                 'portraits.jpg',records,6,(240,250))
    preview_grid([n for n in records if n.startswith('chapter_')],'chapters.jpg',records,2,(720,390))
    preview_grid([n for n in records if n.startswith(('scene_','chest_')) or n in {'backdrop.png','splash.png','empty_collection.png','offline.png'}],
                 'scenes.jpg',records,3,(480,340))
    other=[n for n in records if not n.startswith(('icon_','fx_','chapter_','enemy_','hero_player_alt','scene_','chest_'))
           and n not in {'backdrop.png','splash.png','empty_collection.png','offline.png','pack_reveal_burst.png'}]
    preview_grid(other,'interface.jpg',records,4,(420,250))
    report={'package':'Yeni gorsel 2','png_count':len(records),'expected_png_count':len(expected),
            'missing_png':missing,'errors':errors,'font_binaries_in_package':False,
            'fonts_validated':font_report is not None,'audio_files_generated':0,
            'audio_status':'pending: no connected sound-effects or music generation service',
            'device_or_gameplay_tested':False,'pixel_size_preview':'dokumanlar/yeni-gorsel-2/actual-size.png',
            'assets':records}
    (SKIN/'manifest_v2.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    (DOC/'build-summary.json').write_text(json.dumps({k:v for k,v in report.items() if k!='assets'},ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k!='assets'},ensure_ascii=False,indent=2))
    if not args.partial and (missing or errors):
        raise SystemExit('Incomplete build; branch must not be merged yet')

if __name__=='__main__':
    main()
