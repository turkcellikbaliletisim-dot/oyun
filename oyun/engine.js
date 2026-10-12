import { CARD_BY_ID } from './cards.js';
import { DECKS } from './decks.js';

export const RULE_VERSION = '0.2';
export const LIMITS = { hand: 7, board: 5, traps: 2, hp: 20, energy: 8, turns: 40 };
export class RuleError extends Error {}
const requireRule = (condition, message) => { if (!condition) throw new RuleError(message); };
const card = id => CARD_BY_ID[id];
const enemy = p => 1 - p;
const note = (s, message) => { s.log.push(message); if (s.log.length > 100) s.log.shift(); };

export function validateDeck(deck) {
  requireRule(Array.isArray(deck) && deck.length === 20, 'Deste tam 20 kart olmalı.');
  const counts = {};
  for (const id of deck) {
    requireRule(Number.isInteger(id) && !!card(id), 'Bilinmeyen kart.');
    counts[id] = (counts[id] || 0) + 1;
    requireRule(counts[id] <= (card(id).rarity === 'legendary' ? 1 : 2), `${card(id).name}: kopya sınırı aşıldı.`);
  }
  return true;
}

// Tekrarlanabilir karıştırma; güvenli/çevrimiçi rastgelelik yerine geçmez.
function random(s) {
  s.rng = (s.rng + 0x6D2B79F5) >>> 0;
  let t = Math.imul(s.rng ^ (s.rng >>> 15), 1 | s.rng);
  t ^= t + Math.imul(t ^ (t >>> 7), 61 | t);
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
}
function shuffle(s, list) {
  for (let i = list.length - 1; i > 0; i--) {
    const j = Math.floor(random(s) * (i + 1));
    [list[i], list[j]] = [list[j], list[i]];
  }
}

export function createGame({ decks = [DECKS.starter.cards, DECKS.starter.cards], seed = 1, first, opening, pinned } = {}) {
  requireRule(Array.isArray(decks) && decks.length === 2, 'İki deste gerekir.');
  decks.forEach(validateDeck);
  requireRule(Number.isInteger(seed) && seed >= 0 && seed <= 0xffffffff, 'Tohum 0–4294967295 arası tam sayı olmalı.');
  requireRule(first === undefined || first === 0 || first === 1, 'Başlangıç oyuncusu geçersiz.');
  if(opening!==undefined){
    requireRule(Array.isArray(opening)&&opening.length===2,'İki başlangıç eli gerekir.');
    for(let p=0;p<2;p++){
      requireRule(Array.isArray(opening[p])&&opening[p].length<=4,'Başlangıç seçimi en çok dört karttır.');
      const available=[...decks[p]];
      for(const id of opening[p]){const index=available.indexOf(id);requireRule(index>=0,'Başlangıç kartı destede bulunmalı.');available.splice(index,1);}
    }
  }
  if(pinned!==undefined)requireRule(opening&&Array.isArray(pinned)&&pinned.length===2&&pinned.every((ids,p)=>Array.isArray(ids)&&new Set(ids).size===ids.length&&ids.every(id=>opening[p].includes(id))),'Korunan kart başlangıç elinde bulunmalı.');
  const s = {
    version: RULE_VERSION, seed, rng: seed >>> 0, nextUid: 1,
    status: 'mulligan', active: 0, first: 0, turn: 0, phase: 'main',
    winner: null, reason: null, pending: null, log: [], history: [],
    players: decks.map(deck => ({ hp: 20, energy: 0, maxEnergy: 0, turns: 0,
      deck: [...deck], hand: [], board: [], traps: [], grave: [], half: false,
      stats: { cardPlays: {}, attacks: 0, energySpent: 0 },mulliganPinned:[] })),
    initial: { decks: decks.map(d => [...d]), seed, ...(first === undefined ? {} : { first }),...(opening===undefined?{}:{opening:opening.map(ids=>[...ids])}),...(pinned===undefined?{}:{pinned:pinned.map(ids=>[...ids])}) },
  };
  s.first = first ?? Math.floor(random(s) * 2);
  for (let p = 0; p < 2; p++) {
    shuffle(s,s.players[p].deck);
    for(const id of opening?.[p]??[]){const index=s.players[p].deck.indexOf(id);s.players[p].hand.push(s.players[p].deck.splice(index,1)[0]);}
    s.players[p].mulliganPinned=[...(pinned?.[p]??[])];
    while(s.players[p].hand.length<4)draw(s,p);
  }
  note(s, `İlk oyuncu: ${s.first === 0 ? 'Destancı' : 'Gölge'}. Başlangıç ellerini seçin.`);
  return s;
}

