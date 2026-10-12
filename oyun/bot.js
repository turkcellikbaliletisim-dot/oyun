import { CARD_BY_ID } from './cards.js';
import { legalActions, attackValue, resolveTarget, applyAction, attackTargets } from './engine.js';

// Planlama yalnız açık saha ve kendi eliyle yapılır. Gizli desteler, rakip eli
// ve kapalı tuzak kimlikleri değerlendirme simülasyonuna taşınmaz.
function visibleState(state,p) {
  const s=structuredClone(state);
  s.rng=1;s.seed=0;s.history=[];s.log=[];s.initial={};
  for(let i=0;i<2;i++){
    s.players[i].deck=Array(s.players[i].deck.length).fill(1);
    if(i!==p){s.players[i].hand=Array(s.players[i].hand.length).fill(1);s.players[i].unknownTraps=s.players[i].traps.length;s.players[i].traps=[];}
  }
  return s;
}
function unitValue(s,p,u) {
  const nextTurnFrozen=u.skipUntil>=s.players[p].turns+1;
  const baseAttack=attackValue(s,p,{...u,tempAttack:0});
  return baseAttack*1.8 + u.hp*.55 + CARD_BY_ID[u.id].cost*.2 +
    (u.keywords.includes('Koruyucu')?1.4:0) + (u.keywords.includes('Uçan')?2:0) +
    (u.keywords.includes('Zehirli')?2.2:0) - (nextTurnFrozen?baseAttack*.9:0);
}
function value(s,p) {
  if(s.status==='finished')return s.winner===null?0:s.winner===p?1000000:-1000000;
  const me=s.players[p],foe=s.players[1-p];
  const ownBoard=me.board.reduce((sum,u)=>sum+unitValue(s,p,u),0);
  const enemyBoard=foe.board.reduce((sum,u)=>sum+unitValue(s,1-p,u),0);
  const danger=foe.board.filter(u=>u.skipUntil<foe.turns+1).reduce((sum,u)=>sum+attackValue(s,1-p,u),0);
  const guardians=me.board.filter(u=>u.keywords.includes('Koruyucu')).reduce((sum,u)=>sum+u.hp,0);
  const exposed=Math.max(0,danger-guardians);
  return (ownBoard-enemyBoard)*1.5 + me.hp*1.1 - foe.hp*.85 +
    me.hand.length*1.6 + me.energy*.25 + me.traps.length*2.8 -
    Math.max(0,exposed-me.hp+4)*2.5;
}
function usefulHandCard(s,p,id) {
  const c=CARD_BY_ID[id],player=s.players[p],foe=s.players[1-p];
  if(c.cost>player.maxEnergy+2)return -5-c.cost;
  if(c.id===29)return player.hp<16?5:foe.board.length?1:-1;
  if(c.type==='warrior')return c.attack*1.4+c.hp*.4+(c.keywords.includes('Hızlı')?2:0);
  if(c.id===34)return foe.board.length*3-player.board.length*3;
  if(c.id===33)return foe.board.length*2;
  return c.cost+2;
}
export function chooseBotAction(state,p=state.active) {
  if(state.active!==p||state.status==='finished')return null;
  if(state.status==='mulligan')return {type:'mulligan',indices:state.players[p].hand.map((id,i)=>CARD_BY_ID[id].cost>3&&!state.players[p].mulliganPinned.includes(id)?i:-1).filter(i=>i>=0)};
  const actions=legalActions(state,p);
  if(!actions.length)return null;
  if(state.pending?.kind==='scry')return {type:'scry',bottom:CARD_BY_ID[state.players[p].deck[0]].cost>state.players[p].maxEnergy+1};
  if(state.pending?.kind==='discard')return [...actions].sort((a,b)=>usefulHandCard(state,p,state.players[p].hand[a.index])-usefulHandCard(state,p,state.players[p].hand[b.index]))[0];
  const s=visibleState(state,p),baseline=value(s,p);
  const score=a=>{
    if(a.type==='end')return 0;
    const c=a.type==='play'?CARD_BY_ID[s.players[p].hand[a.index]]:null;
    const target=resolveTarget(s,a.target);
    if(c?.id===30&&target?.p===p || c?.id===29&&target?.p!==p)return -Infinity;
    if(c&&[28,31].includes(c.id)&&(!target||!attackTargets(s,p,target.value).length))return -Infinity;
    const next=applyAction(s,p,a);
    let delta=value(next,p)-baseline;
    if(c&&[28,31].includes(c.id)){
      const uid=target.value.uid;
      const before=legalActions(s,p).filter(b=>b.type==='attack'&&b.uid===uid).reduce((best,b)=>Math.max(best,value(applyAction(s,p,b),p)-baseline),0);
      const after=legalActions(next,p).filter(b=>b.type==='attack'&&b.uid===uid).reduce((best,b)=>Math.max(best,value(applyAction(next,p,b),p)-baseline),-Infinity);
      delta=Math.max(delta,after-before);
    }
    return delta;
  };
  const ranked=actions.map(action=>({action,score:score(action)})).sort((a,b)=>b.score-a.score);
  // Önce kazanma; sonra olumlu kart oyunları; ardından saldırılar. Böylece
  // yüksek puanlı bir saldırıyla ana fazı erken kapatıp kartları elde bırakmaz.
  if(ranked[0].score>=900000)return ranked[0].action;
  const play=ranked.find(r=>r.action.type==='play'&&r.score>.01);
  if(play)return play.action;
  const attack=ranked.find(r=>r.action.type==='attack'&&r.score>.01);
  if(attack)return attack.action;
  return {type:'end'};
}
