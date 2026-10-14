"""Pack three generated, Adobe-matted UI sources for the game's slice renderer.

This is game-specific horizontal three-slice assembly, not AI upscaling.
Corner pieces keep their aspect ratio; only the plain middle changes aspect.
All pieces are downsampled from their independently generated source pixels.
Run only on the isolated art branch; no fonts, audio or game rules are changed.
"""
from __future__ import annotations

import hashlib
import io
import json
import subprocess
import time
import urllib.request
from pathlib import Path

from PIL import Image, ImageStat

BRANCH = 'gorsel-kalite/serit-yenileme-20261013'
BASE = 'acf6f30562ebb24268ae703429ca5a1cfc5f3b15'
PREFIX = 'https://photoshop-api.adobe.io/v2/short-url/urn:aaid:ps:US:'
SPECS = {
    'lane.png': ((1024, 400), '47fddc85-8cc0-43d2-8859-56ea9ba8e3c9', '11e537b4-b345-4e4a-b9ec-eeb0ad15104c'),
    'lane_enemy.png': ((1024, 400), '1db5cec5-1c92-4904-ac8c-ff56404fd832', 'e9306f8e-6d6d-458d-b45e-5f13871140e9'),
    'loading_tip_panel.png': ((900, 160), 'e4b3b5cc-1e6b-4f69-890a-1ba30b3bebe4', 'befa0b0d-1230-4d2b-9712-ed57a8d88d56'),
}
OLD_HASHES = {
    'lane.png': 'd375d5d655afd525c7caa568af38a06824addcd765f4eb3354d4e04c564bf4b8',
    'lane_enemy.png': '1aff7154e6ab50677fa4de81b64bd2c1b9c8e37d4ec51a3921392e96904c4129',
}
SKIN = Path('native/skin')
SOURCES = Path('dokumanlar/serit-yenileme-kaynak')
REPORT = Path('dokumanlar/serit-yenileme-kontrol.json')


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def get_source(url: str) -> bytes:
    for attempt in range(2):
        try:
            req = urllib.request.Request(url, headers={'User-Agent': 'Destan-Asset-Review/1.0'})
            with urllib.request.urlopen(req, timeout=75) as response:
                data = response.read(32_000_001)
            if len(data) > 32_000_000 or not data.startswith(b'\x89PNG\r\n\x1a\n'):
                raise ValueError('Unexpected image response')
            return data
        except (OSError, ValueError):
            if attempt:
                raise
            time.sleep(2)
    raise RuntimeError('No source returned')


def assemble(source: Image.Image, size: tuple[int, int]) -> tuple[Image.Image, dict]:
    source = source.convert('RGBA')
    mask = source.getchannel('A').point(lambda v: 255 if v > 4 else 0)
    bbox = mask.getbbox()
    if bbox is None:
        raise ValueError('Empty source')
    art = source.crop(bbox)
    sw, sh = art.size
    w, h = size
    if source.width < 2*w or source.height < 2*h:
        raise ValueError('Generated canvas smaller than the requested 2x source')
    mx, my = round(w*.04), round(h*.04)
    bw, bh = w-2*mx, h-2*my
    cap = min(round(sh*.55), sw//3)
    dest_cap = round(cap*bh/sh)
    source_x = [0, cap, sw-cap, sw]
    target_x = [0, dest_cap, bw-dest_cap, bw]
    panel = Image.new('RGBA', (w, h))
    scales = []
    for index in range(3):
        part = art.crop((source_x[index], 0, source_x[index+1], sh))
        target = (target_x[index+1]-target_x[index], bh)
        if target[0] <= 0 or target[0] > part.width or target[1] > part.height:
            raise ValueError('Packing would enlarge or erase source pixels')
        scales.append([target[0]/part.width, target[1]/part.height])
        # Premultiplied-alpha resampling avoids dark fringes around transparent art.
        piece = part.convert('RGBa').resize(target, Image.Resampling.LANCZOS).convert('RGBA')
        panel.alpha_composite(piece, (mx+target_x[index], my))
    return panel, {
        'source_subject_bounds': list(bbox),
        'source_slice_cap': cap,
        'part_resample_scales_xy': scales,
        'content_rectangle': [mx, my, w-mx, h-my],
        'runtime_h3_caps': [mx+dest_cap, 0, mx+dest_cap, 0],
        'center_adapted_separately': True,
        'corner_aspect_preserved': True,
        'upscaled': False,
    }


def check_image(im: Image.Image, size: tuple[int, int]) -> dict:
    if im.size != size or im.mode != 'RGBA':
        raise ValueError('Incorrect output dimensions or mode')
    w, h = size
    alpha = im.getchannel('A')
    edges = [alpha.crop((0,0,w,1)), alpha.crop((0,h-1,w,h)), alpha.crop((0,0,1,h)), alpha.crop((w-1,0,w,h))]
    if any(edge.getextrema()[1] != 0 for edge in edges):
        raise ValueError('Artwork clipped at canvas edge')
    center = im.crop((round(w*.25), round(h*.30), round(w*.75), round(h*.70)))
    if center.getchannel('A').getextrema()[0] < 245:
        raise ValueError('Background removal damaged the painted center')
    suspicious = sum(1 for r,g,b,a in im.getdata() if a > 32 and g > 48 and g > r*1.7 and g > b*1.7)
    if suspicious > 8:
        raise ValueError('Possible chroma-green residue: %d pixels' % suspicious)
    return {
        'size': list(size), 'mode': im.mode,
        'alpha_bounds': list(alpha.point(lambda v: 255 if v > 4 else 0).getbbox()),
        'transparent_outer_edges': True,
        'painted_center_alpha_min': center.getchannel('A').getextrema()[0],
        'painted_center_mean_luminance': round(ImageStat.Stat(center.convert('L')).mean[0], 3),
        'chroma_green_suspect_pixels': suspicious,
    }


def json_write(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False)+'\n', encoding='utf-8')


