#!/usr/bin/env python3
"""Install four role-specific fonts from a pinned official Google Fonts revision.

The repository distributes this installer, not font binaries. Downloads go
straight from the official source to the destination chosen by the user.
Requires fonttools. See skin_v2_fonts.command for an isolated installation.
"""
from __future__ import annotations
import argparse
import hashlib
import io
import json
import os
import sys
import tempfile
import urllib.parse
import urllib.request
from pathlib import Path

REVISION = 'bd8f81ddb5c74d5c8897b36ad88b440266245103'
ROOT = 'https://raw.githubusercontent.com/google/fonts/' + REVISION + '/ofl/'
REQUIRED = '\u0131\u0130\u015f\u015e\u011f\u011e\u00e7\u00c7\u00f6\u00d6\u00fc\u00dc0123456789'
SPECS = {
    'font_title.ttf': ('cinzel', 'Cinzel[wght].ttf', {'wght': 700}, 'Cinzel Bold'),
    'font.ttf': ('nunitosans', 'NunitoSans[YTLC,opsz,wdth,wght].ttf',
                 {'wght': 600, 'wdth': 100, 'opsz': 12}, 'Nunito Sans SemiBold'),
    'font_numbers.ttf': ('lilitaone', 'LilitaOne-Regular.ttf', {}, 'Lilita One'),
    'font_card.ttf': ('cinzel', 'Cinzel[wght].ttf', {'wght': 600}, 'Cinzel SemiBold'),
}

def fetch(url: str) -> bytes:
    request = urllib.request.Request(url, headers={'User-Agent': 'DestanDiyarlari-SkinFonts/2'})
    with urllib.request.urlopen(request, timeout=40) as response:
        if response.geturl().split('/')[2] != 'raw.githubusercontent.com':
            raise RuntimeError('Unexpected font download host')
        data = response.read(12_000_001)
    if not data or len(data) > 12_000_000:
        raise RuntimeError('Empty or oversized source: ' + url)
    return data

def atomic_write(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=path.name + '.', dir=path.parent)
    try:
        with os.fdopen(fd, 'wb') as file:
            file.write(data)
            file.flush()
            os.fsync(file.fileno())
        os.replace(tmp, path)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)

def install(destination: Path, replace: bool = False) -> dict:
    from fontTools.ttLib import TTFont
    from fontTools.varLib.instancer import instantiateVariableFont
    from fontTools.pens.recordingPen import RecordingPen
    destination = destination.resolve()
    pending: dict[str, bytes] = {}
    cache: dict[str, bytes] = {}
    report: dict = {'revision': REVISION, 'required_characters': REQUIRED,
                    'font_binaries_distributed_in_art_package': False, 'fonts': {}}
    # Validate every font before replacing any existing file.
    for target, (family, filename, axes, display_name) in SPECS.items():
        path = family + '/' + filename
        url = ROOT + urllib.parse.quote(path, safe='/')
        if path not in cache:
            cache[path] = fetch(url)
        font = TTFont(io.BytesIO(cache[path]), recalcTimestamp=False)
        if 'fvar' in font:
            limits = {axis.axisTag: axes.get(axis.axisTag, axis.defaultValue)
                      for axis in font['fvar'].axes}
            font = instantiateVariableFont(font, limits, inplace=False)
        cmap = font.getBestCmap() or {}
        missing = [char for char in REQUIRED if ord(char) not in cmap]
        if missing:
            raise RuntimeError(display_name + ' is missing: ' + repr(''.join(missing)))
        distinct = True
        if target == 'font_numbers.ttf':
            glyphs = font.getGlyphSet()
            one, letter_i = RecordingPen(), RecordingPen()
            glyphs[cmap[ord('1')]].draw(one)
            glyphs[cmap[ord('I')]].draw(letter_i)
            distinct = one.value != letter_i.value
            if not distinct:
                raise RuntimeError('Digit 1 and Latin I have the same outline')
        output = io.BytesIO()
        font.save(output)
        data = output.getvalue()
        installed = destination / target
        if installed.exists() and installed.read_bytes() != data and not replace:
            raise RuntimeError(str(installed) + ' exists. Back it up, then use --replace.')
        pending[target] = data
        license_path = family + '/OFL.txt'
        if license_path not in cache:
            cache[license_path] = fetch(ROOT + license_path)
        pending['licenses/' + family + '-OFL.txt'] = cache[license_path]
        report['fonts'][target] = {
            'family_and_weight': display_name, 'source_url': url,
            'source_sha256': hashlib.sha256(cache[path]).hexdigest(),
            'installed_sha256': hashlib.sha256(data).hexdigest(),
            'glyph_count': len(cmap), 'turkish_and_digits_covered': not missing,
            'digit_one_distinct_from_latin_I': distinct,
            'static_font': 'fvar' not in font,
        }
    for name, data in pending.items():
        atomic_write(destination / name, data)
    atomic_write(destination / 'fonts-installed.json',
                 (json.dumps(report, ensure_ascii=False, indent=2) + '\n').encode('utf-8'))
    return report

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--dest', type=Path,
                        default=Path(__file__).resolve().parents[1] / 'native' / 'skin')
    parser.add_argument('--replace', action='store_true', help='Replace existing font files after all checks pass')
    parser.add_argument('--report', type=Path, help='Also save the non-binary validation report here')
    args = parser.parse_args()
    try:
        report = install(args.dest, args.replace)
        if args.report:
            atomic_write(args.report, (json.dumps(report, ensure_ascii=False, indent=2) + '\n').encode())
    except ImportError:
        print('Install fonttools in a virtual environment, or run skin_v2_fonts.command.', file=sys.stderr)
        return 2
    except Exception as exc:
        print('Font installation failed: ' + str(exc), file=sys.stderr)
        return 1
    print('Installed and validated four fonts in ' + str(args.dest.resolve()))
    print('Turkish letters and digits verified; numeral 1 is not Latin I.')
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
