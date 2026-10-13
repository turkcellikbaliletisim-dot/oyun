#!/usr/bin/env python3
"""Fit generated effects to the delivery durations and a shared level.

Stages files only; does not replace the game's assets. Music is not synthesized.
"""
from array import array
import json
import math
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
RATE = 44100
CHANNELS = 2

def decode(path):
    raw = subprocess.run(['ffmpeg','-v','error','-i',str(path),'-ac','2','-ar',str(RATE),'-f','f32le','-'],check=True,capture_output=True).stdout
    samples = array('f')
    samples.frombytes(raw)
    if sys.byteorder != 'little': samples.byteswap()
    return samples

def level(samples):
    active = [x for x in samples if abs(x)>0.0031623]
    return math.sqrt(sum(x*x for x in active)/len(active)) if active else 0

def fit(samples, seconds):
    peak = max(map(abs,samples),default=0)
    if peak<0.001: raise ValueError('Silent source')
    threshold = max(0.001,peak*0.01)
    first = next(i for i in range(0,len(samples),CHANNELS) if max(abs(samples[i]),abs(samples[i+1]))>=threshold)
    first = max(0, first-CHANNELS*int(RATE*0.003))
    count = round(seconds*RATE)*CHANNELS
    result = array('f',samples[first:first+count])
    if len(result)<count: result.extend([0.0]*(count-len(result)))
    frames = count//CHANNELS
    fade = min(int(RATE*0.012),frames//8)
    for frame in range(fade):
        fade_in = math.sin((frame+1)/fade*math.pi/2)**2
        fade_out = math.sin(frame/fade*math.pi/2)**2
        for channel in range(CHANNELS):
            result[frame*CHANNELS+channel] *= fade_in
            result[(frames-frame-1)*CHANNELS+channel] *= fade_out
    return result

def main():
    specs=json.loads((ROOT/'native/skin/audio/spec.json').read_text())['assets']
    jobs={j['file']:j for j in json.loads((ROOT/'native-builds/audio-generation-jobs.json').read_text())}
    destination=ROOT/'native-builds/audio-ready'
    destination.mkdir(parents=True,exist_ok=True)
    prepared={}
    peak_ceiling=10**(-3/20) # Headroom for Vorbis intersample peaks.
    for spec in specs:
        if spec['loop']: continue
        source=ROOT/'native-builds/audio-sources'/spec['file'].replace('.ogg','.mp3')
        samples=fit(decode(source),spec['seconds'])
        rms=level(samples)
        if rms==0: raise ValueError('Silent fitted effect: '+spec['file'])
        prepared[spec['file']]={'samples':samples,'rms':rms,'peak':max(map(abs,samples)), 'spec':spec}
    target=min(10**(-18/20),min(v['rms']*peak_ceiling/v['peak'] for v in prepared.values()))
    manifest={}
    encoder_list=subprocess.run(['ffmpeg','-hide_banner','-encoders'],capture_output=True,text=True,check=True).stdout
    codec=['-c:a','libvorbis'] if 'libvorbis' in encoder_list else ['-c:a','vorbis','-strict','experimental']
    for name,item in prepared.items():
        samples=item['samples']
        gain=target/item['rms']
        for i in range(len(samples)): samples[i]*=gain
        if sys.byteorder!='little': samples.byteswap()
        path=destination/name
        subprocess.run(['ffmpeg','-v','error','-y','-f','f32le','-ar',str(RATE),'-ac','2','-i','pipe:0',*codec,'-q:a','5',str(path)],input=samples.tobytes(),check=True)
        manifest[name]={'file':'native/skin/audio/'+name,'method':'Runway AI sound effects; onset crop, short fades, shared RMS normalization; FFmpeg Vorbis',
                        'task_id':jobs[name]['taskId'],'prompt':item['spec']['prompt'],'source':'native-builds/audio-sources/'+name.replace('.ogg','.mp3'),
                        'sample_rate':RATE,'channels':CHANNELS,'duration_seconds':item['spec']['seconds'],'loop':False,
                        'authentic_acoustic_recording':False,'listening_acceptance_pending':True}
        print(name,'staged',item['spec']['seconds'],'seconds')
    (destination/'generation-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    print('Target active RMS:',round(20*math.log10(target),2),'dBFS')

if __name__=='__main__': main()
