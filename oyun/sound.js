// Özgün, prosedürel başlangıç müziği/efektleri; dış ses kaydı kullanılmaz.
export class GameAudio {
  constructor(){this.context=null;this.volume=.18;this.musicTimer=null;this.musicIndex=0;}
  async ready(){
    const Context=globalThis.AudioContext??globalThis.webkitAudioContext;if(!Context)return false;
    this.context??=new Context();await this.context.resume();return true;
  }
  tone(frequency,when,duration=.2,gain=.1,type='triangle'){
    const oscillator=this.context.createOscillator(),volume=this.context.createGain();oscillator.type=type;oscillator.frequency.value=frequency;
    volume.gain.setValueAtTime(.001,when);volume.gain.exponentialRampToValueAtTime(Math.max(.002,gain*this.volume),when+.02);volume.gain.exponentialRampToValueAtTime(.001,when+duration);
    oscillator.connect(volume);volume.connect(this.context.destination);oscillator.start(when);oscillator.stop(when+duration+.03);
  }
  async effect(action,finished=false){
    if(!(await this.ready()))return false;
    const now=this.context.currentTime,notes=finished?[261.63,329.63,392]:action==='attack'?[146.83,110]:action==='play'?[293.66,392]:[196,261.63];
    notes.forEach((note,i)=>this.tone(note,now+i*.07,.16,.16));return true;
  }
  async music(enabled){
    clearInterval(this.musicTimer);this.musicTimer=null;if(!enabled)return;
    if(!(await this.ready()))return false;
    const melody=[293.66,349.23,392,440,392,349.23,261.63,293.66];
    const step=()=>{const index=this.musicIndex++%melody.length,when=this.context.currentTime;this.tone(melody[index],when,.8,.07);if(index%4===0){this.tone(index===0?146.83:130.81,when,2,.045,'sine');this.tone(196,when,2,.035,'sine');}};
    step();this.musicTimer=setInterval(step,650);return true;
  }
  async suspend(){clearInterval(this.musicTimer);this.musicTimer=null;await this.context?.suspend();}
}
