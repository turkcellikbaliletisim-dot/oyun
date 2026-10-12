import test from 'node:test';
import assert from 'node:assert/strict';
import { CARDS, CARD_BY_ID as C } from '../oyun/cards.js';
import { DECKS } from '../oyun/decks.js';
import { createGame, applyAction as act, legalActions, validateDeck, attackValue, canAttack, exportReplay, restoreReplay, RuleError } from '../oyun/engine.js';
import { chooseBotAction } from '../oyun/bot.js';

function fixture() {
  let s = createGame({ first:0 });
  s = act(s,0,{type:'mulligan',indices:[]}); s = act(s,1,{type:'mulligan',indices:[]});
  s.turn=5;
  for (let p=0;p<2;p++) {
    Object.assign(s.players[p],{hand:[],board:[],traps:[],grave:[],energy:8,maxEnergy:8,turns:p===0?3:2});
  }
  return s;
}
function add(s,p,id,extras={}) {
  const c=C[id],u={uid:s.nextUid++,id,attack:c.attack,hp:c.hp,maxHp:c.hp,tempAttack:0,shield:false,keywords:[...c.keywords],exhausted:false,skipUntil:0,...extras};
  s.players[p].board.push(u); return u;
}
function play(s,id,target) { s.players[0].hand=[id]; return act(s,0,{type:'play',index:0,...(target===undefined?{}:{target})}); }
const hit=(s,uid,target)=>act(s,0,{type:'attack',uid,target});
const trap=(s,id)=>s.players[1].traps.push({uid:s.nextUid++,id});

