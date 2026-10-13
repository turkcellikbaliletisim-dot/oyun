#!/usr/bin/env python3
"""Check the game's decoded audio against its delivery specification."""
import argparse
from array import array
import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent

def command(*args):
    return subprocess.run(args, check=True, capture_output=True).stdout

def db(amplitude):
    return 20 * math.log10(max(amplitude, 1e-12))

def inspect(path, target, spec):
    probe = json.loads(command('ffprobe', '-v', 'error', '-show_streams', '-show_format', '-of', 'json', str(path)))
    stream = next(s for s in probe['streams'] if s['codec_type'] == 'audio')
    channels = int(stream['channels'])
    samples = array('f')
    samples.frombytes(command('ffmpeg', '-v', 'error', '-i', str(path), '-map', '0:a:0', '-ar', '44100', '-f', 'f32le', '-'))
    if sys.byteorder != 'little':
        samples.byteswap()
    oversampled = array('f')
    oversampled.frombytes(command('ffmpeg', '-v', 'error', '-i', str(path), '-map', '0:a:0', '-ar', '176400', '-f', 'f32le', '-'))
    if sys.byteorder != 'little':
        oversampled.byteswap()
    duration = float(probe['format']['duration'])
    peak = db(max(map(abs, oversampled), default=0))
    active = [x for x in samples if abs(x) > 0.0031623]
    rms = db(math.sqrt(sum(x*x for x in active) / len(active))) if active else -240
    errors = []
    if stream['codec_name'] != spec['codec'] or 'ogg' not in probe['format']['format_name']:
        errors.append('Expected OGG/Vorbis')
    if int(stream['sample_rate']) != spec['sample_rate']:
        errors.append('Expected 44100 Hz')
    if abs(duration - target['seconds']) > 0.02:
        errors.append('Duration differs by more than 20 ms')
    if peak >= spec['peak_dbfs_max']:
        errors.append('4x oversampled peak must be below -1 dBFS')
    if not active:
        errors.append('Audio is silent')
    result = {'file':path.name, 'duration_seconds':duration, 'decoded_seconds':len(samples)/channels/44100,
              'sample_rate':int(stream['sample_rate']), 'channels':channels, 'codec':stream['codec_name'],
              'peak_4x_dbfs':peak, 'active_rms_dbfs':rms, 'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
              'errors':errors}
    if target['loop'] and len(samples) >= channels * 2:
        result['loop_boundary_jump'] = max(abs(samples[channel] - samples[-channels+channel]) for channel in range(channels))
        result['loop_listening_required'] = True
        # A small sample jump alone cannot certify musical continuity.
    return result

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--directory', type=Path, default=ROOT/'native/skin/audio')
    parser.add_argument('--report', type=Path, default=ROOT/'native-builds/audio-quality-report.json')
    parser.add_argument('--effects-only', action='store_true')
    args = parser.parse_args()
    spec = json.loads((ROOT/'native/skin/audio/spec.json').read_text())
    if args.effects_only:
        spec['assets']=[target for target in spec['assets'] if not target['loop']]
    results = []
    for target in spec['assets']:
        path = args.directory/target['file']
        if not path.is_file():
            results.append({'file':path.name, 'errors':['Missing audio file']})
            continue
        try:
            results.append(inspect(path, target, spec))
        except (subprocess.CalledProcessError, ValueError, KeyError, StopIteration) as error:
            results.append({'file':path.name, 'errors':['Decode/probe failed: '+type(error).__name__]})
    effect_levels = [r['active_rms_dbfs'] for r,t in zip(results,spec['assets']) if not t['loop'] and 'active_rms_dbfs' in r]
    spread = max(effect_levels)-min(effect_levels) if effect_levels else None
    mix_ok = spread is not None and spread <= spec['sfx_rms_spread_db_max']
    report = {'scope':'effects' if args.effects_only else 'music_and_effects',
              'technical_pass':all(not r['errors'] for r in results) and mix_ok,
              'originality_not_verified':True, 'listening_acceptance_pending':True,
              'sfx_active_rms_spread_db':spread, 'sfx_mix_pass':mix_ok, 'files':results}
    args.report.parent.mkdir(parents=True,exist_ok=True)
    args.report.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    for result in results:
        print(result['file']+': '+('; '.join(result['errors']) or 'technical checks passed'))
    print('SFX RMS spread:',round(spread,2) if spread is not None else 'unavailable','dB')
    print('Report:',args.report)
    raise SystemExit(0 if report['technical_pass'] else 1)

if __name__ == '__main__':
    main()