export function attackValue(s, p, unit) {
  return Math.max(0, unit.attack + unit.tempAttack + (unit.id === 21 ? s.players[p].board.length - 1 : 0));
}
export function canAttack(s, p, unit) {
  return s.status === 'playing' && s.active === p && !s.pending && !unit.exhausted &&
    unit.skipUntil < s.players[p].turns && attackValue(s, p, unit) > 0;
}
export function resolveTarget(s, target) {
  if (typeof target !== 'string') return null;
  const hero = /^hero:([01])$/.exec(target);
  if (hero) return { kind: 'hero', p: Number(hero[1]), value: s.players[Number(hero[1])] };
  const match = /^unit:(\d+)$/.exec(target);
  if (match) for (let p = 0; p < 2; p++) {
    const unit = s.players[p].board.find(u => u.uid === Number(match[1]));
    if (unit) return { kind: 'unit', p, value: unit };
  }
  return null;
}
const unitTarget = u => `unit:${u.uid}`;

function conclude(s) {
  const dead = s.players.map(p => p.hp <= 0);
  if (dead.some(Boolean)) {
    s.status = 'finished'; s.winner = dead[0] && dead[1] ? null : dead[0] ? 1 : 0;
    s.reason = 'can'; s.pending = null;
  }
}
function cleanup(s) {
  for (let p = 0; p < 2; p++) {
    const player = s.players[p];
    for (const u of player.board.filter(u => u.hp <= 0)) {
      player.grave.push({ id: u.id, uid: u.uid });
      note(s, `${card(u.id).name} yok edildi.`);
    }
    player.board = player.board.filter(u => u.hp > 0);
  }
  conclude(s);
}

function damage(s, target, amount, { source = 'ability', flying = false, poison = false } = {}) {
  const t = resolveTarget(s, target);
  if (!t) return 0;
  if (t.kind === 'unit' && (t.value.shield ||
      (source === 'combat' && t.value.keywords.includes('Uçan') && !flying))) return 0;
  let actual = Math.max(0, amount);
  if (s.players[t.p].half) actual = Math.floor(actual / 2);
  t.value.hp -= actual;
  if (t.kind === 'unit' && poison && actual > 0) t.value.hp = 0;
  return actual;
}
function heal(s, target, amount) {
  const t = resolveTarget(s, target);
  if (t) t.value.hp = Math.min(t.kind === 'hero' ? 20 : t.value.maxHp, t.value.hp + amount);
}
function draw(s, p) {
  const player = s.players[p];
  if (!player.deck.length) {
    damage(s, `hero:${p}`, 1); note(s, `${p === 0 ? 'Destancı' : 'Gölge'} boş desteden 1 hasar aldı.`); conclude(s);
    return;
  }
  const id = player.deck.shift();
  if (player.hand.length < 7) player.hand.push(id);
  else note(s, `Dolu el: ${card(id).name} yakıldı.`);
}
function summon(s, p, id) {
  const c = card(id);
  const unit = { uid: s.nextUid++, id, attack: c.attack, hp: c.hp, maxHp: c.hp,
    tempAttack: 0, shield: false, keywords: [...c.keywords], exhausted: !c.keywords.includes('Hızlı'), skipUntil: 0 };
  s.players[p].board.push(unit);
  return unit;
}
function finishStart(s) {
  s.pending = null;
  const p = s.active, player = s.players[p];
  if (player.turns === 1 && p === s.first) return;
  draw(s, p);
  if (s.status === 'playing' && player.turns === 1 && p !== s.first) draw(s, p);
}
function beginTurn(s, p) {
  s.active = p; s.turn++; s.phase = 'main';
  const player = s.players[p];
  player.turns++; player.maxEnergy = Math.min(8, player.maxEnergy + 1); player.energy = player.maxEnergy;
  for (const u of player.board) u.exhausted = false;
  note(s, `${p === 0 ? 'Destancı' : 'Gölge'} · tur ${player.turns} · ${player.energy} enerji.`);
  const sages = player.board.filter(u => u.id === 23).map(u => u.uid);
  if (sages.length && player.deck.length) s.pending = { kind: 'scry', units: sages };
  else finishStart(s);
}
function endTurn(s) {
  for (const player of s.players) {
    player.half = false;
    for (const u of player.board) { u.tempAttack = 0; u.shield = false; }
  }
  if (s.turn >= LIMITS.turns) {
    s.status = 'finished'; s.reason = 'tur sınırı';
    const [a, b] = s.players.map(p => p.hp);
    s.winner = a === b ? null : a > b ? 0 : 1;
  } else beginTurn(s, enemy(s.active));
}