test('40 canonical cards and all preset decks satisfy counts and limits',()=>{
  assert.deepEqual(CARDS.map(c=>c.id),Array.from({length:40},(_,i)=>i+1));
  assert.equal(CARDS.filter(c=>c.rarity==='legendary').length,6);
  for(const deck of Object.values(DECKS)) assert.equal(validateDeck(deck.cards),true);
  assert.throws(()=>validateDeck(Array(20).fill(1)),RuleError);
  assert.throws(()=>validateDeck([...DECKS.control.cards.slice(0,18),23,23]),RuleError);
});
test('mulligan rejects duplicate indices without modifying the state',()=>{
  const s=createGame(),before=structuredClone(s);
  assert.throws(()=>act(s,0,{type:'mulligan',indices:[1,1]}),RuleError);assert.deepEqual(s,before);
});
test('mulligan holds replaced cards out of the replacement draw',()=>{
  const s=createGame({first:0}),old=[...s.players[0].hand],next=s.players[0].deck.slice(0,4);
  const result=act(s,0,{type:'mulligan',indices:[0,1,2,3]});
  assert.deepEqual(result.players[0].hand,next);
  assert.equal(result.players[0].deck.length,16);
  for(const id of new Set(old))assert.equal(result.players[0].deck.filter(v=>v===id).length+next.filter(v=>v===id).length,DECKS.starter.cards.filter(v=>v===id).length);
});
test('first player skips first draw; second draws two and both start at one energy',()=>{
  let s=createGame({first:0});s=act(s,0,{type:'mulligan',indices:[]});s=act(s,1,{type:'mulligan',indices:[]});
  assert.equal(s.players[0].hand.length,4);assert.equal(s.players[0].energy,1);
  s=act(s,0,{type:'end'});assert.equal(s.players[1].hand.length,6);assert.equal(s.players[1].energy,1);
});
test('illegal player, insufficient energy and wrong target preserve input',()=>{
  const s=fixture();s.players[0].hand=[30];s.players[0].energy=1;const before=structuredClone(s);
  assert.throws(()=>act(s,1,{type:'end'}),RuleError);
  assert.throws(()=>act(s,0,{type:'play',index:0,target:'hero:1'}),RuleError);
  s.players[0].energy=8;assert.throws(()=>act(s,0,{type:'play',index:0,target:'unit:999'}),RuleError);
  s.players[0].energy=1;assert.deepEqual(s,before);
});
test('one attack per turn; entering attack phase blocks further plays',()=>{
  let s=fixture();const u=add(s,0,7);s.players[0].hand=[1];
  s=hit(s,u.uid,'hero:1');assert.equal(s.players[1].hp,17);
  assert.throws(()=>hit(s,u.uid,'hero:1'),RuleError);
  assert.throws(()=>act(s,0,{type:'play',index:0}),RuleError);
});
test('summoning sickness and Hızlı',()=>{
  let s=play(fixture(),1);assert.equal(canAttack(s,0,s.players[0].board[0]),false);
  s=play(fixture(),2);assert.equal(canAttack(s,0,s.players[0].board[0]),true);
});
test('guardian forces attack target; flying guardian cannot be hit by grounded unit',()=>{
  const s=fixture(),a=add(s,0,7),g=add(s,1,3,{keywords:['Koruyucu','Uçan']});
  assert.throws(()=>hit(s,a.uid,'hero:1'),RuleError);
  assert.throws(()=>hit(s,a.uid,`unit:${g.uid}`),RuleError);
  a.keywords.push('Uçan');assert.doesNotThrow(()=>hit(s,a.uid,`unit:${g.uid}`));
});
test('simultaneous combat and persistent wounds',()=>{
  let s=fixture(),a=add(s,0,7),b=add(s,1,13);
  s=hit(s,a.uid,`unit:${b.uid}`);assert.equal(s.players[0].board.length,0);assert.equal(s.players[1].board[0].hp,1);
  s=act(s,0,{type:'end'});assert.equal(s.players[1].board[0].hp,1);
});
test('flying attacker is immune to grounded combat counterdamage but not spells',()=>{
  let s=fixture(),a=add(s,0,25),b=add(s,1,27);
  s=hit(s,a.uid,`unit:${b.uid}`);assert.equal(s.players[0].board[0].hp,8);
  s=fixture();a=add(s,1,25);s=play(s,30,`unit:${a.uid}`);assert.equal(s.players[1].board[0].hp,5);
});
test('poison requires positive unprevented damage; simultaneous poison deaths',()=>{
  let s=fixture(),a=add(s,0,16),b=add(s,1,27,{shield:true});
  s=hit(s,a.uid,`unit:${b.uid}`);assert.equal(s.players[1].board[0].hp,8);
  s=fixture();a=add(s,0,16);b=add(s,1,16);s=hit(s,a.uid,`unit:${b.uid}`);
  assert.equal(s.players[0].board.length+s.players[1].board.length,0);
});
test('trap order: bounce first leaves later pit unused',()=>{
  let s=fixture(),a=add(s,0,7);trap(s,39);trap(s,36);
  s=hit(s,a.uid,'hero:1');assert.deepEqual(s.players[0].hand,[7]);assert.deepEqual(s.players[1].traps.map(t=>t.id),[36]);assert.equal(s.players[1].hp,20);
});
test('pit first leaves bounce unused; high-cost warrior bypasses pit',()=>{
  let s=fixture(),a=add(s,0,7);trap(s,36);trap(s,39);s=hit(s,a.uid,'hero:1');
  assert.equal(s.players[0].grave[0].id,7);assert.equal(s.players[1].traps[0].id,39);
  s=fixture();a=add(s,0,13);trap(s,36);s=hit(s,a.uid,'hero:1');assert.equal(s.players[1].traps.length,1);assert.equal(s.players[1].hp,16);
});
test('ambush kills Meddah before battlecry; surviving battlecry still resolves',()=>{
  let s=fixture();trap(s,40);s.players[0].deck=[1];s=play(s,8);
  assert.equal(s.players[0].deck.length,1);assert.equal(s.players[0].board.length,0);
  s=fixture();trap(s,40);s.players[0].hp=10;s=play(s,24);
  assert.equal(s.players[0].board[0].hp,6); // survives trap then heals itself
});
test('echo consumes one trap and spell energy without resolving spell',()=>{
  let s=fixture();trap(s,37);trap(s,37);s=play(s,30,'hero:1');
  assert.equal(s.players[0].energy,6);assert.equal(s.players[0].hand.length,0);assert.equal(s.players[1].hp,20);assert.equal(s.players[1].traps.length,1);
});
test('wall halves damage rounding down and expires at end of attacking turn',()=>{
  let s=fixture(),a=add(s,0,7);trap(s,38);s=hit(s,a.uid,'hero:1');assert.equal(s.players[1].hp,19);
  s=act(s,0,{type:'end'});assert.equal(s.players[1].half,false);
});
test('bounce to a full hand destroys warrior; normal bounce loses buffs',()=>{
  let s=fixture(),a=add(s,0,7,{attack:10});s.players[0].hand=Array(7).fill(1);trap(s,39);s=hit(s,a.uid,'hero:1');
  assert.equal(s.players[0].hand.length,7);assert.equal(s.players[0].grave[0].id,7);
  s=fixture();a=add(s,0,7,{attack:10});trap(s,39);s=hit(s,a.uid,'hero:1');
  s=act(s,0,{type:'end'});s=act(s,1,{type:'end'});s=act(s,0,{type:'play',index:0});assert.equal(s.players[0].board[0].attack,3);
});
test('hand, board and trap limits are enforced',()=>{
  let s=fixture();s.players[0].hand=[8,...Array(6).fill(1)];s.players[0].deck=[2,2];s=act(s,0,{type:'play',index:0});
  assert.equal(s.players[0].hand.length,7);s.players[0].hand=[32,...Array(6).fill(1)];s=act(s,0,{type:'play',index:0});assert.equal(s.players[0].hand.length,7);
  s=fixture();for(let i=0;i<5;i++)add(s,0,1);assert.throws(()=>play(s,2),RuleError);
  s=fixture();s.players[0].traps=[{uid:1,id:36},{uid:2,id:37}];assert.throws(()=>play(s,38),RuleError);
});
test('fatigue damages for every unsuccessful draw and can terminate Pazar',()=>{
  let s=fixture();s.players[0].deck=[];s.players[0].hp=1;s=play(s,32);
  assert.equal(s.status,'finished');assert.equal(s.winner,1);assert.equal(s.pending,null);
  s=fixture();s.players[0].deck=[];s=play(s,32);assert.equal(s.players[0].hp,18);
});
test('draw-discard choice blocks other actions and accepts chosen hand index',()=>{
  let s=fixture();s.players[0].deck=[1,2];s=play(s,32);assert.equal(s.pending.kind,'discard');
  assert.throws(()=>act(s,0,{type:'end'}),RuleError);s=act(s,0,{type:'discard',index:1});assert.deepEqual(s.players[0].hand,[1]);
});
test('Ney, Bozkır and Karagöz apply hero effects; hero healing is capped',()=>{
  let s=fixture();s.players[0].hp=19;s=play(s,4);assert.equal(s.players[0].hp,20);
  s=play(fixture(),5);assert.equal(s.players[1].hp,19);
  s=play(fixture(),19);assert.equal(s.players[1].hp,18);
  s=fixture();s.players[0].hp=19;s=play(s,29,'hero:0');assert.equal(s.players[0].hp,20);
});
test('permanent stat buffs raise current and maximum hp, and wolf aura is dynamic',()=>{
  let s=fixture(),u=add(s,0,1,{hp:1});s=play(s,11,`unit:${u.uid}`);
  assert.equal(s.players[0].board[0].hp,2);assert.equal(s.players[0].board[0].maxHp,3);assert.equal(s.players[0].board[0].attack,2);
  s.players[0].energy=8;s=play(s,20,`unit:${u.uid}`);assert.equal(s.players[0].board[0].maxHp,5);
  s=fixture();u=add(s,0,21);assert.equal(attackValue(s,0,u),5);add(s,0,1);assert.equal(attackValue(s,0,u),6);
});
test('merchant grants one immediate energy up to eight; Tepegöz self-damages',()=>{
  let s=play(fixture(),10);assert.equal(s.players[0].energy,6);
  s=play(fixture(),18);assert.equal(s.players[0].board[0].hp,2);
});
test('Hoca selects strongest with oldest tie; freeze expires after next owner turn',()=>{
  let s=fixture(),a=add(s,1,13),b=add(s,1,13);s=play(s,12);
  assert.equal(s.players[1].board[0].skipUntil,3);assert.equal(s.players[1].board[1].skipUntil,0);
  s=act(s,0,{type:'end'});assert.equal(canAttack(s,1,s.players[1].board[0]),false);assert.equal(canAttack(s,1,s.players[1].board[1]),true);
  s=act(s,1,{type:'end'});s=act(s,0,{type:'end'});assert.equal(canAttack(s,1,s.players[1].board[0]),true);
});
test('snow freezes current enemies but not warriors summoned later',()=>{
  let s=fixture();add(s,1,7);s=play(s,33);s=act(s,0,{type:'end'});s.players[1].hand=[2];s=act(s,1,{type:'play',index:0});
  assert.equal(canAttack(s,1,s.players[1].board[0]),false);assert.equal(canAttack(s,1,s.players[1].board[1]),true);
});
test('Dede scry occurs before draw and only on owner turn',()=>{
  let s=fixture();add(s,0,23);s.players[0].deck=[1,2,3];s=act(s,0,{type:'end'});assert.equal(s.pending,null);
  s=act(s,1,{type:'end'});assert.equal(s.pending.kind,'scry');assert.equal(s.players[0].hand.length,0);
  s=act(s,0,{type:'scry',bottom:true});assert.deepEqual(s.players[0].hand,[2]);assert.deepEqual(s.players[0].deck,[3,1]);
});
test('resurrection resets stats, consumes chosen grave entry and never repeats battlecry',()=>{
  let s=fixture();s.players[0].grave=[{id:19,uid:99},{id:2,uid:100}];s=play(s,26,'grave:99');
  assert.equal(s.players[1].hp,20);assert.equal(s.players[0].board[1].hp,5);assert.equal(s.players[0].board[1].exhausted,true);assert.equal(s.players[0].grave.length,1);
  s=fixture();for(let i=0;i<4;i++)add(s,0,1);s.players[0].grave=[{id:2,uid:99}];s=play(s,26);assert.equal(s.players[0].board.length,5);assert.equal(s.players[0].grave.length,1);
});
test('temporary attack and shield expire; permanent Ergenekon buffs persist',()=>{
  let s=fixture(),u=add(s,0,7);s=play(s,28,`unit:${u.uid}`);s.players[0].energy=8;s=play(s,31,`unit:${u.uid}`);s.players[0].energy=8;s=play(s,35);
  assert.equal(attackValue(s,0,s.players[0].board[0]),7);assert.equal(s.players[0].board[0].shield,true);
  s=act(s,0,{type:'end'});assert.equal(attackValue(s,0,s.players[0].board[0]),5);assert.equal(s.players[0].board[0].shield,false);assert.equal(s.players[0].board[0].maxHp,4);
});
test('topçu targets enemy; Kızılelma and Tufan hit correct sides',()=>{
  let s=fixture(),a=add(s,0,13),b=add(s,1,13);s=play(s,22,`unit:${b.uid}`);assert.equal(s.players[1].board[0].hp,1);assert.equal(s.players[0].board[0].hp,4);
  s=fixture();add(s,0,13);add(s,1,13);s=play(s,27);assert.equal(s.players[1].board[0].hp,2);assert.equal(s.players[0].board[0].hp,4);
  s=fixture();add(s,0,13);add(s,1,13);s=play(s,34);assert.equal(s.players[0].board[0].hp,2);assert.equal(s.players[1].board[0].hp,2);
});
test('all 40 cards can be played in valid representative scenarios',()=>{
  for(const c of CARDS){
    const s=fixture();add(s,0,13);add(s,1,13);s.players[0].grave=[{id:2,uid:999}];s.players[0].hand=[c.id];
    const action=legalActions(s,0).find(a=>a.type==='play');assert.ok(action,c.name);
    const result=act(s,0,action);assert.equal(result.players[0].energy,8-c.cost+(c.id===10?1:0),c.name);
  }
});
test('turn limit uses forty player turns with a draw on equal hp',()=>{
  let s=fixture();s.turn=40;s=act(s,0,{type:'end'});assert.equal(s.status,'finished');assert.equal(s.winner,null);
  s=fixture();s.turn=40;s.players[1].hp=19;s=act(s,0,{type:'end'});assert.equal(s.winner,0);
});
test('lethal damage, surrender and rejecting actions after finish',()=>{
  let s=fixture();s.players[1].hp=3;s=play(s,30,'hero:1');assert.equal(s.winner,0);assert.equal(s.pending,null);
  assert.throws(()=>act(s,0,{type:'end'}),RuleError);
  s=act(fixture(),1,{type:'surrender'});assert.equal(s.winner,0);
});
test('replays reconstruct full state and reject altered illegal actions',()=>{
  let s=createGame({seed:342,decks:[DECKS.control.cards,DECKS.tempo.cards]});
  for(let i=0;i<300 && s.status!=='finished';i++)s=act(s,s.active,chooseBotAction(s));
  assert.equal(s.status,'finished');assert.deepEqual(restoreReplay(JSON.parse(JSON.stringify(exportReplay(s)))),s);
  const bad=exportReplay(s);bad.history=[{p:0,action:{type:'play',index:0}}];assert.throws(()=>restoreReplay(bad),RuleError);
});
test('opponent card draws and trap identities are absent from public log',()=>{
  let s=fixture();s.players[1].hand=[36];s=act(s,0,{type:'end'});s=act(s,1,{type:'play',index:0});
  assert.ok(!s.log.some(line=>line.includes('Tuzak Kuyu')));
});
test('bot decisions do not depend on opponent private hand or deck',()=>{
  const s=fixture();s.players[0].hand=[7,30];add(s,1,1);
  const a=chooseBotAction(s,0),modified=structuredClone(s);modified.players[1].hand=[27,27,27];modified.players[1].deck=[];
  assert.deepEqual(chooseBotAction(modified,0),a);
});
