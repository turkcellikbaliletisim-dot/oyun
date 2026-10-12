import {mkdtemp,rm,mkdir} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {spawn} from 'node:child_process';
import {createApp} from '../server/http.js';
const dir=await mkdtemp(join(tmpdir(),'destan-native-'));
const app=await createApp({dataDir:join(dir,'server')});
await new Promise(resolve=>app.server.listen(0,'127.0.0.1',resolve));
const env={...process.env,DESTAN_SERVER_URL:`http://127.0.0.1:${app.server.address().port}`,XDG_DATA_HOME:join(dir,'data'),XDG_CONFIG_HOME:join(dir,'config'),XDG_CACHE_HOME:join(dir,'cache')};
for(const name of ['data','config','cache'])await mkdir(join(dir,name),{recursive:true});
async function godot(args){
  const child=spawn(process.env.GODOT_BIN??'godot',args,{env,stdio:['ignore','pipe','pipe']});
  let errors=false;
  child.stdout.on('data',chunk=>process.stdout.write(chunk));
  child.stderr.on('data',chunk=>{if(/SCRIPT ERROR|ERROR:/.test(chunk))errors=true;process.stderr.write(chunk);});
  const timeout=setTimeout(()=>child.kill('SIGTERM'),90000);
  try{return await new Promise((resolve,reject)=>{child.on('error',reject);child.on('exit',code=>resolve(code===0&&!errors));});}finally{clearTimeout(timeout);}
}
try{
  if(!await godot(['--headless','--path','.','--editor','--import','--quit']))throw new Error('Godot import failed');
  const display=process.env.DESTAN_NATIVE_VISUAL==='1'?['--rendering-driver','opengl3','--audio-driver','Dummy']:['--headless'];
  if(!await godot([...display,'--path','.','--script','native/integration.gd','--','--no-connect']))throw new Error('Godot integration failed');
}finally{await app.close();await rm(dir,{recursive:true,force:true});}