export function playTargets(s, p, id) {
  const friendly = s.players[p].board.map(unitTarget), foes = s.players[enemy(p)].board.map(unitTarget);
  if ([11,20,28,31].includes(id)) return friendly;
  if (id === 22) return foes;
  if ([29,30].includes(id)) return [`hero:${p}`, `hero:${enemy(p)}`, ...friendly, ...foes];
  if (id === 26 && s.players[p].board.length < 4) return s.players[p].grave.map(g => `grave:${g.uid}`);
  return [];
}
function targetsRequired(id) { return [11,20,22,26,28,29,30,31].includes(id); }
export function attackTargets(s, p, unit) {
  if (!canAttack(s, p, unit)) return [];
  const foes = s.players[enemy(p)].board;
  const guardians = foes.filter(u => u.keywords.includes('Koruyucu'));
  const targets = guardians.length ? guardians : foes;
  const reachable = targets.filter(u => !u.keywords.includes('Uçan') || unit.keywords.includes('Uçan'));
  return [...(guardians.length ? [] : [`hero:${enemy(p)}`]), ...reachable.map(unitTarget)];
}
function freeze(s, p, units) { for (const u of units) u.skipUntil = Math.max(u.skipUntil, s.players[p].turns + 1); }

function effects(s, p, id, target) {
  const player = s.players[p], foe = s.players[enemy(p)];
  const t = resolveTarget(s, target);
  switch (id) {
    case 4: heal(s, `hero:${p}`, 1); break;
    case 5: damage(s, `hero:${enemy(p)}`, 1); break;
    case 8: draw(s, p); break;
    case 10: player.energy = Math.min(8, player.energy + 1); break;
    case 11: if (t) { t.value.attack++; t.value.hp++; t.value.maxHp++; } break;
    case 12: {
      const strongest = [...foe.board].sort((a,b) => attackValue(s, enemy(p), b) - attackValue(s, enemy(p), a) || a.uid - b.uid)[0];
      if (strongest) freeze(s, enemy(p), [strongest]);
      break;
    }
    case 18: damage(s, unitTarget(player.board.at(-1)), 1); break;
    case 19: damage(s, `hero:${enemy(p)}`, 2); break;
    case 20: if (t) { t.value.hp += 2; t.value.maxHp += 2; } break;
    case 22: if (t) damage(s, target, 3); break;
    case 24: for (const u of player.board) u.hp = u.maxHp; break;
    case 26: {
      const index = player.grave.findIndex(g => `grave:${g.uid}` === target);
      if (index >= 0 && player.board.length < 5) summon(s, p, player.grave.splice(index, 1)[0].id);
      break;
    }
    case 27: for (const u of foe.board) damage(s, unitTarget(u), 2); break;
    case 28: t.value.tempAttack += 2; break;
    case 29: heal(s, target, 3); break;
    case 30: damage(s, target, 3); break;
    case 31: t.value.shield = true; break;
    case 32:
      draw(s, p); if (s.status === 'playing') draw(s, p);
      if (s.status === 'playing' && player.hand.length) s.pending = { kind: 'discard' };
      break;
    case 33: freeze(s, enemy(p), foe.board); break;
    case 34: for (const side of s.players) for (const u of side.board) damage(s, unitTarget(u), 2); break;
    case 35: for (const u of player.board) { u.attack += 2; u.hp += 2; u.maxHp += 2; } break;
  }
  cleanup(s);
}

