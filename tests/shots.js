// Kullanım: DESTAN_SHOT_DIR=/tmp/k GODOT_BIN=godot [DESTAN_SIZE=land] node tests/shots.js
import {mkdtemp,rm,mkdir} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {spawn} from 'node:child_process';
import {createApp} from '../server/http.js';
const dir=await mkdtemp(join(tmpdir(),'destan-shots-'));
const app=await createApp({dataDir:join(dir,'server')});
await new Promise(r=>app.server.listen(0,'127.0.0.1',r));
for(const n of ['data','config','cache','session'])await mkdir(join(dir,n),{recursive:true});
const env={...process.env,DESTAN_SESSION_DIR:join(dir,'session'),DESTAN_SERVER_URL:`http://127.0.0.1:${app.server.address().port}`,XDG_DATA_HOME:join(dir,'data'),XDG_CONFIG_HOME:join(dir,'config'),XDG_CACHE_HOME:join(dir,'cache')};
if(!env.DESTAN_SHOT_DIR)throw new Error('DESTAN_SHOT_DIR gerekli');
await mkdir(env.DESTAN_SHOT_DIR,{recursive:true});
const run=args=>new Promise(res=>{const c=spawn(process.env.GODOT_BIN??'godot',args,{env,stdio:'inherit'});c.on('exit',res);});
try{
  await run(['--headless','--path','.','--editor','--import','--quit']);
  await run(['--rendering-driver','opengl3','--audio-driver','Dummy','--path','.','--script','tests/shots.gd','--','--no-connect']);
}finally{await app.close();await rm(dir,{recursive:true,force:true});}