def main() -> None:
    branch = subprocess.check_output(['git','branch','--show-current'], text=True).strip()
    if branch != BRANCH:
        raise RuntimeError('This preparer may only write the isolated art branch')
    if REPORT.exists():
        raise RuntimeError('Already prepared; review instead of regenerating unchanged assets')
    for name, expected in OLD_HASHES.items():
        if digest((SKIN/name).read_bytes()) != expected:
            raise RuntimeError('Concurrent change to '+name)
    if (SKIN/'loading_tip_panel.png').exists():
        raise RuntimeError('Do not overwrite an existing tip panel')
    result = {'source_base_commit': BASE, 'assets': {}, 'physical_device_test': False, 'gameplay_test': False, 'visual_acceptance': 'pending actual renderer inspection'}
    prepared = {}
    for name, (size, cutout_id, generation_id) in SPECS.items():
        data = get_source(PREFIX+cutout_id)
        with Image.open(io.BytesIO(data)) as im:
            im.load()
            output, geometry = assemble(im, size)
            source_size = list(im.size)
        qa = check_image(output, size)
        encoded = io.BytesIO()
        output.save(encoded, format='PNG', optimize=True)
        output_data = encoded.getvalue()
        with Image.open(io.BytesIO(output_data)) as reopened:
            reopened.verify()
        record = {
            'file': 'native/skin/'+name,
            'method': 'Independent Adobe Firefly illustration; Adobe background removal; game-specific three-slice packing with downsampling',
            'source_generation_url': PREFIX+generation_id,
            'source_cutout_url': PREFIX+cutout_id,
            'source_file': str(SOURCES/name),
            'source_size': source_size,
            'source_sha256': digest(data),
            'source_at_least_2x_each_dimension': True,
            'generated_independently': True,
            'sha256': digest(output_data), 'bytes': len(output_data),
            **geometry, **qa,
        }
        result['assets'][name] = record
        prepared[name] = (data, output_data)
    # Do not write any output until all three assets pass validation.
    SOURCES.mkdir(parents=True, exist_ok=True)
    for name, (data, output_data) in prepared.items():
        (SOURCES/name).write_bytes(data)
        (SKIN/name).write_bytes(output_data)
    for manifest_path, name in [(SKIN/'manifest.json','lane.png'), (SKIN/'manifest_v2.json','lane_enemy.png')]:
        manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
        old = manifest['assets'][name]
        manifest['assets'][name] = {**result['assets'][name], 'previous_revision': old, 'revision': '2026-10-13-lane-refresh'}
        json_write(manifest_path, manifest)
    json_write(SKIN/'manifest_lane_refresh.json', result)
    json_write(REPORT, result)
    # Both active render paths must preserve the newly rounded end caps.
    patches = {
        'native/mobile.gd': ('art_slice(strip, "lane_enemy.png" if lane_index == 0 else "lane.png", Rect2(), "p9", Vector4(90, 70, 90, 70), 0.3)', 'art_slice(strip, "lane_enemy.png" if lane_index == 0 else "lane.png", Rect2(), "h3", Vector4(246, 0, 246, 0))'),
        'native/landscape_match.gd': ('art_slice(strip, entry[3], Rect2(), "h3", Vector4(120, 0, 120, 0))', 'art_slice(strip, entry[3], Rect2(), "h3", Vector4(246, 0, 246, 0))'),
    }
    for filename, (old, new) in patches.items():
        path = Path(filename)
        text = path.read_text(encoding='utf-8')
        if text.count(old) != 1:
            raise RuntimeError('Unexpected renderer source; inspect instead of replacing: '+filename)
        path.write_text(text.replace(old, new), encoding='utf-8')
    print(json.dumps(result, indent=2, ensure_ascii=False))


if __name__ == '__main__':
    main()
