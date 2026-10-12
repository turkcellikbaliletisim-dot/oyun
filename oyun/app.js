import { CARDS, CARD_BY_ID } from './cards.js';
import { DECKS } from './decks.js';
import { createGame, applyAction, legalActions, attackValue, canAttack, exportReplay, restoreReplay, validateDeck } from './engine.js';
import { chooseBotAction } from './bot.js';
import { CHAPTERS, chapterCompleted,chapterOptions } from './chapters.js';
import { newProfile,validateProfile,loginReward,chapterReward,matchReward,openPack,craftCard,dismantleCard,archiveCard,capacity,CRAFT,DUST,deckOwned,missingDust } from './economy.js';
import { applyCardArt } from '../kart-prototipi/art.js';
import { feedbackRecord,saveFeedback,feedbackCSV } from './playtest.js';

const $ = id => document.getElementById(id);
const STORE = 'destan-v02-match';
const TYPE = { warrior: 'SAVAŞÇI', spell: 'BÜYÜ', trap: 'TUZAK' };
const RARITY = { common: 'YAYGIN', rare: 'NADİR', legendary: 'EFSANEVİ' };
let state = null, selected = null, mulligan = new Set(), botTimer, deadline = null;
let visible = false, timed = false, sound = false, audio, saved = null, storageFailed = false;
let custom = [...DECKS.starter.cards];
let chapter = null, completed = [];
let profile=newProfile(),matchId=null,rewardEligible=false;
let elapsedMs=0,resumeAt=0,feedback=[],feedbackEligible=true;
try{const records=JSON.parse(localStorage.getItem('destan-v02-feedback'));if(Array.isArray(records))feedback=records;}catch{}
const localDay=()=>new Intl.DateTimeFormat('sv-SE',{timeZone:'Europe/Istanbul',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
try { const data=JSON.parse(localStorage.getItem('destan-v02-story')); if(Array.isArray(data))completed=[...new Set(data.filter(id=>Number.isInteger(id)&&id>=1&&id<=10))]; } catch {}
const elem = (tag, text, className) => {
  const node = document.createElement(tag);
  if (text !== undefined) node.textContent = text;
  if (className) node.className = className;
  return node;
};
function notice(text) { $('notice').textContent = text; }
function activeElapsed(){return elapsedMs+(visible&&state?.status!=='finished'?Math.max(0,Date.now()-resumeAt):0);}
function showCardDetail(id,unit=null,p=0){
  const c=CARD_BY_ID[id];$('detail-name').textContent=c.name;
  $('detail-stats').textContent=`${c.cost} enerji · ${TYPE[c.type]} · ${RARITY[c.rarity]}${c.type==='warrior'?` · SAL ${unit?attackValue(state,p,unit):c.attack} / CAN ${unit?unit.hp+'/'+unit.maxHp:c.hp}`:''}`;
  $('detail-text').textContent=c.text;applyCardArt($('detail-art'),id);$('card-detail').showModal();
}
function remaining() {
  if (!visible && saved?.matchId === matchId) return saved.remaining ?? 45000;
  return deadline == null ? 45000 : Math.max(0, deadline - Date.now());
}
function persist() {
  if (!state) return;
  saved = { replay: exportReplay(state), timed, remaining: remaining(), chapterId: chapter?.id ?? null,matchId,rewardEligible,elapsedMs:activeElapsed(),feedbackEligible };
  try { localStorage.setItem(STORE, JSON.stringify(saved)); }
  catch { storageFailed = true; notice('Tarayıcı kaydı kullanılamıyor. Maçı indirerek kaydını koruyabilirsin.'); }
  $('resume').hidden = false;
}
try { saved = JSON.parse(localStorage.getItem(STORE)); if (saved) restoreReplay(saved.replay); }
catch { saved = null; notice('Önceki kayıt açılamadı. Yeni maç başlatabilir veya geçerli bir kayıt yükleyebilirsin.'); }
$('resume').hidden = !saved;
try{const raw=localStorage.getItem('destan-v02-collection');if(raw){const loaded=JSON.parse(raw);validateProfile(loaded);profile=loaded;}}
catch{notice('Koleksiyon kaydı okunamadı. Geçersiz kayıt ayrı anahtarda korunarak yeni yerel koleksiyon başlatılacak.');try{localStorage.setItem('destan-v02-collection-backup',localStorage.getItem('destan-v02-collection'));}catch{}}
profile=loginReward(profile,localDay());
for(const id of completed)profile=chapterReward(profile,id);
function saveProfile(){try{localStorage.setItem('destan-v02-collection',JSON.stringify(profile));}catch{notice('Koleksiyon bu tarayıcıda kalıcı kaydedilemiyor.');}}
saveProfile();
function settleRewards(){
  if(!rewardEligible || !state || state.status!=='finished')return;
  profile=loginReward(profile,localDay());
  if(chapter&&chapterCompleted(chapter,state))profile=chapterReward(profile,chapter.id);
  profile=matchReward(profile,{id:matchId,state,day:localDay(),chapterId:chapter?.id});saveProfile();
}
function renderCollection(){
  profile=loginReward(profile,localDay());saveProfile();
  $('wallet').textContent=`${profile.gold} altın · ${profile.dust} toz · ${profile.freePacks} ücretsiz paket · ${Object.values(profile.inventory).filter(Boolean).length}/40 farklı kart`;
  const today=profile.days[localDay()];
  $('quests').textContent=`Günlük görevler: savaşçı ${Math.min(8,today.warriors)}/8 · büyü ${Math.min(3,today.spells)}/3 · maç ${Math.min(2,today.matches)}/2. Her görev 50 altın. Efsanevi garanti: en çok ${10-profile.pity} paket içinde.`;
  $('open-pack').disabled=!(profile.freePacks>0||profile.gold>=300);
  $('open-pack').textContent=profile.freePacks>0?'Ücretsiz paket aç':'300 altına paket aç';
  $('archive-info').textContent=profile.archiveLeft?`Final arşivi: ${profile.archiveLeft} farklı eksik kart seçebilirsin.`:'';
  $('collection-cards').replaceChildren();
  for(const c of CARDS){
    const row=elem('div',undefined,'collection-row'),name=elem('span');
    const inspect=elem('button',`${c.name} · ${profile.inventory[c.id]??0}/${capacity(c.id)}`);inspect.dataset.inspectId=c.id;
    inspect.addEventListener('click',()=>showCardDetail(c.id));name.append(inspect);
    name.append(elem('small',`${TYPE[c.type]} · ${RARITY[c.rarity]} · ${c.cost} enerji`));row.append(name);
    const craft=elem('button',`Üret · ${CRAFT[c.rarity]} toz`);craft.dataset.craftId=c.id;craft.disabled=profile.dust<CRAFT[c.rarity]||(profile.inventory[c.id]??0)>=capacity(c.id);
    craft.addEventListener('click',()=>{try{profile=craftCard(profile,c.id);saveProfile();renderCollection();}catch(e){notice(e.message);}});
    const scrap=elem('button',`Parçala · +${DUST[c.rarity]} toz`);scrap.dataset.scrapId=c.id;scrap.disabled=!(profile.inventory[c.id]>0);
    scrap.addEventListener('click',()=>{if(confirm(`${c.name} kartının 1 kopyasını parçalamak istiyor musun? Bu işlem geri alınmaz; koleksiyon desteğin eksilebilir.`)){profile=dismantleCard(profile,c.id);saveProfile();renderCollection();}});
    row.append(craft,scrap);
    if(profile.archiveLeft&&!(profile.inventory[c.id]>0)){const choice=elem('button','Arşivden seç');choice.addEventListener('click',()=>{profile=archiveCard(profile,c.id);saveProfile();renderCollection();});row.append(choice);}
    $('collection-cards').append(row);
  }
}
$('collection-open').addEventListener('click',()=>{renderCollection();$('collection').showModal();});$('collection-close').addEventListener('click',()=>$('collection').close());
$('detail-close').addEventListener('click',()=>$('card-detail').close());
$('open-pack').addEventListener('click',()=>{
  try{const result=openPack(profile);profile=result.profile;saveProfile();renderCollection();$('pack-result').textContent=result.rewards.map(r=>r.id?(r.dust?`${CARD_BY_ID[r.id].name} (fazla kopya: ${r.dust} toz)`:CARD_BY_ID[r.id].name):`${r.dust} toz`).join(' · ');}catch(e){notice(e.message);}
});
function refreshChapters() {
  const chosen=$('chapter').value;
  $('chapter').replaceChildren();
  for(const item of CHAPTERS){
    const option=elem('option',`${completed.includes(item.id)?'✓ ':''}${item.id}. ${item.title}`);option.value=item.id;
    option.disabled=item.id>1&&!completed.includes(item.id-1);$('chapter').append(option);
  }
  if(chosen && !$('chapter').querySelector(`option[value="${chosen}"]`).disabled)$('chapter').value=chosen;
  chapterDescription();
}
function chapterDescription(){const item=CHAPTERS.find(c=>c.id===Number($('chapter').value));$('chapter-description').textContent=`${item.place} · ${item.task} Hikâyede hazır desteler kullanılır.`;}
$('chapter').addEventListener('change',chapterDescription);
$('mode').addEventListener('change',()=>{$('chapter-picker').hidden=$('mode').value!=='story';$('deck').disabled=$('mode').value==='story';$('opponent').disabled=$('mode').value==='story';});
refreshChapters();

for (const key of Object.keys(DECKS)) for (const id of ['deck', 'opponent']) {
  const option = elem('option', DECKS[key].name); option.value = key; $(id).append(option);
}
const customOption = elem('option', 'Kendi destem'); customOption.value = 'custom'; $('deck').append(customOption);
$('opponent').value = 'tempo';
function deckDescription() { $('deck-description').textContent = DECKS[$('deck').value]?.description ?? 'Seçtiğin 20 kartla oyna.'; }
$('deck').addEventListener('change', deckDescription); deckDescription();
for (const c of CARDS) {
  const row = elem('label', undefined, 'builder-row');
  const name = elem('span', `${c.name} · ${c.cost} enerji`); name.append(elem('small', `${TYPE[c.type]} · ${RARITY[c.rarity]}`));
  const input = elem('input'); input.type = 'number'; input.min = '0'; input.max = c.rarity === 'legendary' ? '1' : '2'; input.step = '1';
  input.value = custom.filter(id => id === c.id).length; input.dataset.cardId = c.id; input.setAttribute('aria-label', `${c.name} kopya sayısı`);
  input.addEventListener('input', () => { $('deck-total').textContent = `${builderCards().length}/20 kart`; });
  row.append(name, input); $('deck-builder').append(row);
}
function builderCards() {
  return [...$('deck-builder').querySelectorAll('input')].flatMap(input => {
    const n = Number(input.value);
    return Number.isInteger(n) && n >= 0 && n <= Number(input.max) ? Array(n).fill(Number(input.dataset.cardId)) : [];
  });
}
$('deck-total').textContent = '20/20 kart';
$('use-custom').addEventListener('click', () => {
  try {
    for (const input of $('deck-builder').querySelectorAll('input')) if (!input.checkValidity()) throw new Error('Kart adetlerini sınırlar içinde seç.');
    const deck = builderCards(); validateDeck(deck); custom = deck; $('deck').value = 'custom'; deckDescription(); notice('20 kartlık desten hazır.');
  } catch (e) { notice(e.message); }
});

function openMatch(s, options = {}) {
  clearTimeout(botTimer); state = s; selected = null; mulligan.clear(); visible = true;
  timed = options.timed ?? $('timed').checked;
  chapter = CHAPTERS.find(c=>c.id===options.chapterId) ?? null;
  matchId=options.matchId??crypto.randomUUID();rewardEligible=options.rewardEligible??true;
  elapsedMs=options.elapsedMs??0;resumeAt=Date.now();
  feedbackEligible=options.feedbackEligible??(options.replay===undefined||Number.isFinite(options.elapsedMs));
  deadline = timed && state.status === 'playing' ? Date.now() + Math.min(45000, Math.max(0, options.remaining ?? 45000)) : null;
  $('setup').hidden = true; $('match').hidden = false; notice(''); render(); persist(); scheduleBot();
}
$('new-game').addEventListener('submit', event => {
  event.preventDefault();
  try {
    const decks = [$('deck').value === 'custom' ? custom : DECKS[$('deck').value].cards, DECKS[$('opponent').value].cards];
    const stage=$('mode').value==='story'?CHAPTERS.find(c=>c.id===Number($('chapter').value)):null;
    if(stage && stage.id>1 && !completed.includes(stage.id-1))throw new Error('Önce önceki bölümü tamamla.');
    if(!stage && $('owned-only').checked && !deckOwned(profile,decks[0]))throw new Error(`Bu destede eksik kartların var. Üretim için ${missingDust(profile,decks[0])} toz gerekir; koleksiyonunu aç veya serbest denemeyi seç.`);
    const seed=Number($('seed').value);
    openMatch(createGame(stage?chapterOptions(stage,seed):{decks,seed}),{chapterId:stage?.id});
  } catch (e) { notice(e.message); }
});
$('resume').addEventListener('click', () => { try { openMatch(restoreReplay(saved.replay), saved); } catch (e) { notice(e.message); } });
$('back').addEventListener('click', () => {
  persist(); elapsedMs=activeElapsed();visible = false; clearTimeout(botTimer); $('match').hidden = true; $('setup').hidden = false; notice('Maçın kaydedildi. Devam etmek için kayıtlı maçı aç.');
  if (storageFailed) notice('Bu tarayıcıda kalıcı kayıt yok. Sayfayı kapatmadan maçı indir.');
});
window.addEventListener('beforeunload', persist);

function beep() {
  if (!sound) return;
  try {
    audio ??= new (window.AudioContext || window.webkitAudioContext)(); audio.resume();
    const oscillator = audio.createOscillator(), gain = audio.createGain();
    oscillator.frequency.value = state.status === 'finished' ? 660 : 330;
    gain.gain.setValueAtTime(.035, audio.currentTime); gain.gain.exponentialRampToValueAtTime(.001, audio.currentTime + .12);
    oscillator.connect(gain); gain.connect(audio.destination); oscillator.start(); oscillator.stop(audio.currentTime + .13);
  } catch { sound = false; $('sound-toggle').textContent = 'Ses kullanılamıyor'; }
}
$('sound-toggle').addEventListener('click', () => { sound = !sound; $('sound-toggle').textContent = sound ? 'Ses açık' : 'Ses kapalı'; $('sound-toggle').setAttribute('aria-pressed', String(sound)); if (sound) beep(); });
function commit(action, p = 0) {
  try {
    const previousTurn = state.turn;
    const spent=activeElapsed();
    state = applyAction(state, p, action); selected = null; mulligan.clear();
    if(chapter && chapterCompleted(chapter,state) && !completed.includes(chapter.id)){
      completed.push(chapter.id);
      try{localStorage.setItem('destan-v02-story',JSON.stringify(completed));}catch{notice('Bölüm ilerlemesi kalıcı olarak kaydedilemedi.');}
      refreshChapters();
    }
    if (timed && state.status === 'playing' && previousTurn !== state.turn) deadline = Date.now() + 45000;
    if (state.status === 'finished') {deadline = null;elapsedMs=spent;}
    $('announcements').textContent=state.status==='finished'?'Maç tamamlandı. Sonuç ve değerlendirme hazır.':`${state.log.at(-1)} ${state.active===0?'Sıra sende.':'Gölge oynuyor.'}`;
    notice(''); render(); persist(); beep(); scheduleBot();
  } catch (e) { notice(e.message); }
}
function scheduleBot() {
  clearTimeout(botTimer);
  if (!visible || !state || state.status === 'finished' || state.active !== 1) return;
  botTimer = setTimeout(() => {
    if (!visible || state.active !== 1 || state.status === 'finished') return;
    const action = chapter?.passive && state.status==='playing' && !state.pending ? {type:'end'} : chooseBotAction(state,1);
    if (action) commit(action,1);
  }, 450);
}
function chooseTarget(target) {
  if (!selected) return;
  const action = selected.options.find(a => a.target === target);
  if (action) commit(action);
}
function cardNode(c, unit = null, p = 0) {
  const node = elem('button', undefined, `card ${c.rarity}${unit ? ' unit' : ''}`);
  node.type = 'button';
  const header = elem('div', undefined, 'card-header'); header.append(elem('span', c.name, 'card-name'), elem('span', c.cost, 'cost'));
  const illustration=elem('div',undefined,'sigil');applyCardArt(illustration,c.id);
  node.append(header, illustration, elem('div', `${TYPE[c.type]} · ${RARITY[c.rarity]}`, 'card-type'), elem('div', c.text, 'card-text'));
  if (c.type === 'warrior') {
    node.append(elem('div', c.keywords.join(' · '), 'keywords'));
    const stats = elem('div', undefined, 'stats');
    stats.append(elem('span', `⚔ ${unit ? attackValue(state,p,unit) : c.attack}`, 'attack'), elem('span', `♥ ${unit ? unit.hp + '/' + unit.maxHp : c.hp}`, 'health')); node.append(stats);
  }
  if (unit) {
    const ready = canAttack(state,p,unit);
    node.classList.toggle('ready', ready);
    const flags = [unit.skipUntil >= state.players[p].turns ? 'Donmuş' : ready ? 'Hazır' : 'Bekliyor', unit.shield ? 'Korunuyor' : ''];
    node.append(elem('div', flags.filter(Boolean).join(' · '), 'state'));
    node.dataset.uid = unit.uid;
  }
  node.setAttribute('aria-label', `${c.name}, ${c.cost} enerji. ${c.text}${unit ? ` Saldırı ${attackValue(state,p,unit)}, can ${unit.hp}/${unit.maxHp}.` : ''}`);
  return node;
}
function heroZone(id, p) {
  const zone = $(id); zone.replaceChildren(); const player = state.players[p];
  const hero = elem('button', undefined, 'hero'); hero.type = 'button'; hero.dataset.target = `hero:${p}`;
  const name = elem('span'); name.append(elem('strong', p === 0 ? 'Destancı' : 'Gölge'), elem('small', p === 0 ? 'Anadolu Diyarı' : 'Unutuş’un gölgesi'));
  hero.append(name, elem('span', `${player.hp}`, 'hp')); hero.setAttribute('aria-label', `${p === 0 ? 'Sen' : 'Rakip'}: ${player.hp} can`);
  const eligible = selected?.options.some(a => a.target === `hero:${p}`);
  hero.classList.toggle('targetable', !!eligible); hero.disabled = !eligible; hero.addEventListener('click', () => chooseTarget(`hero:${p}`));
  const details = elem('div', undefined, 'hero-details');
  details.append(elem('div', `Enerji ${player.energy}/${player.maxEnergy}`, 'energy'), elem('div', `El ${player.hand.length}/7 · Deste ${player.deck.length} · Mezarlık ${player.grave.length}${player.half ? ' · Hasar yarıya iner' : ''}`));
  const traps = elem('div', undefined, 'traps');
  for (const trap of player.traps) traps.append(elem('span', p === 0 ? CARD_BY_ID[trap.id].name : '◇ Gizli tuzak', 'trap'));
  details.append(traps); zone.append(hero,details);
}
function board(id,p) {
  const root = $(id); root.replaceChildren();
  for (const unit of state.players[p].board) {
    const node = cardNode(CARD_BY_ID[unit.id],unit,p), target = `unit:${unit.uid}`;
    const targetable = selected?.options.some(a => a.target === target);
    const usable = p === 0 && canAttack(state,0,unit);
    node.dataset.target = target;
    node.disabled = !(targetable || usable);
    node.classList.toggle('targetable', !!targetable);
    node.classList.toggle('selected', selected?.type === 'attack' && selected.uid === unit.uid);
    node.addEventListener('click', () => {
      if (targetable) chooseTarget(target);
      else if (usable) {
        selected = { type: 'attack', uid: unit.uid, options: legalActions(state).filter(a => a.type === 'attack' && a.uid === unit.uid) };
        render();
      }
    });
    const slot=elem('div',undefined,'board-slot'),inspect=elem('button','İncele','unit-info');inspect.type='button';inspect.dataset.infoUid=unit.uid;
    inspect.setAttribute('aria-label',`${CARD_BY_ID[unit.id].name} kartını incele`);inspect.addEventListener('click',()=>showCardDetail(unit.id,unit,p));slot.append(node,inspect);root.append(slot);
  }
  for (let i = state.players[p].board.length; i < 5; i++) root.append(elem('div', '·', 'empty-slot'));
}
function hand() {
  const root = $('hand'); root.replaceChildren();
  const actions = legalActions(state,0);
  state.players[0].hand.forEach((id,index) => {
    const node = cardNode(CARD_BY_ID[id]); node.dataset.index = index;
    const options = actions.filter(a => a.type === 'play' && a.index === index);
    const isMulligan = state.status === 'mulligan' && state.active === 0;
    const isPinned=isMulligan&&state.players[0].mulliganPinned.includes(id);
    const isDiscard = state.pending?.kind === 'discard' && state.active === 0;
    node.disabled = !(isMulligan&&!isPinned || isDiscard || options.length);
    if(isPinned){node.append(elem('small','Görev kartı · korunur','quest-card-note'));node.setAttribute('aria-label',node.getAttribute('aria-label')+' Görev kartı; başlangıçta korunur.');}
    node.classList.toggle('selected', mulligan.has(index) || selected?.type === 'play' && selected.index === index);
    node.setAttribute('aria-pressed',String(mulligan.has(index)||selected?.type==='play'&&selected.index===index));
    node.addEventListener('click', () => {
      if (isMulligan) { mulligan.has(index) ? mulligan.delete(index) : mulligan.add(index); render(); }
      else if (isDiscard) commit({ type: 'discard', index });
      else if (options.length === 1 && options[0].target == null) commit(options[0]);
      else { selected = { type: 'play', index, options }; render(); }
    });
    const slot=elem('div',undefined,'hand-slot'),inspect=elem('button','İncele','unit-info');inspect.type='button';inspect.dataset.infoIndex=index;inspect.setAttribute('aria-label',`${CARD_BY_ID[id].name} kartını incele`);inspect.addEventListener('click',()=>showCardDetail(id));slot.append(node,inspect);root.append(slot);
  });
}
function decisions() {
  const root = $('decision'); root.replaceChildren(); root.hidden = true;
  if (state.active !== 0 || state.status === 'finished') return;
  if (state.status === 'mulligan') {
    root.hidden = false; root.append(elem('strong', 'Başlangıç elini seç'), elem('p', 'Değiştirmek istediğin kartlara dokun. Seçtiğin kartlar yenileri çekildikten sonra desteye döner.'+(chapter?' Bu bölümün görev kartı başlangıç elinde korunur.':'')));
    const accept = elem('button', mulligan.size ? `${mulligan.size} kartı değiştir` : 'Bu elle başla', 'primary'); accept.id = 'confirm-mulligan';
    accept.addEventListener('click', () => commit({ type: 'mulligan', indices: [...mulligan] })); root.append(accept);
  } else if (state.pending?.kind === 'discard') {
    root.hidden = false; root.append(elem('strong', 'Pazar Pazarlığı: elinden 1 kart at'), elem('p', 'Atmak istediğin karta dokun. Kart seçmeden diğer hamlelere geçemezsin.'));
  } else if (state.pending?.kind === 'scry') {
    root.hidden = false;
    root.append(elem('strong', 'Dede Korkut: üst kartına bak'), elem('p', CARD_BY_ID[state.players[0].deck[0]].name));
    for (const [bottom,text] of [[false,'Üstte tut'],[true,'Destenin altına koy']]) {
      const button = elem('button',text); button.addEventListener('click', () => commit({type:'scry',bottom})); root.append(button);
    }
  } else if (selected?.type === 'play' && CARD_BY_ID[state.players[0].hand[selected.index]].id === 26 && selected.options.some(a => a.target?.startsWith('grave:'))) {
    root.hidden = false; root.append(elem('strong','Geri getirilecek savaşçıyı seç'));
    for (const action of selected.options) {
      const entry = state.players[0].grave.find(g => `grave:${g.uid}` === action.target);
      const button = elem('button',CARD_BY_ID[entry.id].name); button.addEventListener('click', () => commit(action)); root.append(button);
    }
  }
}
function render() {
  const focus=document.activeElement,dataset={...focus?.dataset};
  settleRewards();
  heroZone('foe-hero',1); heroZone('my-hero',0); board('foe-board',1); board('my-board',0); hand(); decisions();
  $('turn-label').textContent = state.status === 'mulligan' ? 'Başlangıç eli' : `${state.active === 0 ? 'Senin turun' : 'Gölge’nin turu'} · ${Math.ceil(state.turn/2)}/20`;
  $('phase-label').textContent = state.phase === 'main' ? 'Kart oynama fazı' : 'Saldırı fazı';
  $('hand-count').textContent = `${state.players[0].hand.length}/7 kart`;
  $('end-turn').disabled = state.status !== 'playing' || state.active !== 0 || !!state.pending;
  $('surrender').disabled = state.status === 'finished';
  $('selection').hidden = !selected;
  $('selection-text').textContent = selected?.type === 'attack' ? 'Saldırmak için parlayan rakip hedefini seç.' : 'Kartın etkisi için parlayan hedefi seç.';
  $('result').hidden = state.status !== 'finished';
  $('chapter-task').hidden=!chapter;
  if(chapter)$('chapter-task').replaceChildren(elem('strong',`${chapter.id}. ${chapter.title} · ${chapter.enemy}`),elem('p',`Dede Korkut: “${chapter.dialogue}”`),elem('p',`Görev: ${chapter.task}`));
  if (state.status === 'finished') {
    $('result').replaceChildren(elem('h2', state.winner == null ? 'Destan berabere bitti.' : state.winner === 0 ? 'Diyar seninle yeniden hatırladı. Kazandın!' : 'Gölge bu kez galip geldi.'), elem('p', `Sonuç: ${state.reason}. Sen ${state.players[0].hp} can · Gölge ${state.players[1].hp} can.`));
    $('turn-label').textContent = 'Maç tamamlandı';
    if(rewardEligible&&feedbackEligible){const response=elem('button','Bu maçı değerlendir');response.id='feedback-open';response.addEventListener('click',()=>$('feedback').showModal());$('result').append(response);}
    if(chapter){
      const success=chapterCompleted(chapter,state);
      $('result').append(elem('p',success?(chapter.id===10?'Anadolu’nun Mühür Parçası hatırlandı. 10 bölümü tamamladın!':'Görev tamamlandı. Sonraki bölüm açıldı.'):'Bölüm görevi tamamlanmadı. Görevi de yerine getirerek yeniden dene.'));
      const again=elem('button',success&&chapter.id<10?'Sonraki bölüm':'Bölümü yeniden oyna','primary');
      again.addEventListener('click',()=>{const next=success&&chapter.id<10?CHAPTERS[chapter.id]:chapter;openMatch(createGame(chapterOptions(next,Number($('seed').value))),{chapterId:next.id,timed});});
      $('result').append(again);
    }
  }
  $('log').replaceChildren(...state.log.slice().reverse().map(message => elem('li',message)));
  updateTimer();
  if(selected){document.querySelector('.targetable')?.focus({preventScroll:true});}
  else {
    const selectors=[dataset.uid?`[data-uid="${dataset.uid}"]`:null,dataset.index!==undefined?`#hand [data-index="${dataset.index}"]`:null,dataset.infoUid?`[data-info-uid="${dataset.infoUid}"]`:null,dataset.infoIndex!==undefined?`[data-info-index="${dataset.infoIndex}"]`:null];
    for(const selector of selectors.filter(Boolean)){const target=document.querySelector(selector);if(target&&!target.disabled){target.focus({preventScroll:true});break;}}
  }
}
$('cancel-selection').addEventListener('click', () => { selected = null; render(); });
$('end-turn').addEventListener('click', () => commit({ type: 'end' }));
$('surrender').addEventListener('click', () => { if (confirm('Bu maçı bitirip teslim olmak istiyor musun?')) commit({ type: 'surrender' }); });
$('help-open').addEventListener('click', () => $('help').showModal()); $('help-close').addEventListener('click', () => $('help').close());
$('feedback-close').addEventListener('click',()=>$('feedback').close());
$('feedback-form').addEventListener('submit',event=>{
  event.preventDefault();
  try{
    const record=feedbackRecord(state,{matchId,mode:chapter?'story':'practice',chapter:chapter?.id??0,elapsedMs:activeElapsed(),experience:$('feedback-experience').value,fun:Number($('feedback-fun').value),again:$('feedback-again').value==='yes',confusion:$('feedback-confusion').value});
    const records=saveFeedback(feedback,record);localStorage.setItem('destan-v02-feedback',JSON.stringify(records));feedback=records;$('feedback').close();notice('Maç değerlendirmen bu tarayıcıya kaydedildi.');
  }catch(e){notice(e.message);}
});
$('feedback-export').addEventListener('click',()=>{const blob=new Blob(['\uFEFF'+feedbackCSV(feedback)],{type:'text/csv;charset=utf-8'});const url=URL.createObjectURL(blob),a=elem('a');a.href=url;a.download='destan-mac-degerlendirmeleri.csv';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);});
$('export').addEventListener('click', () => {
  const blob = new Blob([JSON.stringify(exportReplay(state),null,2)], { type: 'application/json' });
  const url = URL.createObjectURL(blob), a = elem('a'); a.href = url; a.download = `destan-${state.seed}.json`; a.click(); setTimeout(() => URL.revokeObjectURL(url),1000);
});
$('import-replay').addEventListener('change', async event => {
  const file = event.target.files[0]; if (!file) return;
  try {
    if (file.size > 1000000) throw new Error('Maç kaydı 1 MB’dan küçük olmalı.');
    const replay = JSON.parse(await file.text()); openMatch(restoreReplay(replay), { timed: false,rewardEligible:false });
  } catch (e) { notice(`Kayıt yüklenemedi: ${e.message}`); }
  event.target.value = '';
});
function updateTimer() { $('timer').textContent = timed && state?.status === 'playing' ? `${Math.ceil(remaining()/1000)} sn` : 'Süresiz çalışma'; }
setInterval(() => {
  if (!visible || !state || state.status !== 'playing' || !timed) return;
  updateTimer();
  if (remaining() > 0) return;
  // Bekleyen zorunlu seçimleri çöz, sonra süre dolan turu bitir.
  const p = state.active;
  const spent=activeElapsed();
  while (state.pending && state.status === 'playing') {
    const action = state.pending.kind === 'scry' ? { type:'scry', bottom:false } : { type:'discard', index:0 };
    state = applyAction(state,p,action);
  }
  if (state.status === 'playing') commit({type:'end'},p);
  else { elapsedMs=spent;render(); persist(); }
},250);
