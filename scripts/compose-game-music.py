#!/usr/bin/env python3
"""Original deterministic game scores using local instrument synthesis.

No sampled recordings, existing songs, external model or paid service is used.
Ney/zurna and baglama are synthesized timbres, not acoustic recordings.
Every event and reverb tail wraps around the 96-second timeline.
"""
from pathlib import Path
import hashlib
import json
import math
import subprocess
import sys
import numpy as np
from scipy.signal import butter, sosfilt

ROOT = Path(__file__).resolve().parent.parent
RATE = 44100
SECONDS = 96
FRAMES = RATE * SECONDS
DEST = ROOT/'native-builds/music-ready'
RNG = np.random.default_rng(20261013)

def hz(midi):
    return 440 * 2 ** ((midi-69)/12)

def envelope(t, duration, attack=0.035, release=0.12):
    return np.minimum(1,t/attack) * np.clip((duration-t)/release,0,1)

def instrument(kind, midi, duration):
    t = np.arange(round(duration*RATE),dtype=np.float64)/RATE
    f = hz(midi)
    if kind in ['ney','zurna']:
        reed = kind == 'zurna'
        vibrato = (0.0045 if reed else 0.0025)*np.sin(2*np.pi*5.3*t)*np.clip(t/0.18,0,1)
        phase = 2*np.pi*np.cumsum(f*(1+vibrato))/RATE
        weights = [1,0.36,0.23,0.19,0.13,0.09,0.07,0.055] if reed else [1,0.2,0.105,0.075,0.035]
        signal = sum(weight*np.sin(phase*(index+1)+index*0.17) for index,weight in enumerate(weights))
        noise = RNG.normal(0,1,len(t))
        breath = sosfilt(butter(2,[1000,4200],btype='bandpass',fs=RATE,output='sos'),noise)
        signal += breath*(0.07 if reed else 0.13)
        signal *= envelope(t,duration,0.015 if reed else 0.075,min(0.18,duration/3))
        signal *= 0.35 if reed else 0.48
    elif kind == 'baglama':
        signal = np.zeros(len(t))
        # Paired string courses, progressively damped partials and pick noise.
        for partial in range(1,13):
            decay = np.exp(-t*(1.7+partial**0.75*1.1))
            pitch = f*partial*np.sqrt(1+0.000012*partial**2)
            paired = np.sin(2*np.pi*pitch*t)+0.68*np.sin(2*np.pi*pitch*1.0017*t+0.16)
            signal += paired*decay/partial**1.15
        pick = sosfilt(butter(2,1800,btype='highpass',fs=RATE,output='sos'),RNG.normal(0,1,len(t)))
        signal += pick*np.exp(-t*350)*0.19
        signal *= envelope(t,duration,0.002,0.06)*0.35
    elif kind == 'pad':
        signal = (np.sin(2*np.pi*f*t)+0.3*np.sin(2*np.pi*f*2*t)+0.16*np.sin(2*np.pi*f*3*t))
        signal += 0.35*np.sin(2*np.pi*f*0.9991*t)
        signal *= envelope(t,duration,0.8,1.0)*0.21
    else:
        raise ValueError(kind)
    return signal.astype(np.float32)

def drum(kind):
    duration = 0.55 if kind == 'davul' else 0.23
    t = np.arange(round(duration*RATE))/RATE
    noise = RNG.normal(0,1,len(t))
    if kind == 'davul':
        phase = 2*np.pi*(56*t+8*(1-np.exp(-t*32)))
        signal = np.sin(phase)*np.exp(-t*11)+0.35*np.sin(2*np.pi*133*t)*np.exp(-t*18)
        signal += noise*np.exp(-t*140)*0.19
    elif kind == 'tek':
        signal = sosfilt(butter(2,800,btype='highpass',fs=RATE,output='sos'),noise)*np.exp(-t*36)*0.48
        signal += np.sin(2*np.pi*240*t)*np.exp(-t*28)*0.38
    else: # Light frame-drum hit with small metallic jingles.
        signal = np.sin(2*np.pi*168*t)*np.exp(-t*32)*0.45
        signal += noise*np.exp(-t*65)*0.15
        for f in [2670,3430,4610,5960]:
            signal += np.sin(2*np.pi*f*t)*np.exp(-t*27)*0.055
    return (signal*envelope(t,duration,0.001,0.025)).astype(np.float32)

