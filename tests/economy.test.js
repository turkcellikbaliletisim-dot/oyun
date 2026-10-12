import test from 'node:test';
import assert from 'node:assert/strict';
import { CARDS } from '../oyun/cards.js';
import { DECKS } from '../oyun/decks.js';
import {newProfile,loginReward,openPack,craftCard,dismantleCard,chapterReward,archiveCard,matchReward,missingDust,deckOwned} from '../oyun/economy.js';
test('starting collection is exactly twenty owned cards; tempo costs 440 dust, story reduces to 260',()=>{
  let p=newProfile();assert.equal(Object.values(p.inventory).reduce((a,b)=>a+b),20);assert.ok(deckOwned(p,DECKS.starter.cards));assert.equal(missingDust(p,DECKS.tempo.cards),440);
  for(let i=1;i<=10;i++)p=chapterReward(p,i);assert.equal(missingDust(p,DECKS.tempo.cards),260);assert.equal(p.archiveLeft,7);
});
test('login is idempotent and seventh nonconsecutive login grants a pack',()=>{
  let p=newProfile();for(const day of [1,2,4,5,7,8,10])p=loginReward(p,`2026-10-${String(day).padStart(2,'0')}`);
  assert.equal(p.gold,210);assert.equal(p.freePacks,1);assert.deepEqual(loginReward(p,'2026-10-10'),p);
});
test('ten pack pity, rarity bounds, duplicate protection and atomic insufficient gold',()=>{
  let p=newProfile();p.gold=3000;
  for(let i=0;i<9;i++){const result=openPack(p,()=>0);p=result.profile;assert.ok(!result.rewards.some(r=>r.id&&CARDS[r.id-1].rarity==='legendary'));}
  const result=openPack(p,()=>0);p=result.profile;assert.ok(result.rewards.some(r=>r.id&&CARDS[r.id-1].rarity==='legendary'));assert.equal(p.pity,0);assert.equal(p.gold,0);
  const before=structuredClone(p);assert.throws(()=>openPack(p),/300 altın/);assert.deepEqual(p,before);
});
test('full rarity gives dust and free pack is consumed before gold',()=>{
  const p=newProfile();for(const c of CARDS)p.inventory[c.id]=c.rarity==='legendary'?1:2;p.freePacks=1;p.gold=300;
  const result=openPack(p,()=>0);assert.equal(result.profile.gold,300);assert.equal(result.profile.freePacks,0);assert.equal(result.profile.dust,65);
});
test('craft/dismantle cannot exceed ownership or create positive value loops',()=>{
  let p=newProfile();p.dust=100;p=craftCard(p,19);assert.equal(p.dust,0);p=dismantleCard(p,19);assert.equal(p.dust,25);
  assert.throws(()=>craftCard(p,19),/toz/);assert.throws(()=>dismantleCard(p,19),/sahip/);
  assert.throws(()=>craftCard({...p,dust:1000},1),/tamam/);
});
test('chapter rewards are one-time and seven distinct archive selections guarantee 25 unique cards',()=>{
  let p=newProfile();for(let i=1;i<=10;i++)p=chapterReward(p,i);assert.deepEqual(chapterReward(p,10),p);
  assert.equal(Object.values(p.inventory).filter(Boolean).length,18);
  assert.throws(()=>archiveCard(p,1),/eksik/);
  for(const c of CARDS.filter(c=>!p.inventory[c.id]).slice(0,7))p=archiveCard(p,c.id);
  assert.equal(Object.values(p.inventory).filter(Boolean).length,25);assert.equal(p.archiveLeft,0);
  const full=newProfile();for(const c of CARDS)full.inventory[c.id]=c.rarity==='legendary'?1:2;
  assert.equal(chapterReward(full,10).archiveLeft,0);
});
test('valid match rewards cap wins, pay quests once and weekly once; IDs are idempotent',()=>{
  let p=newProfile();const state={status:'finished',winner:0,turn:8,history:[{p:0,action:{type:'play'}},{p:0,action:{type:'attack'}}],players:[{stats:{cardPlays:{1:8,30:3}}}]};
  for(let i=0;i<10;i++)p=matchReward(p,{id:`m${i}`,state,day:'2026-10-12'});
  assert.equal(p.gold,510); // wins 60 + quests 150 + weekly 300
  assert.equal(p.freePacks,1);assert.deepEqual(matchReward(p,{id:'m0',state,day:'2026-10-12'}),p);
  p=matchReward(p,{id:'new',state,day:'2026-10-12'});assert.equal(p.gold,510);
});
test('short games and scripted tutorial do not farm match rewards',()=>{
  const state={status:'finished',winner:0,turn:2,history:[],players:[{stats:{cardPlays:{1:8}}}]};
  let p=matchReward(newProfile(),{id:'short',state,day:'2026-10-12'});assert.equal(p.gold,0);
  p=matchReward(p,{id:'training',state:{...state,turn:8},chapterId:1,day:'2026-10-12'});assert.equal(p.gold,0);
});
