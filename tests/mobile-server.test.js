import{test}from'node:test';
import assert from'node:assert/strict';
import{mkdtemp,mkdir,writeFile,rm,symlink}from'node:fs/promises';
import{tmpdir}from'node:os';
import{join}from'node:path';
import{brotliCompressSync}from'node:zlib';
import{createApp}from'../server/http.js';
test('mobile Web assets have correct types/CSP/compression and cannot escape their public directory',async()=>{
 const dir=await mkdtemp(join(tmpdir(),'destan-mobile-http-'));const mobileDir=join(dir,'public');
 await mkdir(mobileDir);const wasm=Buffer.from([0,97,115,109,1,0,0,0]);
 await writeFile(join(mobileDir,'game.wasm'),wasm);await writeFile(join(mobileDir,'game.wasm.br'),brotliCompressSync(wasm));
 await writeFile(join(mobileDir,'index.html'),'<html>game</html>');await writeFile(join(dir,'secret.js'),'secret');
 await symlink(join(dir,'secret.js'),join(mobileDir,'escape.js'));
 const app=await createApp({dataDir:join(dir,'state'),mobileDir});await new Promise(r=>app.server.listen(0,'127.0.0.1',r));
 const url='http://127.0.0.1:'+app.server.address().port;
 try{
  const response=await fetch(url+'/mobile/game.wasm',{headers:{'Accept-Encoding':'br'}});
  assert.equal(response.status,200);assert.equal(response.headers.get('Content-Type'),'application/wasm');
  assert.equal(response.headers.get('Content-Encoding'),'br');assert.deepEqual(Buffer.from(await response.arrayBuffer()),wasm);
  assert.match(response.headers.get('Content-Security-Policy'),/wasm-unsafe-eval/);assert.doesNotMatch(response.headers.get('Content-Security-Policy'),/'unsafe-inline'.*script|script-src[^;]*'unsafe-inline'/);
  assert.equal((await fetch(url+'/mobile/escape.js')).status,404);
  assert.equal((await fetch(url+'/mobile/%2e%2e/secret.js')).status,404);
  assert.equal((await fetch(url+'/mobile/')).status,200);
 }finally{await app.close();await rm(dir,{recursive:true,force:true});}
});
