import {mkdir,readFile,writeFile,rename,open,unlink} from 'node:fs/promises';
import {join} from 'node:path';
import {randomUUID} from 'node:crypto';
import {validateProfile} from '../oyun/economy.js';

export class Store {
  constructor(dir){this.dir=dir;this.path=join(dir,'state.json');}
  async acquire(){
    await mkdir(this.dir,{recursive:true,mode:0o700});const path=join(this.dir,'server.lock'),owner=randomUUID();
    let handle;
    try{handle=await open(path,'wx',0o600);}catch(error){
      if(error.code!=='EEXIST')throw error;
      let old;try{old=JSON.parse(await readFile(path,'utf8'));}catch{throw new Error('Kayıt dizininin kilidi doğrulanamadı; dosyayı koruyarak kontrol edin.');}
      if(!Number.isInteger(old.pid)||old.pid<=0||typeof old.owner!=='string')throw new Error('Kayıt dizini kilidi uyumsuz.');
      let gone=false;try{process.kill(old.pid,0);}catch(e){gone=e.code==='ESRCH';}
      if(!gone)throw new Error('Bu kayıt dizinini başka bir sunucu kullanıyor.');
      await unlink(path);handle=await open(path,'wx',0o600);
    }
    await handle.writeFile(JSON.stringify({pid:process.pid,owner}));await handle.close();
    return async()=>{try{const current=JSON.parse(await readFile(path,'utf8'));if(current.owner===owner)await unlink(path);}catch(e){if(e.code!=='ENOENT')throw e;}};
  }
  async load(){
    try{
      const data=JSON.parse(await readFile(this.path,'utf8'));
      if(data.version!==1||!data.users||!data.sessions||!data.matches||!Array.isArray(data.queue))throw new Error('version');
      for(const user of Object.values(data.users))validateProfile(user.profile);
      return data;
    }catch(error){
      if(error.code==='ENOENT')return {version:1,users:{},sessions:{},matches:{},queue:[],seasonStarted:null};
      throw new Error('Sunucu kaydı okunamadı veya sürümü uyumsuz. Mevcut dosyayı koruyarak yedekten doğrulayın.');
    }
  }
  async save(data){
    await mkdir(this.dir,{recursive:true,mode:0o700});
    const temp=join(this.dir,'state.json.tmp');
    await writeFile(temp,JSON.stringify(data),{mode:0o600});await rename(temp,this.path);
  }
}