class Score:
    def __init__(self, bpm, bars):
        assert abs(bars*4*60/bpm-SECONDS)<1e-9
        self.bpm,self.bars = bpm,bars
        self.beat = 60/bpm
        self.mix = np.zeros((FRAMES,2),dtype=np.float32)
        self.events = []
        self.drums = {kind:drum(kind) for kind in ['davul','tek','def']}

    def add(self, samples, beat, gain, pan=0):
        start = round(beat*self.beat*RATE)%FRAMES
        stereo = samples[:,None]*np.array([math.cos((pan+1)*np.pi/4),math.sin((pan+1)*np.pi/4)],dtype=np.float32)*gain
        stop = min(len(stereo),FRAMES-start)
        self.mix[start:start+stop] += stereo[:stop]
        if stop<len(stereo): self.mix[:len(stereo)-stop] += stereo[stop:]

    def note(self, kind, midi, beat, length, gain, pan=0):
        # Plucked strings decay past the metrical note length.
        duration = length*self.beat + (0.55 if kind=='baglama' else 0.14 if kind in ['ney','zurna'] else 1.2)
        self.add(instrument(kind,midi,duration),beat,gain,pan)
        self.events.append({'instrument':kind,'midi':midi,'beat':beat,'beats':length,'gain':round(gain,3)})

    def hit(self, kind, beat, gain, pan=0):
        self.add(self.drums[kind],beat,gain,pan)

    def finish(self):
        # Circular convolution: late ambience contributes to the next loop.
        dry = self.mix.copy()
        for index,(delay,gain) in enumerate([(0.041,.055),(0.073,.05),(0.131,.045),(0.227,.04),(0.353,.033),(0.487,.03),(0.719,.025),(1.113,.018),(1.379,.012)]):
            echo = np.roll(dry,round(delay*RATE),axis=0)
            self.mix += (echo[:,::-1] if index%2 else echo)*gain
        self.mix -= np.mean(self.mix,axis=0)
        self.mix = np.tanh(self.mix*1.08).astype(np.float32)
        # Choose a nearby smooth phase boundary; the full timeline is rotated,
        # never shortened. No fade-to-silence gap is inserted at the loop.
        delta = np.max(np.abs(self.mix-np.roll(self.mix,1,axis=0)),axis=1)
        vicinity = np.r_[np.arange(0,round(RATE*.012)),np.arange(FRAMES-round(RATE*.012),FRAMES)]
        offset = int(vicinity[np.argmin(delta[vicinity])])
        self.mix = np.roll(self.mix,-offset,axis=0)
        self.mix *= 10**(-3.0/20)/np.max(np.abs(self.mix))
        return self.mix

def menu():
    score = Score(70,28) # 28 bars × 4 beats = exactly 96 seconds.
    roots = [50,53,55,50,58,55,50]
    phrases = [
        [(0,74,1.5),(1.75,72,.75),(2.75,69,1),(4.25,67,1.25),(5.75,69,.75),(6.75,65,1),(8.25,67,1.5),(10,64,1),(11.5,65,.75),(12.5,62,2.5)],
        [(0,69,1),(1.5,72,1),(3,74,1.5),(5,77,1),(6.5,74,1),(8,72,1.5),(10,69,1.5),(12,67,1),(13.5,65,1.5)],
        [(0,67,1.5),(2,69,1),(3.5,72,1.5),(5.5,71,.5),(6.25,69,1.25),(8,65,1),(9.5,67,1.5),(11.5,64,1),(13,62,2)]
    ]
    for section,root in enumerate(roots):
        start = section*16
        score.note('pad',root,start,16,0.38,-.2)
        score.note('pad',root+7,start,16,0.23,.24)
        phrase = phrases[[0,0,1,0,2,1,0][section]]
        for beat,note,length in phrase:
            score.note('ney',note,start+beat,length,0.40 if section in [0,6] else .48,.05)
        for bar in range(4):
            at=start+bar*4
            pitches=[root+12,root+19,root+15,root+19,root+24,root+19]
            for index,beat in enumerate([0,.75,1.5,2.25,3,3.5]):
                score.note('baglama',pitches[index],at+beat,.65,.24 if index%2 else .3,-.28)
            score.hit('def',at,.11,-.12)
            score.hit('def',at+2,.075,.2)
            score.hit('tek',at+3.5,.045,.32)
    return score

