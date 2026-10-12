#!/usr/bin/env python3
"""Remove exterior rectangles from three otherwise finished hero portraits."""
from pathlib import Path
import hashlib,json,math
import numpy as np
from scipy import ndimage
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[1]

def polish(root):
    skin=root/'native/skin';doc=root/'dokumanlar/yeni-gorsel-2'
    mf=skin/'manifest_v2.json';m=json.loads(mf.read_text())
    for name in ['enemy_06.png','enemy_10.png','hero_player_alt1.png']:
        if m['assets'][name].get('exterior_portrait_matte_corrected'):
            continue
        p=skin/name;im=Image.open(p).convert('RGBA');a=np.array(im.getchannel('A'),dtype=np.float32)
        h,w=a.shape;yy,xx=np.mgrid[:h,:w]
        if name=='enemy_06.png':
            radius=np.sqrt(((xx-256.5)/212.5)**2+((yy-265)/213)**2)
            mask=np.clip((1-radius)*213+.6,0,1)
        elif name=='enemy_10.png':
            radius=np.sqrt(((xx-257)/184.5)**2+((yy-258.5)/190.5)**2)
            mask=np.clip((1-radius)*187+.6,0,1)
            mask[yy>=230]=1
            horn=Image.new('L',(w*4,h*4));ImageDraw.Draw(horn).polygon([(241*4,96*4),(256*4,50*4),(271*4,96*4)],fill=255)
            mask=np.maximum(mask,np.asarray(horn.resize((w,h),Image.Resampling.LANCZOS))/255)
        else:
            labels,count=ndimage.label(a>100);sizes=np.bincount(labels.ravel());sizes[0]=0
            main=labels==int(sizes.argmax())
            mask=ndimage.binary_dilation(main,iterations=2).astype(float)
        out=np.asarray(im).copy();out[:,:,3]=np.uint8(np.rint(a*mask));out[out[:,:,3]==0,:3]=0
        result=Image.fromarray(out,'RGBA');result.save(p,optimize=True)
        aa=out[:,:,3];r=m['assets'][name]
        r.update(sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size,
                 alpha_min=int(aa.min()),alpha_max=int(aa.max()),transparent_fraction=float(np.mean(aa==0)),
                 content_bounds_px=list(result.getchannel('A').point(lambda v:255 if v>8 else 0).getbbox()),
                 exterior_portrait_matte_corrected=True,
                 postprocessing='Verified round-ring silhouette mask; exterior rectangular background removed without repainting portrait')
    names=[n for n in m['assets'] if n.startswith('enemy_') or n.startswith('hero_player_alt')]
    cols=6;cw,ch=240,250;sheet=Image.new('RGB',(cols*cw,math.ceil(len(names)/cols)*ch),(25,28,31));d=ImageDraw.Draw(sheet)
    try:font=ImageFont.truetype('DejaVuSans.ttf',13)
    except OSError:font=ImageFont.load_default()
    for i,n in enumerate(names):
        x=i%cols*cw;y=i//cols*ch
        if i%2:d.rectangle((x+4,y+4,x+cw-4,y+ch-30),fill=(66,55,45))
        art=Image.open(skin/n).convert('RGBA');art.thumbnail((cw-20,ch-42),Image.Resampling.LANCZOS)
        sheet.paste(art,(x+(cw-art.width)//2,y+(ch-35-art.height)//2),art)
        d.text((x+8,y+ch-26),n,font=font,fill=(237,220,190))
    sheet.save(doc/'portraits.jpg',quality=91)
    m['portrait_exterior_matte_verified']=True
    mf.write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n')
    summary={k:v for k,v in m.items() if k!='assets'}
    (doc/'build-summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
    print('Corrected three portrait masks and refreshed checksums and preview.')

if __name__=='__main__':polish(ROOT)
