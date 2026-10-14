// JS motoru ile GDScript çevrimdışı motoru arasındaki çapraz doğrulama verisini üretir.
// Kullanım: node tests/offline-parity.js <çıktı.json>
import {writeFileSync} from 'node:fs';
import {randomInt} from 'node:crypto';
import {createGame,applyAction,legalActions} from '../oyun/engine.js';
import {chooseBotAction} from '../oyun/bot.js';
import {DECKS} from '../oyun/decks.js';
import {CHAPTERS,chapterOptions} from '../oyun/chapters.js';

const canon=v=>Array.isArray(v)?v.map(canon):v&&typeof v==='object'?Object.fromEntries(Object.keys(v).sort().map(k=>[k,canon(v[k])])):v;
const finger=s=>canon({active:s.active,turn:s.turn,status:s.status,winner:s.winner,reason:s.reason,pending:s.pending,nextUid:s.nextUid,first:s.first,phase:s.phase,log:s.log.length,
  players:s.players.map(p=>({hp:p.hp,energy:p.energy,maxEnergy:p.maxEnergy,turns:p.turns,half:p.half,deck:p.deck,hand:p.hand,board:p.board,traps:p.traps,grave:p.grave,stats:p.stats,pinned:p.mulliganPinned}))});
const entropy=()=>Array.from({length:80},()=>randomInt(0,4294967296));
const names=Object.keys(DECKS);
const games=[];
function record(options,label){
  let s=createGame(options);const steps=[];let guard=0;
  while(s.status!=='finished'&&guard++<600){
    const p=s.active;
    const action=chooseBotAction(s,p);
    if(!action)break;
    s=applyAction(s,p,action);
    steps.push({p,action,fp:finger(s)});
  }
  games.push({label,options,start:finger(createGame(options)),steps});
}
for(let i=0;i<40;i++){
  const a=names[i%3],b=names[(i+1+Math.floor(i/3))%3];
  record({decks:[DECKS[a].cards,DECKS[b].cards],seed:0,entropy:entropy()},`${a}-vs-${b}-${i}`);
}
for(const chapter of CHAPTERS){
  const o=chapterOptions(chapter,0);
  record({...o,entropy:entropy()},`chapter-${chapter.id}`);
}
writeFileSync(process.argv[2],JSON.stringify(games));
console.log(`${games.length} oyun, ${games.reduce((n,g)=>n+g.steps.length,0)} adım`);
