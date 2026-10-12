import test from 'node:test';
import assert from 'node:assert/strict';
import { CHAPTERS, chapterCompleted,chapterOptions } from '../oyun/chapters.js';
import { validateDeck, createGame, applyAction } from '../oyun/engine.js';
import { chooseBotAction } from '../oyun/bot.js';
test('all ten chapters have legal decks and distinct ordered identities',()=>{
  assert.deepEqual(CHAPTERS.map(c=>c.id),[1,2,3,4,5,6,7,8,9,10]);
  for(const c of CHAPTERS){validateDeck(c.deck);validateDeck(c.foe);assert.ok(c.dialogue&&c.task);}
});
test('chapter completion requires both victory and the taught mechanic',()=>{
  const s={status:'finished',winner:0,players:[{stats:{cardPlays:{1:1},attacks:0}}]};
  assert.equal(chapterCompleted(CHAPTERS[0],s),false);
  s.players[0].stats.attacks=1;assert.equal(chapterCompleted(CHAPTERS[0],s),true);
  s.winner=1;assert.equal(chapterCompleted(CHAPTERS[0],s),false);
  s.winner=0;s.players[0].stats.cardPlays={1:1,30:1,36:1};assert.equal(chapterCompleted(CHAPTERS[9],s),true);
});
test('every chapter goal is reachable in a complete game with legal actions',()=>{
  for(const chapter of CHAPTERS){
    let completed=false;
    for(let seed=1;seed<=100&&!completed;seed++){
      let s=createGame(chapterOptions(chapter,seed));
      for(let step=0;step<1500&&s.status!=='finished';step++){
        const action=chapter.passive&&s.active===1&&s.status==='playing'&&!s.pending?{type:'end'}:chooseBotAction(s);
        s=applyAction(s,s.active,action);
      }
      assert.equal(s.status,'finished',chapter.title);
      completed=chapterCompleted(chapter,s);
    }
    assert.ok(completed,`${chapter.title}: görevli galibiyet bulunamadı`);
  }
});
test('story mission cards are present without duplication and cannot be mulliganed away',()=>{
  for(const chapter of CHAPTERS){
    const s=createGame(chapterOptions(chapter,23));
    const player=s.players[0];assert.equal(player.hand.length,4);assert.equal(player.deck.length,16);
    for(const id of player.mulliganPinned){const index=player.hand.indexOf(id);assert.ok(index>=0);assert.throws(()=>applyAction(s,0,{type:'mulligan',indices:[index]}));}
    const total=[...player.deck,...player.hand].sort((a,b)=>a-b);assert.deepEqual(total,[...chapter.deck].sort((a,b)=>a-b));
  }
});
