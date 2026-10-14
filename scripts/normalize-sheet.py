#!/usr/bin/env python3
"""Yatay animasyon şeridini düzenler: her kareyi saydam sınırına göre kırpar,
ortak yüksekliğe ölçekler, ayakları aynı zemin çizgisine ve ortaya hizalar.
Kullanım: normalize-sheet.py girdi.png çıktı.png [kare_sayısı] [kare_px]"""
import sys
from PIL import Image

def main():
    src, dst = sys.argv[1], sys.argv[2]
    count = int(sys.argv[3]) if len(sys.argv) > 3 else 4
    cell = int(sys.argv[4]) if len(sys.argv) > 4 else 256
    im = Image.open(src).convert('RGBA')
    fw = im.width / count
    frames = []
    for i in range(count):
        f = im.crop((round(i * fw), 0, round((i + 1) * fw), im.height))
        a = f.split()[3].point(lambda v: 255 if v > 24 else 0)
        box = a.getbbox()
        frames.append(f.crop(box) if box else None)
    valid = [f for f in frames if f is not None]
    if len(valid) < count:
        print('EKSIK_KARE', src, len(valid)); sys.exit(2)
    # yönü ters çizilmiş kareyi ilk kareye göre aynala
    import numpy as np
    from PIL import ImageOps
    def sig(img):
        return np.asarray(img.convert('L').resize((48, 48)), dtype=np.float32)
    ref = sig(frames[0])
    flipped = []
    for i in range(1, count if 'walk_' in src else 1):
        same = np.mean((sig(frames[i]) - ref) ** 2)
        mirror = np.mean((sig(ImageOps.mirror(frames[i])) - ref) ** 2)
        if mirror < same * 0.8:
            frames[i] = ImageOps.mirror(frames[i])
            flipped.append(i)
    if flipped:
        print('AYNALANDI', src, flipped)
    valid = frames
    # ortak ölçek: en yüksek kare hücrenin %90'ına sığsın, genişlik de taşmasın
    maxh = max(f.height for f in valid)
    maxw = max(f.width for f in valid)
    scale = min(cell * 0.9 / maxh, cell * 0.96 / maxw)
    out = Image.new('RGBA', (cell * count, cell), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        w, h = max(1, round(f.width * scale)), max(1, round(f.height * scale))
        g = f.resize((w, h), Image.LANCZOS)
        x = i * cell + (cell - w) // 2
        y = cell - h - round(cell * 0.04)
        out.alpha_composite(g, (x, y))
    out.save(dst, optimize=True)
    hs = [round(f.height * scale) for f in valid]
    print('OK', src, 'yükseklikler', hs)

main()
