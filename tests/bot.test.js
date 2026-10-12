import test from 'node:test';
import assert from 'node:assert/strict';
import {createGame,applyAction} from '../oyun/engine.js';
import {CARD_BY_ID} from '../oyun/cards.js';
import {chooseBotAction} from '../oyun/bot.js';
function game(hand){let s=createGame({first:0});s=applyAction(s,0,{type:'mulligan',indices:[]});s=applyAction(s,1,{type:'mulligan',indices:[]});s.players[0].energy=8;s.players[0].maxEnergy=8;s.players[0].hand=hand;return s;}
function unit(s,p,id,hp=CARD_BY_ID[id].hp){const c=CARD_BY_ID[id],u={uid:s.nextUid++,id,attack:c.attack,hp,maxHp:c.hp,tempAttack:0,shield:false,keywords:[...c.keywords],exhausted:false,skipUntil:0};s.players[p].board.push(u);return u;}
test('bot takes lethal before developing an expensive warrior',()=>{const s=game([27,30]);s.players[1].hp=3;assert.deepEqual(chooseBotAction(s),{type:'play',index:1,target:'hero:1'});});
test('bot takes lethal attack instead of locking itself into unnecessary plays',()=>{const s=game([13]);const u=unit(s,0,7);s.players[1].hp=3;assert.deepEqual(chooseBotAction(s),{type:'attack',uid:u.uid,target:'hero:1'});});
test('bot develops useful warriors before entering attack phase',()=>{const s=game([13]);unit(s,0,7);assert.deepEqual(chooseBotAction(s),{type:'play',index:0});});
test('bot does not wipe its own valuable army for a cheap enemy',()=>{const s=game([34]);unit(s,0,27,2);unit(s,1,1);const action=chooseBotAction(s);assert.notEqual(action.type,'play');const next=applyAction(s,0,action);assert.ok(next.players[0].board.some(u=>u.id===27));});
test('bot uses a shield when it enables a surviving combat trade',()=>{const s=game([31]);const u=unit(s,0,7);unit(s,1,15);assert.deepEqual(chooseBotAction(s),{type:'play',index:0,target:`unit:${u.uid}`});});
test('planning ignores hidden trap identities and unrevealed draw order',()=>{
  const s=game([8,30]);unit(s,1,1);s.players[1].traps=[{uid:20,id:37}];
  const other=structuredClone(s);other.players[1].traps[0].id=40;other.players[1].hand=[27];other.players[0].deck=Array(other.players[0].deck.length).fill(27);other.players[1].deck=Array(other.players[1].deck.length).fill(36);
  assert.deepEqual(chooseBotAction(s),chooseBotAction(other));
});
