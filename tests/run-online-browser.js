import {mkdtemp,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {spawn} from 'node:child_process';
import {createApp} from '../server/http.js';
const dir=await mkdtemp(join(tmpdir(),'destan-browser-'));
const app=await createApp({dataDir:dir});
await new Promise(resolve=>app.server.listen(0,'127.0.0.1',resolve));
try{
  const child=spawn('python3',['tests/online-browser.py'],{stdio:'inherit',env:{...process.env,DESTAN_ONLINE_URL:`http://127.0.0.1:${app.server.address().port}`}});
  const result=await new Promise(resolve=>child.on('exit',resolve));process.exitCode=result??1;
}finally{await app.close();await rm(dir,{recursive:true,force:true});}
