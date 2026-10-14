"""Read-only verification of delivered assets and deterministic source packing.

No network, regeneration, writes, fonts, audio, or gameplay changes. Technical
validation is not a replacement for renderer screenshots or device review.
"""
from pathlib import Path
import hashlib
import json
from PIL import Image
import prepare_lane_refresh_final as pipeline


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    root = Path(__file__).resolve().parents[1]
    manifest = json.loads((root/'native/skin/manifest_lane_refresh.json').read_text())
    for name, row in manifest['assets'].items():
        path = root/row['file']
        source = root/row['source_file']
        assert sha(path) == row['sha256'], 'Output hash mismatch: '+name
        assert sha(source) == row['source_sha256'], 'Source hash mismatch: '+name
        size = tuple(row['size'])
        with Image.open(source) as original, Image.open(path) as delivered:
            assert list(original.size) == row['source_size'], name
            rebuilt, geometry = pipeline.pack.assemble(original, size)
            assert delivered.mode == 'RGBA' and delivered.size == size, name
            assert rebuilt.tobytes() == delivered.tobytes(), 'Non-reproducible pixels: '+name
            qa = pipeline.pack.check_image(delivered, size)
            assert qa['chroma_green_suspect_pixels_at_boundary'] == 0, name
            assert geometry['runtime_h3_caps'] == row['runtime_h3_caps'], name
        print(name, 'RGBA/alpha/source/output/pixel-reproduction OK; opaque color candidates:', qa['opaque_green_candidate_count'])
    for relative, name in [('native/skin/manifest.json','lane.png'),('native/skin/manifest_v2.json','lane_enemy.png')]:
        row = json.loads((root/relative).read_text())['assets'][name]
        assert row['sha256'] == manifest['assets'][name]['sha256'], relative
        assert row['mode'] == 'RGBA' and row['size'] == [1024,400], relative
    expected = json.loads((root/'dokumanlar/skin_v2_expected.json').read_text())
    for name, size in expected.items():
        with Image.open(root/'native/skin'/name) as image:
            assert list(image.size) == size, name
            image.verify()
    for relative in ['native/mobile.gd','native/landscape_match.gd']:
        code = (root/relative).read_text()
        assert '"h3", Vector4(246, 0, 246, 0)' in code, relative
    print('All %d original package PNGs intact; three delivered assets verified.' % len(expected))


if __name__ == '__main__':
    main()