function triggerTraps(s, owner, event, unit) {
  const player = s.players[owner];
  for (const trap of [...player.traps]) {
    const alive = unit && s.players[enemy(owner)].board.some(u => u.uid === unit.uid);
    if (event === 'spell' && trap.id === 37) {
      player.traps = player.traps.filter(t => t.uid !== trap.uid);
      note(s, 'Yankı açıldı; büyü iptal edildi.'); return true;
    }
    if (!alive) continue;
    const triggers = event === 'summon' && trap.id === 40 || event === 'attack' &&
      (trap.id === 39 || trap.id === 38 || trap.id === 36 && card(unit.id).cost <= 3);
    if (!triggers) continue;
    player.traps = player.traps.filter(t => t.uid !== trap.uid);
    note(s, `${card(trap.id).name} açıldı.`);
    if (trap.id === 40) damage(s, unitTarget(unit), 4);
    if (trap.id === 36) unit.hp = 0; // Yok etme, hasar bağışıklığından etkilenmez.
    if (trap.id === 38) player.half = true;
    if (trap.id === 39) {
      const attacker = s.players[enemy(owner)];
      if (attacker.hand.length < 7) {
        attacker.board = attacker.board.filter(u => u.uid !== unit.uid); attacker.hand.push(unit.id);
      } else unit.hp = 0;
    }
    cleanup(s);
    if (s.status !== 'playing') break;
  }
  return false;
}

function play(s, p, action) {
  requireRule(s.phase === 'main', 'Saldırı fazında kart oynanamaz.');
  const player = s.players[p];
  requireRule(Number.isInteger(action.index) && action.index >= 0 && action.index < player.hand.length, 'Geçersiz el kartı.');
  const id = player.hand[action.index], c = card(id);
  requireRule(player.energy >= c.cost, 'Yeterli enerji yok.');
  if (c.type === 'warrior') requireRule(player.board.length < 5, 'Saha dolu.');
  if (c.type === 'trap') requireRule(player.traps.length < 2, 'Tuzak alanı dolu.');
  const targets = playTargets(s, p, id);
  if (targetsRequired(id)) {
    if (!targets.length && c.type === 'warrior') requireRule(action.target == null, 'Geçerli hedef yok.');
    else requireRule(targets.includes(action.target), 'Geçerli hedef seç.');
  } else requireRule(action.target == null, 'Bu kart hedef istemez.');
  player.energy -= c.cost; player.hand.splice(action.index, 1);
  player.stats.cardPlays[id] = (player.stats.cardPlays[id] || 0) + 1;
  player.stats.energySpent += c.cost;
  note(s, c.type === 'trap' ? `${p === 0 ? 'Destancı' : 'Gölge'} gizli bir tuzak kurdu.` : `${p === 0 ? 'Destancı' : 'Gölge'}: ${c.name}.`);
  if (c.type === 'trap') player.traps.push({ uid: s.nextUid++, id });
  else if (c.type === 'spell') {
    if (!triggerTraps(s, enemy(p), 'spell')) effects(s, p, id, action.target);
  } else {
    const unit = summon(s, p, id);
    triggerTraps(s, enemy(p), 'summon', unit);
    if (s.status === 'playing' && player.board.some(u => u.uid === unit.uid)) effects(s, p, id, action.target);
  }
}
function attack(s, p, action) {
  const unit = s.players[p].board.find(u => u.uid === action.uid);
  requireRule(unit && attackTargets(s, p, unit).includes(action.target), 'Bu saldırı geçerli değil.');
  s.phase = 'attack'; unit.exhausted = true;
  s.players[p].stats.attacks++;
  note(s, `${card(unit.id).name} saldırıyor.`);
  triggerTraps(s, enemy(p), 'attack', unit);
  if (s.status !== 'playing' || !s.players[p].board.some(u => u.uid === unit.uid)) return;
  const target = resolveTarget(s, action.target);
  if (!target) return;
  const atk = attackValue(s, p, unit), flying = unit.keywords.includes('Uçan'), poison = unit.keywords.includes('Zehirli');
  if (target.kind === 'unit') {
    const counter = attackValue(s, enemy(p), target.value);
    // Her iki hasar da ölüm temizliği yapılmadan uygulanır.
    damage(s, action.target, atk, { source: 'combat', flying, poison });
    damage(s, unitTarget(unit), counter, { source: 'combat', flying: target.value.keywords.includes('Uçan'), poison: target.value.keywords.includes('Zehirli') });
  } else damage(s, action.target, atk, { source: 'combat' });
  cleanup(s);
}

