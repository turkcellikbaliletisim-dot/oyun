import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {randomBytes} from 'node:crypto';
import {readFileSync} from 'node:fs';
import {createApp} from '../server/http.js';
const starter=JSON.parse(readFileSync(new URL('../native/data.json',import.meta.url),'utf8')).decks.starter.cards;

async function harness(){
  const dir=await mkdtemp(join(tmpdir(),'destan-full-'));
  const app=await createApp({dataDir:join(dir,'s')});
  await new Promise(r=>app.server.listen(0,'127.0.0.1',r));
  const base=`http://127.0.0.1:${app.server.address().port}`;
  let cookie='',csrf='';
  const api=async(p,m='GET',b)=>{
    const r=await fetch(`${base}/api/${p}`,{method:m,headers:{'Content-Type':'application/json',Origin:base,Cookie:cookie,'X-Destan-Csrf':csrf},body:m==='GET'?undefined:JSON.stringify(b||{})});
    const sc=r.headers.get('set-cookie');if(sc)cookie=sc.split(';')[0];
    return r.json();
  };
  const acc=await api('session','POST');csrf=acc.csrf;
  const act=(room,action)=>api(`matches/${room.id}/actions`,'POST',{version:room.version,action,requestId:randomBytes(16).toString('hex')});
  return {api,act,close:async()=>{await app.close();await rm(dir,{recursive:true,force:true});}};
}

// Plays with a simple policy: mulligan nothing, play affordable cards, attack, then end the turn.
async function playOut(h,room,limit=600){
  let moves=0;
  while(room.state.status!=='finished'){
    assert.ok(!room.error,`server error: ${room.error}`);
    assert.ok(++moves<=limit,`match did not finish in ${limit} moves`);
    const legal=room.actions||[];
    assert.ok(legal.length>0,`no legal action while active=${room.state.active} status=${room.state.status}`);
    const pick=legal.find(a=>a.type==='mulligan')
      ||legal.find(a=>a.type==='play')
      ||legal.find(a=>a.type==='attack'&&a.target==='hero:1')
      ||legal.find(a=>a.type==='attack')
      ||legal.find(a=>a.type==='scry')
      ||legal.find(a=>a.type==='discard')
      ||legal.find(a=>a.type==='end');
    const action=pick.type==='mulligan'?{type:'mulligan',indices:[]}:pick;
    room=await h.act(room,action);
  }
  return {room,moves};
}

test('bota karşı hızlı maç baştan sona biter',async()=>{
  const h=await harness();
  try{
    const room=await h.api('solo','POST',{chapterId:0,deck:starter});
    const {room:done,moves}=await playOut(h,room);
    assert.equal(done.state.status,'finished');
    assert.ok(moves>3);
    assert.equal((await h.api('me')).matchId,done.id,'sonuç ekranı için maç açık kalır');
    const out=await h.api(`matches/${done.id}/leave`,'POST');
    assert.ok(!out.error,out.error);
    const me=await h.api('me');
    assert.equal(me.matchId,null,'Lobiye dönünce maç kapanmalı');
    assert.ok(me.history.length>=1);
  }finally{await h.close();}
});

test('hikâye bölümü 1 baştan sona biter',async()=>{
  const h=await harness();
  try{
    const room=await h.api('solo','POST',{chapterId:1});
    const {room:done}=await playOut(h,room);
    assert.equal(done.state.status,'finished');
  }finally{await h.close();}
});

test('maç ortasında ayrılmak teslim sayılır ve hesabı serbest bırakır',async()=>{
  const h=await harness();
  try{
    let room=await h.api('solo','POST',{chapterId:0,deck:starter});
    room=await h.act(room,{type:'mulligan',indices:[]});
    const out=await h.api(`matches/${room.id}/leave`,'POST');
    assert.ok(!out.error,out.error);
    const me=await h.api('me');
    assert.equal(me.matchId,null);
  }finally{await h.close();}
});