def battle():
    score = Score(110,44) # 44 bars × 4 beats = exactly 96 seconds.
    phrases = [
        [(0,74,.5),(.75,75,.25),(1.25,78,.75),(2.25,79,.5),(3,78,.75),(4,75,.5),(5,74,1),(6.25,81,.5),(7,79,.75)],
        [(0,81,.75),(1,79,.5),(1.75,78,.5),(2.5,75,.5),(3.25,74,.5),(4,72,1),(5.5,70,.5),(6.25,69,1.25)],
        [(0,74,1),(1.5,78,.5),(2.25,79,.5),(3,81,1),(4.5,82,.5),(5.25,81,.5),(6,78,.75),(7,74,.75)]
    ]
    for bar in range(44):
        at=bar*4
        root=[50,50,46,45][(bar//2)%4]
        energy=.72 if bar<4 or bar>=40 else .65 if 24<=bar<28 else 1.0
        if bar%2==0:
            score.note('pad',root,at,8,.22,-.16)
            score.note('pad',root+7,at,8,.12,.2)
            phrase=phrases[0 if bar<16 else 1 if bar<28 else 2]
            for beat,note,length in phrase:
                score.note('zurna',note,at+beat,length,.34*energy,.14)
                if note in [75,78,81] and length>=.5:
                    score.note('zurna',note+1,at+beat+.06,.07,.11*energy,.14)
        for index,beat in enumerate([0,.5,1,1.5,2,2.5,3,3.5]):
            pitch=root+12+[0,7,0,12,0,7,3,7][index]
            score.note('baglama',pitch,at+beat,.4,.32*energy,-.28)
        score.hit('davul',at,.67*energy,-.12)
        score.hit('davul',at+2,.52*energy,-.12)
        for beat,gain in [(1,.22),(1.5,.32),(2.75,.17),(3,.3),(3.5,.2)]:
            score.hit('tek',at+beat,gain*energy,.22)
        if bar%4==3:
            for beat in [3.25,3.5,3.75]: score.hit('davul',at+beat,.13*energy,-.12)
        score.hit('def',at+1.5,.07*energy,.4)
    return score

def encode(score,name,encoder):
    samples=score.finish()
    path=DEST/name
    for attempt in range(3):
        subprocess.run(['ffmpeg','-v','error','-y','-f','f32le','-ar',str(RATE),'-ac','2','-i','pipe:0',*encoder,'-q:a','5',str(path)],input=samples.astype('<f4').tobytes(),check=True)
        # Check intersample peaks after codec conversion, keeping extra headroom.
        raw=subprocess.run(['ffmpeg','-v','error','-i',str(path),'-ar','176400','-f','f32le','-'],capture_output=True,check=True).stdout
        peak=float(np.max(np.abs(np.frombuffer(raw,dtype='<f4'))))
        if peak<10**(-1.5/20): break
        samples*=10**(-2/20)/peak
    preview=DEST/name.replace('.ogg','.mp3')
    subprocess.run(['ffmpeg','-v','error','-y','-i',str(path),'-c:a','libmp3lame','-q:a','3',str(preview)],check=True)
    info={'file':'native/skin/audio/'+name,'sample_rate':RATE,'channels':2,'duration_seconds':SECONDS,'loop':True,
          'bpm':score.bpm,'bars':score.bars,'method':'original local score; additive/modal instrument synthesis; cyclic event tails and stereo reverb',
          'source':'scripts/compose-game-music.py','authentic_acoustic_recording':False,'external_samples':False,
          'peak_4x_dbfs':20*math.log10(peak),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
          'listening_acceptance_pending':True,'events':score.events}
    print(name, '96 s',score.bpm,'BPM',score.bars,'bars; encoded peak',round(info['peak_4x_dbfs'],2),'dBFS',flush=True)
    return info

def main():
    DEST.mkdir(parents=True,exist_ok=True)
    encoders=subprocess.run(['ffmpeg','-hide_banner','-encoders'],capture_output=True,text=True,check=True).stdout
    encoder=['-c:a','libvorbis'] if 'libvorbis' in encoders else ['-c:a','vorbis','-strict','experimental']
    manifest={}
    for name,compose in [('music_menu.ogg',menu),('music_battle.ogg',battle)]:
        manifest[name]=encode(compose(),name,encoder)
    (DEST/'music-score.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')

if __name__=='__main__': main()
