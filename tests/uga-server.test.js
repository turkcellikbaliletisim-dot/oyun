import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {createApp} from '../server/http.js';

async function setup(t){
  const dir=await mkdtemp(join(tmpdir(),'destan-uga-'));
  const app=await createApp({dataDir:dir,now:()=>Date.parse('2026-10-13T12:00:00Z')});await new Promise(r=>app.server.listen(0,'127.0.0.1',r));
  const url=`http://127.0.0.1:${app.server.address().port}`;
  t.after(async()=>{await app.close();await rm(dir,{recursive:true,force:true});});
  async function request(path,{method='GET',body,client}={}){
    const headers={};if(client)headers.cookie=client.cookie;
    if(method!=='GET'){headers.origin=url;headers['content-type']='application/json';headers['x-destan-csrf']=client?.csrf??'';}
    const r=await fetch(url+path,{method,headers,...(body===undefined?{}:{body:JSON.stringify(body)})});return {status:r.status,body:await r.json()};
  }
  async function guest(){const r=await fetch(url+'/api/session',{method:'POST',headers:{origin:url,'content-type':'application/json'},body:'{}'});const b=await r.json();return {cookie:r.headers.get('set-cookie').split(';')[0],csrf:b.csrf};}
  return {request,guest};
}

test('UGACHA sıralaması en iyi dalgayı tutar ve sıralar',async t=>{
  const f=await setup(t);const a=await f.guest(),b=await f.guest();
  let r=await f.request('/api/uga/score',{method:'POST',client:a,body:{world:0,wave:12}});assert.equal(r.status,200);assert.equal(r.body.me.rank,1);
  r=await f.request('/api/uga/score',{method:'POST',client:b,body:{world:0,wave:20}});assert.equal(r.body.me.rank,1);
  r=await f.request('/api/uga/score',{method:'POST',client:a,body:{world:0,wave:5}});assert.equal(r.body.me.wave,12,'daha düşük skor rekoru silmez');
  r=await f.request('/api/uga/board/0',{client:a});assert.equal(r.status,200);assert.deepEqual(r.body.top.map(x=>x.wave),[20,12]);assert.equal(r.body.me.rank,2);
  r=await f.request('/api/uga/score',{method:'POST',client:a,body:{world:9,wave:5}});assert.equal(r.status,400);
  r=await f.request('/api/uga/score',{method:'POST',client:a,body:{world:0,wave:99}});assert.equal(r.status,400);
});

test('UGACHA arkadaş yarışı aynı tohumu paylaşır ve sonuçları toplar',async t=>{
  const f=await setup(t);const a=await f.guest(),b=await f.guest();
  const created=await f.request('/api/uga/race',{method:'POST',client:a,body:{world:1}});assert.equal(created.status,200);assert.match(created.body.code,/^[A-Z0-9]{6}$/);
  const got=await f.request(`/api/uga/race/${created.body.code}`,{client:b});assert.equal(got.body.seed,created.body.seed);assert.equal(got.body.world,1);
  await f.request(`/api/uga/race/${created.body.code}/result`,{method:'POST',client:a,body:{wave:9}});
  const fin=await f.request(`/api/uga/race/${created.body.code}/result`,{method:'POST',client:b,body:{wave:14}});
  assert.deepEqual(fin.body.results.map(x=>x.wave),[14,9]);
  const missing=await f.request('/api/uga/race/ZZZZZZ',{client:a});assert.equal(missing.status,404);
});
