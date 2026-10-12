import { createGame, applyAction, exportReplay, restoreReplay } from '../oyun/engine.js';
import { DECKS } from '../oyun/decks.js';
import { chooseBotAction } from '../oyun/bot.js';
import assert from 'node:assert/strict';

const keys=Object.keys(DECKS),results=[];
for(let i=0;i<60;i++){
  const pair=Math.floor(i/20),a=keys[pair],b=keys[(pair+1)%3];
  let s=createGame({decks:[DECKS[a].cards,DECKS[b].cards],seed:Math.floor(i/2)+1,first:i%2});
  let steps=0;
  while(s.status!=='finished' && steps++<1500) s=applyAction(s,s.active,chooseBotAction(s));
  assert.equal(s.status,'finished',`Maç ${i} bitmedi`);
  assert.deepEqual(restoreReplay(exportReplay(s)),s,`Maç ${i} tekrar oynatılamadı`);
  for(const p of s.players){assert.ok(p.hand.length<=7);assert.ok(p.board.length<=5);assert.ok(p.traps.length<=2);}
  results.push({a,b,first:s.first,winner:s.winner,turn:s.turn,steps});
}
console.log('60 bot maçı tamamlandı; 60 yeniden oynatım ve tüm saha/el/tuzak sınırları doğrulandı.');
for(const a of keys){
  const matches=results.filter(r=>r.a===a);
  console.log(`${a} – ${matches[0].b}: ${matches.filter(r=>r.winner===0).length}/${matches.length} kazanma; ortalama ${(matches.reduce((sum,r)=>sum+r.turn,0)/matches.length/2).toFixed(1)} tam tur.`);
}
console.log('Bu otomatik çalışma insan oyun testi değildir; denge ve eğlenceyi kanıtlamaz.');
