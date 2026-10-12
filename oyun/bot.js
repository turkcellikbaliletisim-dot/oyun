import { CARD_BY_ID } from './cards.js';
import { legalActions, attackValue, resolveTarget } from './engine.js';

// Bot yalnız kendi eli ve açık saha üzerinden karar verir. Öğrenme rakibidir.
export function chooseBotAction(s, p = s.active) {
  if (s.status === 'mulligan') return { type: 'mulligan', indices: s.players[p].hand.map((id,i) => CARD_BY_ID[id].cost > 3 ? i : -1).filter(i => i >= 0) };
  const actions = legalActions(s, p);
  if (!actions.length) return null;
  if (s.pending?.kind === 'scry') return { type: 'scry', bottom: CARD_BY_ID[s.players[p].deck[0]].cost > s.players[p].maxEnergy + 1 };
  if (s.pending?.kind === 'discard') return [...actions].sort((a,b) => CARD_BY_ID[s.players[p].hand[b.index]].cost - CARD_BY_ID[s.players[p].hand[a.index]].cost)[0];
  function score(a) {
    if (a.type === 'end') return -1;
    const target = resolveTarget(s, a.target);
    if (a.type === 'play') {
      const c = CARD_BY_ID[s.players[p].hand[a.index]];
      let value = 10 + c.cost;
      if (c.type === 'warrior') value += 10;
      if ([29,30].includes(c.id)) {
        const friendly = target?.p === p;
        if (c.id === 30 && friendly || c.id === 29 && !friendly) return -100;
        if (c.id === 29) {
          const missing = (target.kind === 'hero' ? 20 : target.value.maxHp) - target.value.hp;
          if (!missing) return -10;
          value += Math.min(3, missing);
        } else if (target.kind === 'hero' && target.value.hp <= 3) value += 1000;
        else if (target.kind === 'unit' && target.value.hp <= 3) value += 10;
      }
      if ([28,31].includes(c.id) && target?.value.exhausted) return -5;
      if ([33,34,35].includes(c.id)) {
        const affected = c.id === 35 ? s.players[p].board : s.players[1-p].board;
        if (!affected.length) return -10;
      }
      return value;
    }
    const u = s.players[p].board.find(unit => unit.uid === a.uid), atk = attackValue(s,p,u);
    if (target.kind === 'hero') return target.value.hp <= atk ? 1000 : 8 + atk;
    const killed = target.value.hp <= atk || u.keywords.includes('Zehirli');
    const survives = u.hp > attackValue(s,1-p,target.value) && !target.value.keywords.includes('Zehirli') || u.shield;
    return 7 + (killed ? CARD_BY_ID[target.value.id].cost + 8 : 0) + (survives ? 5 : -CARD_BY_ID[u.id].cost);
  }
  return [...actions].sort((a,b) => score(b) - score(a))[0];
}
