import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,rm,readFile,stat} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {createApp} from '../server/http.js';
import {Service} from '../server/service.js';
import {DECKS} from '../oyun/decks.js';
import {chooseBotAction} from '../oyun/bot.js';
import {legalActions,restoreReplay} from '../oyun/engine.js';

async function setup(t){
  const dir=await mkdtemp(join(tmpdir(),'destan-server-'));let clock=Date.parse('2026-10-12T12:00:00Z');
  const app=await createApp({dataDir:dir,now:()=>clock});await new Promise(resolve=>app.server.listen(0,'127.0.0.1',resolve));
  const url=`http://127.0.0.1:${app.server.address().port}`;
  t.after(async()=>{await app.close();await rm(dir,{recursive:true,force:true});});
  async function request(path,{method='GET',body,client,csrf,origin=url}={}){
    const headers={};if(client)headers.cookie=client.cookie;
    if(method!=='GET'){headers.origin=origin;headers['content-type']='application/json';headers['x-destan-csrf']=csrf??client?.csrf??'';}
    const response=await fetch(url+path,{method,headers,...(body===undefined?{}:{body:JSON.stringify(body)})});
    const result={status:response.status,headers:response.headers,body:await response.json()};return result;
  }
  async function guest(){const r=await request('/api/session',{method:'POST',body:{}});assert.equal(r.status,200);return {cookie:r.headers.get('set-cookie').split(';')[0],csrf:r.body.csrf,id:r.body.id,key:r.body.recoveryKey,header:r.headers.get('set-cookie')};}
  return {...app,dir,url,request,guest,now:()=>clock,advance:ms=>{clock+=ms;}};
}
async function pair(f){const a=await f.guest(),b=await f.guest();const r=await f.request('/api/rooms',{method:'POST',body:{deck:DECKS.starter.cards},client:a});const joined=await f.request('/api/join',{method:'POST',body:{code:r.body.code,deck:DECKS.starter.cards},client:b});assert.equal(joined.status,200);return {a,b,id:r.body.id};}
async function action(f,client,id,view,action,requestId=crypto.randomUUID()){
  return f.request(`/api/matches/${id}/actions`,{method:'POST',client,body:{version:view.version,requestId,action}});
}
async function start(f,pair){
  for(const client of [pair.a,pair.b]){const r=await f.request(`/api/matches/${pair.id}`,{client});assert.equal((await action(f,client,pair.id,r.body,{type:'mulligan',indices:[]})).status,200);}
}
test('guest sessions are protected and bootstrap rejects forged profile data or foreign origins',async t=>{
  const f=await setup(t),a=await f.guest();assert.ok(a.header.includes('HttpOnly')&&a.header.includes('SameSite=Strict'));
  assert.equal((await f.request('/api/me')).status,401);
  assert.equal((await f.request('/api/session',{method:'POST',body:{},origin:'https://other.example'})).status,403);
  assert.equal((await f.request('/api/session',{method:'POST',body:{gold:99999},client:a})).status,400);
  assert.equal((await f.request('/api/me',{client:a})).body.profile.gold,30);
});
test('CSRF including malformed Unicode is rejected; private runtime files cannot be served',async t=>{
  const f=await setup(t),a=await f.guest();
  for(const csrf of ['','bad','ü'.repeat(64)])assert.equal((await f.request('/api/rooms',{method:'POST',body:{deck:DECKS.starter.cards},client:a,csrf})).status,403);
  assert.equal((await f.request('/.data/state.json')).status,404);assert.equal((await f.request('/.git/config')).status,404);
});
test('both players receive only their own hand; deck, entropy and closed traps stay hidden',async t=>{
  const f=await setup(t),p=await pair(f),outsider=await f.guest();
  f.service.data.matches[p.id].game.players[1].traps=[{id:36,uid:999}];
  for(const client of [p.a,p.b]){
    const r=await f.request(`/api/matches/${p.id}`,{client}),s=r.body.state;
    assert.ok(s.players[0].hand.every(Number.isInteger));assert.ok(s.players[1].hand.every(id=>id===null));assert.ok(s.players.every(player=>player.deck.every(id=>id===null)));
    for(const field of ['entropy','rng','seed','history','initial'])assert.equal(Object.hasOwn(s,field),false);
  }
  const a=(await f.request(`/api/matches/${p.id}`,{client:p.a})).body.state;assert.equal(a.players[1].traps[0].id,undefined);
  assert.equal((await f.request(`/api/matches/${p.id}`,{client:outsider})).status,404);
  assert.equal((await f.request(`/api/matches/${p.id}/replay`,{client:p.a})).status,409);
});
test('duplicate action requests and JSON field order do not apply the move twice; stale versions fail',async t=>{
  const f=await setup(t),p=await pair(f),v=(await f.request(`/api/matches/${p.id}`,{client:p.a})).body;
  const first=await action(f,p.a,p.id,v,{type:'mulligan',indices:[]},'move-1');assert.equal(first.status,200);
  const again=await action(f,p.a,p.id,v,{indices:[],type:'mulligan'},'move-1');assert.equal(again.status,200);assert.equal(again.body.version,first.body.version);
  assert.equal((await action(f,p.a,p.id,v,{type:'mulligan',indices:[]},'move-2')).status,409);
  assert.equal((await action(f,p.a,p.id,first.body,{type:'end'},'move-1')).status,409);
});
test('roles cannot be forged and player-two hero targets are translated correctly',async t=>{
  const f=await setup(t),p=await pair(f);await start(f,p);
  const game=f.service.data.matches[p.id].game;game.active=1;game.phase='main';game.players[1].hand=[30];game.players[1].energy=8;
  const view=(await f.request(`/api/matches/${p.id}`,{client:p.b})).body;
  const bad=await f.request(`/api/matches/${p.id}/actions`,{method:'POST',client:p.b,body:{version:view.version,requestId:'fake-role',p:0,action:{type:'play',index:0,target:'hero:1'}}});assert.equal(bad.status,400);
  const good=await action(f,p.b,p.id,view,{type:'play',index:0,target:'hero:1'});assert.equal(good.status,200);assert.equal(good.body.state.players[1].hp,17);assert.equal(good.body.state.players[0].hp,20);
});
test('ordinary card play cannot extend the authoritative turn deadline',async t=>{
  const f=await setup(t),p=await pair(f);await start(f,p);let client,view,play;
  for(let i=0;i<8;i++){
    const a=(await f.request(`/api/matches/${p.id}`,{client:p.a})).body;client=a.state.active===0?p.a:p.b;view=(await f.request(`/api/matches/${p.id}`,{client})).body;
    play=legalActions(view.state).find(a=>a.type==='play');if(play)break;
    await action(f,client,p.id,view,{type:'end'});
  }
  assert.ok(play);const deadline=view.deadline;f.advance(10000);const played=await action(f,client,p.id,view,play);assert.equal(played.status,200);assert.equal(played.body.deadline,deadline);
});
test('server expiry advances turns and two missed turns surrender; reconnect gets latest version',async t=>{
  const f=await setup(t),p=await pair(f);await start(f,p);const first=(await f.request(`/api/matches/${p.id}`,{client:p.a})).body;
  for(let i=0;i<3;i++){f.advance(45001);await f.request(`/api/matches/${p.id}`,{client:p.a});}
  const after=(await f.request(`/api/matches/${p.id}`,{client:p.b})).body;assert.equal(after.status,'finished');assert.equal(after.state.reason,'teslim');assert.ok(after.version>first.version);
});
test('owned deck enforcement rejects unowned and invalid-copy decks',async t=>{
  const f=await setup(t),a=await f.guest();
  assert.equal((await f.request('/api/rooms',{method:'POST',client:a,body:{deck:DECKS.control.cards}})).status,403);
  assert.equal((await f.request('/api/rooms',{method:'POST',client:a,body:{deck:Array(20).fill(1)}})).status,422);
});
test('wallet operations are serialized and idempotent under concurrent requests',async t=>{
  const f=await setup(t),a=await f.guest();f.service.data.users[a.id].profile.gold=600;
  const call=()=>f.request('/api/collection/pack',{method:'POST',client:a,body:{requestId:'same-pack'}});
  const [one,two]=await Promise.all([call(),call()]);assert.equal(one.status,200);assert.equal(two.status,200);assert.equal(one.body.account.profile.gold,300);assert.deepEqual(one.body.rewards,two.body.rewards);
  await f.request('/api/collection/pack',{method:'POST',client:a,body:{requestId:'second-pack'}});
  assert.equal((await call()).body.account.profile.gold,0);
  assert.equal((await f.request('/api/collection/pack',{method:'POST',client:a,body:{requestId:'no-gold'}})).status,422);
});
test('story completion and chapter rewards come from the server, survive restart and are one-time',async t=>{
  const f=await setup(t),a=await f.guest();let room=(await f.request('/api/solo',{method:'POST',client:a,body:{chapterId:1}})).body;
  const forbidden=await action(f,a,room.id,room,{type:'mulligan',indices:[0]});assert.equal(forbidden.status,422);
  for(let step=0;step<200&&room.status!=='finished';step++){
    const next=await action(f,a,room.id,room,chooseBotAction(room.state));assert.equal(next.status,200);room=next.body;
  }
  assert.equal(room.status,'finished');assert.equal(room.state.winner,0);
  const me=(await f.request('/api/me',{client:a})).body;assert.equal(me.profile.gold,130);assert.equal(me.profile.freePacks,1);assert.ok(me.profile.chapterRewards.includes(1));
  await f.request(`/api/matches/${room.id}`,{client:a});assert.equal((await f.request('/api/me',{client:a})).body.profile.gold,130);
  const stored=await readFile(join(f.dir,'state.json'),'utf8');assert.ok(!stored.includes(a.key));assert.ok(!stored.includes(a.cookie.slice('destan_session='.length)));
  assert.equal((await stat(join(f.dir,'state.json'))).mode&0o777,0o600);
  const replay=(await f.request(`/api/matches/${room.id}/replay`,{client:a})).body;assert.equal(restoreReplay(replay).status,'finished');
  await f.close();const reopened=await Service.open(f.dir,f.now);const recovered=await reopened.recover(a.key);assert.equal(recovered.account.profile.gold,130);assert.equal(recovered.account.matchId,room.id);
});
test('ranked unlock, matching, rating and result settlement are server-owned',async t=>{
  const f=await setup(t),a=await f.guest(),b=await f.guest();
  assert.equal((await f.request('/api/queue',{method:'POST',client:a,body:{deck:DECKS.starter.cards}})).status,403);
  for(const c of [a,b])f.service.data.users[c.id].profile.chapterRewards=[1,2,3,4,5,6,7,8,9,10];
  assert.equal((await f.request('/api/queue',{method:'POST',client:a,body:{deck:DECKS.starter.cards}})).status,200);
  const matched=await f.request('/api/queue',{method:'POST',client:b,body:{deck:DECKS.starter.cards}});assert.equal(matched.status,200);assert.ok(matched.body.matchId);
  const id=matched.body.matchId,v=(await f.request(`/api/matches/${id}`,{client:a})).body;assert.equal((await action(f,a,id,v,{type:'surrender'})).status,200);
  const aa=(await f.request('/api/me',{client:a})).body,bb=(await f.request('/api/me',{client:b})).body;assert.equal(aa.mmr,980);assert.equal(bb.mmr,1020);assert.equal(aa.placements,1);
  await f.request(`/api/matches/${id}`,{client:b});assert.equal((await f.request('/api/me',{client:b})).body.mmr,1020);
});
test('recovery rotation invalidates old keys; deletion revokes sessions and recovery',async t=>{
  const f=await setup(t),a=await f.guest();const rotated=await f.request('/api/recovery-key',{method:'POST',client:a,body:{}});assert.equal(rotated.status,200);
  assert.equal((await f.request('/api/recover',{method:'POST',body:{key:a.key}})).status,401);
  assert.equal((await f.request('/api/recover',{method:'POST',body:{key:rotated.body.recoveryKey}})).status,200);
  assert.equal((await f.request('/api/account',{method:'DELETE',body:{},client:a})).status,200);assert.equal((await f.request('/api/me',{client:a})).status,401);
  assert.equal((await f.request('/api/recover',{method:'POST',body:{key:rotated.body.recoveryKey}})).status,401);
});
test('failed persistence rolls back an economy transaction',async t=>{
  const f=await setup(t),a=await f.guest();f.service.data.users[a.id].profile.gold=300;
  const original=f.service.store.save.bind(f.service.store);f.service.store.save=async()=>{throw new Error('simulated-write-failure');};
  assert.equal((await f.request('/api/collection/pack',{method:'POST',client:a,body:{requestId:'disk-failure'}})).status,500);
  f.service.store.save=original;assert.equal((await f.request('/api/me',{client:a})).body.profile.gold,300);assert.equal(f.service.data.users[a.id].ops['disk-failure'],undefined);
});
test('production refuses startup without HTTPS origin',async()=>{await assert.rejects(createApp({production:true}),/HTTPS/);});
test('the same persistent directory cannot have two live writer servers',async t=>{const f=await setup(t);await assert.rejects(createApp({dataDir:f.dir}),/başka bir sunucu/);});
