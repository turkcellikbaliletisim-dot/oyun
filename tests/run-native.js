import {mkdtemp,rm,mkdir,readFile} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {homedir} from 'node:os';
const sessionPath=join(homedir(),'Library/Application Support/Godot/app_userdata/Destan Diyarları/destan-session.cfg');
async function realSession(){try{return await readFile(sessionPath,'utf8');}catch(e){if(e.code==='ENOENT')return null;throw e;}}
const beforeSession=await realSession();
import {spawn} from 'node:child_process';
import {createApp} from '../server/http.js';
const dir=await mkdtemp(join(tmpdir(),'destan-native-'));
const app=await createApp({dataDir:join(dir,'server')});
await new Promise(resolve=>app.server.listen(0,'127.0.0.1',resolve));
const env={...process.env,DESTAN_SESSION_DIR:join(dir,'session'),DESTAN_SERVER_URL:`http://127.0.0.1:${app.server.address().port}`,XDG_DATA_HOME:join(dir,'data'),XDG_CONFIG_HOME:join(dir,'config'),XDG_CACHE_HOME:join(dir,'cache')};
for(const name of ['data','config','cache','session'])await mkdir(join(dir,name),{recursive:true});
async function godot(args){
  const verbosity=process.env.DESTAN_NATIVE_VERBOSE==='1'?['--verbose']:[];
  const child=spawn(process.env.GODOT_BIN??'godot',[...verbosity,...args],{env:{...env,DESTAN_SESSION_DIR:join(dir,'session',args.find(arg=>arg.endsWith('.gd'))?.split('/').pop()??'import')},stdio:['ignore','pipe','pipe']});
  let errors=false;
  child.stdout.on('data',chunk=>process.stdout.write(chunk));
  child.stderr.on('data',chunk=>{if(/SCRIPT ERROR|ERROR:/.test(chunk))errors=true;process.stderr.write(chunk);});
  const timeout=setTimeout(()=>child.kill('SIGTERM'),90000);
  try{return await new Promise((resolve,reject)=>{child.on('error',reject);child.on('exit',code=>resolve(code===0&&!errors));});}finally{clearTimeout(timeout);}
}
try{
  if(!await godot(['--headless','--path','.','--editor','--import','--quit']))throw new Error('Godot import failed');
  if(!await godot(['--headless','--path','.','--script','tests/native-audio.gd']))throw new Error('Godot audio import failed');
  const display=process.env.DESTAN_NATIVE_VISUAL==='1'?['--rendering-driver','opengl3','--audio-driver','Dummy']:['--headless'];
  if(!await godot([...display,'--path','.','--script','tests/native-skin-chrome.gd','--','--no-connect']))throw new Error('Mobile skin chrome failed');
  if(!await godot([...display,'--path','.','--script','tests/native-landscape-match.gd','--','--no-connect']))throw new Error('Landscape match failed');
  if(!await godot([...display,'--path','.','--script','tests/native-layout.gd','--','--no-connect']))throw new Error('Mobile layout failed');
  if(!await godot(['--headless','--path','.','--script','tests/native-mobile-lifecycle.gd','--','--no-connect']))throw new Error('Mobile lifecycle failed');
  if(!await godot(['--headless','--path','.','--script','tests/native-touch.gd','--','--no-connect']))throw new Error('Native touch failed');
  if(!await godot(['--headless','--path','.','--script','tests/native-interaction.gd','--','--no-connect']))throw new Error('Mobile interaction failed');
  if(!await godot([...display,'--path','.','--script','native/integration.gd','--','--no-connect']))throw new Error('Godot integration failed');
  await new Promise((resolve,reject)=>spawn('node',['tests/offline-parity.js',join(dir,'parity.json')],{stdio:'inherit'}).on('exit',code=>code===0?resolve():reject(new Error('Parity generation failed'))));
  if(!await godot(['--headless','--path','.','--script','tests/offline-parity.gd','--',join(dir,'parity.json')]))throw new Error('Offline engine parity failed');
  if(!await godot(['--headless','--path','.','--script','tests/merge-engine.gd','--','--no-connect']))throw new Error('Merge engine failed');
  if(!await godot(['--headless','--path','.','--script','tests/native-offline.gd','--','--no-connect']))throw new Error('Offline mode failed');
  if(await realSession()!==beforeSession)throw new Error('Native test changed real player session');
}finally{await app.close();await rm(dir,{recursive:true,force:true});}