export function applyAction(state, p, action) {
  requireRule(p === 0 || p === 1, 'Geçersiz oyuncu.');
  requireRule(action && typeof action.type === 'string', 'Geçersiz hamle.');
  requireRule(state.status !== 'finished', 'Maç bitmiş.');
  const s = structuredClone(state);
  if (action.type === 'surrender') {
    s.status = 'finished'; s.winner = enemy(p); s.reason = 'teslim'; s.pending = null;
  } else {
    requireRule(s.active === p, 'Sıra sende değil.');
    if (s.status === 'mulligan') {
      requireRule(action.type === 'mulligan' && Array.isArray(action.indices), 'Başlangıç elini seç.');
      const indices = [...new Set(action.indices)];
      requireRule(indices.length === action.indices.length && indices.every(i => Number.isInteger(i) && i >= 0 && i < 4), 'Geçersiz mulligan seçimi.');
      requireRule(indices.every(i=>!s.players[p].mulliganPinned.includes(s.players[p].hand[i])),'Hikâye görev kartı başlangıç elinde korunur.');
      const player = s.players[p], held = indices.map(i => player.hand[i]);
      player.hand = player.hand.filter((_,i) => !indices.includes(i));
      for (const _ of held) draw(s, p);
      player.deck.push(...held); shuffle(s, player.deck);
      note(s, `${p === 0 ? 'Destancı' : 'Gölge'} ${held.length} kart değiştirdi.`);
      if (p === 0) s.active = 1;
      else { s.status = 'playing'; beginTurn(s, s.first); }
    } else if (s.pending) {
      if (s.pending.kind === 'scry') {
        requireRule(action.type === 'scry' && typeof action.bottom === 'boolean', 'Üst kartı tut veya alta koy.');
        if (action.bottom) { const deck = s.players[p].deck; deck.push(deck.shift()); }
        s.pending.units.shift();
        if (!s.pending.units.length) finishStart(s);
      } else {
        requireRule(action.type === 'discard' && Number.isInteger(action.index) && action.index >= 0 && action.index < s.players[p].hand.length, 'Atılacak kartı seç.');
        s.players[p].hand.splice(action.index, 1); s.pending = null;
        note(s, `${p === 0 ? 'Destancı' : 'Gölge'} elinden bir kart attı.`);
      }
    } else {
      if (action.type === 'play') play(s, p, action);
      else if (action.type === 'attack') attack(s, p, action);
      else if (action.type === 'end') endTurn(s);
      else throw new RuleError('Bilinmeyen hamle.');
    }
  }
  s.history.push({ p, action: structuredClone(action) });
  return s;
}

export function legalActions(s, p = s.active) {
  if (s.status === 'finished' || s.active !== p) return [];
  if (s.status === 'mulligan') return [{ type: 'mulligan', indices: [] }];
  if (s.pending?.kind === 'scry') return [{ type: 'scry', bottom: false }, { type: 'scry', bottom: true }];
  if (s.pending?.kind === 'discard') return s.players[p].hand.map((_,index) => ({ type: 'discard', index }));
  const actions = [];
  const player = s.players[p];
  if (s.phase === 'main') player.hand.forEach((id,index) => {
    const c = card(id);
    if (c.cost > player.energy || c.type === 'warrior' && player.board.length >= 5 || c.type === 'trap' && player.traps.length >= 2) return;
    const targets = playTargets(s, p, id);
    if (targetsRequired(id) && targets.length) for (const target of targets) actions.push({ type: 'play', index, target });
    else if (!targetsRequired(id) || c.type === 'warrior') actions.push({ type: 'play', index });
  });
  for (const u of player.board) for (const target of attackTargets(s, p, u)) actions.push({ type: 'attack', uid: u.uid, target });
  actions.push({ type: 'end' });
  return actions;
}

export function exportReplay(s) { return { version: RULE_VERSION, initial: s.initial, history: s.history }; }
export function restoreReplay(replay) {
  requireRule(replay?.version === RULE_VERSION && Array.isArray(replay.history) && replay.history.length <= 10000, 'Uyumsuz maç kaydı.');
  let s = createGame(replay.initial);
  for (const entry of replay.history) s = applyAction(s, entry.p, entry.action);
  return s;
}
