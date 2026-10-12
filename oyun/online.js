import {CARDS,CARD_BY_ID} from './cards.js';
import {DECKS} from './decks.js';
import {CHAPTERS,chapterCompleted} from './chapters.js';
import {legalActions,attackValue,canAttack,validateDeck} from './engine.js';
import {deckOwned,CRAFT,DUST,capacity} from './economy.js';
import {applyCardArt} from '../kart-prototipi/art.js';
const $=id=>document.getElementById(id),ROOT=new URL('../',import.meta.url),PENDING='destan-online-pending';
const TYPE={warrior:'SAVAŞÇI',spell:'BÜYÜ',trap:'TUZAK'},RARITY={common:'YAYGIN',rare:'NADİR',legendary:'EFSANEVİ'};
let account=null,room=null,selected=null,mulligan=new Set(),busy=false,online=true,clockOffset=0,key=null,custom=[...DECKS.starter.cards],polling=false;
const el=(tag,text,cls)=>{const node=document.createElement(tag);if(text!==undefined)node.textContent=text;if(cls)node.className=cls;return node;};
const say=text=>{$('online-notice').textContent=text;};
function download(text,name,type){const url=URL.createObjectURL(new Blob([text],{type})),a=el('a');a.href=url;a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);}
async function api(path,method='GET',body){
  const target=new URL(path,ROOT);if(target.origin!==ROOT.origin||!target.pathname.startsWith(ROOT.pathname+'api/'))throw new Error('İstek adresi geçersiz.');
  const response=await fetch(target,{method,credentials:'same-origin',cache:'no-store',headers:{'Content-Type':'application/json',...(account?{'X-Destan-Csrf':account.csrf}:{})},...(body===undefined?{}:{body:JSON.stringify(body)})});
  let data;try{data=await response.json();}catch{throw new Error('Hesaplı oyuna bağlanılamadı. Yerel oyundan devam edebilirsin.');}
  if(!response.ok){const error=new Error(data.error??'İşlem tamamlanamadı.');error.status=response.status;throw error;}return data;
}
function acceptAccount(data){
  const previous=account?JSON.stringify(account):null;
  if(account&&account.id!==data.id){room=null;selected=null;mulligan.clear();}
  account={...data};delete account.recoveryKey;$('online-collection-open').disabled=false;
  if(data.recoveryKey){key=data.recoveryKey;$('recovery-key').value=key;$('new-key').hidden=false;}
  if(previous!==JSON.stringify(account))renderLobby();
}
function acceptRoom(data){
  room=data;clockOffset=data.serverNow-Date.now();selected=null;mulligan.clear();online=true;
  $('online-lobby').hidden=true;$('online-match').hidden=false;renderRoom();
}
function activeDeck(){return $('online-deck').value==='custom'?custom:DECKS[$('online-deck').value].cards;}
async function safe(operation){
  if(busy)return;busy=true;renderRoom();
  try{await operation();say('');online=true;}catch(error){say(error.message);if(!error.status)online=false;}finally{busy=false;renderRoom();renderLobby();if($('online-collection').open)collection();}
}
async function mutation(path,body){
  const requestId=crypto.randomUUID(),payload={...body,requestId};
  const record={accountId:account.id,path,body:payload};localStorage.setItem(PENDING,JSON.stringify(record));
  try{const data=await api(path,'POST',payload);localStorage.removeItem(PENDING);return data;}
  catch(error){if(error.status)localStorage.removeItem(PENDING);throw error;}
}
async function retryPending(){
  const raw=localStorage.getItem(PENDING);if(!raw)return false;
  let record;try{record=JSON.parse(raw);}catch{localStorage.removeItem(PENDING);return false;}
  if(record.accountId!==account.id){localStorage.removeItem(PENDING);return false;}
  try{const data=await api(record.path,'POST',record.body);localStorage.removeItem(PENDING);if(data.account){acceptAccount(data.account);if(data.rewards)showPack(data.rewards);}else acceptRoom(data);return true;}
  catch(error){if(error.status){localStorage.removeItem(PENDING);say(error.message);return false;}throw error;}
}
async function refresh(){
  if(!account||busy||polling||document.hidden)return;polling=true;
  try{
    await retryPending();acceptAccount(await api('api/me'));
    if(account.matchId){const view=await api(`api/matches/${account.matchId}`);if(!room||view.version!==room.version||view.status!==room.status||!online)acceptRoom(view);else clockOffset=view.serverNow-Date.now();}
    online=true;
  }catch(error){online=false;say(error.status===401?'Oturum bulunamadı. Hesabını kurtarma anahtarınla açabilirsin.':'Bağlantı kesildi. Yeniden bağlanılıyor…');renderRoom();}
  finally{polling=false;}
}
function renderLobby(){
  if(!account)return;
  $('online-lobby').hidden=!!room;$('online-match').hidden=!room;
  $('account-summary').textContent=`${account.league} · ${account.mmr} puan · ${account.profile.gold} altın · ${account.profile.dust} toz · ${Object.values(account.profile.inventory).filter(Boolean).length}/40 farklı kart`;
  const previous=$('online-deck').value;$('online-deck').replaceChildren();
  for(const [id,deck]of Object.entries(DECKS)){const option=el('option',deck.name);option.value=id;option.disabled=!deckOwned(account.profile,deck.cards);$('online-deck').append(option);}
  const own=el('option','Kendi destem');own.value='custom';$('online-deck').append(own);if(previous)$('online-deck').value=previous;
  const stage=$('online-chapter').value;$('online-chapter').replaceChildren();
  for(const chapter of CHAPTERS){const option=el('option',`${account.profile.chapterRewards.includes(chapter.id)?'✓ ':''}${chapter.id}. ${chapter.title}`);option.value=chapter.id;option.disabled=chapter.id>1&&!account.profile.chapterRewards.includes(chapter.id-1);$('online-chapter').append(option);}
  if(stage&&!$('online-chapter').querySelector(`option[value="${stage}"]`).disabled)$('online-chapter').value=stage;
  chapterTask();$('join-queue').disabled=!account.profile.chapterRewards.includes(10)||account.queued;
  $('cancel-queue').hidden=!account.queued;$('queue-status').textContent=account.queued?'Lig rakibi aranıyor. İstersen eşleştirmeyi iptal edebilirsin.':account.profile.chapterRewards.includes(10)?'Lig açık.':'Lig, hikâye finalinden sonra açılır.';
  $('create-room').disabled=account.queued;$('join-room').disabled=account.queued;$('start-server-story').disabled=account.queued;$('start-server-bot').disabled=account.queued;
  $('online-history').replaceChildren();
  for(const entry of account.history){const button=el('button',`${entry.kind==='story'?`Bölüm ${entry.chapterId}`:entry.kind==='ranked'?'Lig':entry.kind==='friendly'?'Arkadaş':'Bot'} · ${entry.result==='win'?'Galibiyet':entry.result==='loss'?'Mağlubiyet':'Berabere'} · ${Math.ceil(entry.turns/2)} tur`);button.addEventListener('click',()=>safe(async()=>acceptRoom(await api(`api/matches/${entry.id}`))));$('online-history').append(button);}
}
function chapterTask(){const chapter=CHAPTERS.find(c=>c.id===Number($('online-chapter').value));$('online-chapter-task').textContent=chapter?.task??'';}
function buildDeckEditor(){
  $('online-builder').replaceChildren();
  for(const c of CARDS){const row=el('label',undefined,'builder-row'),name=el('span',`${c.name} · sahiplik ${account.profile.inventory[c.id]??0}`),input=el('input');input.type='number';input.min=0;input.max=account.profile.inventory[c.id]??0;input.value=Math.min(Number(input.max),custom.filter(id=>id===c.id).length);input.dataset.cardId=c.id;input.setAttribute('aria-label',`${c.name} deste kopyası`);input.addEventListener('input',()=>{$('online-deck-total').textContent=`${builderDeck().length}/20 kart`;});row.append(name,input);$('online-builder').append(row);}
  $('online-deck-total').textContent=`${builderDeck().length}/20 kart`;
}
function builderDeck(){return [...$('online-builder').querySelectorAll('input')].flatMap(input=>{const n=Number(input.value);return Number.isInteger(n)&&n>=0&&n<=Number(input.max)?Array(n).fill(Number(input.dataset.cardId)):[];});}
$('online-use-custom').addEventListener('click',()=>{try{for(const input of $('online-builder').querySelectorAll('input'))if(!input.checkValidity())throw new Error('Kart miktarını sahipliğin içinde seç.');const deck=builderDeck();validateDeck(deck);custom=deck;$('online-deck').value='custom';say('Desten hazır.');}catch(error){say(error.message);}});
$('online-chapter').addEventListener('change',chapterTask);
$('create-room').addEventListener('click',()=>safe(async()=>acceptRoom(await api('api/rooms','POST',{deck:activeDeck()}))));
$('join-room').addEventListener('click',()=>safe(async()=>acceptRoom(await api('api/join','POST',{code:$('join-code').value.trim().toUpperCase(),deck:activeDeck()}))));
$('join-queue').addEventListener('click',()=>safe(async()=>{acceptAccount(await api('api/queue','POST',{deck:activeDeck()}));if(account.matchId)acceptRoom(await api(`api/matches/${account.matchId}`));}));
$('cancel-queue').addEventListener('click',()=>safe(async()=>acceptAccount(await api('api/queue/cancel','POST',{}))));
$('start-server-bot').addEventListener('click',()=>safe(async()=>acceptRoom(await api('api/solo','POST',{chapterId:0,deck:activeDeck()}))));
$('start-server-story').addEventListener('click',()=>safe(async()=>acceptRoom(await api('api/solo','POST',{chapterId:Number($('online-chapter').value)}))));
$('leave-match').addEventListener('click',()=>{if(room?.state?.status!=='finished'&&!confirm('Maçtan ayrılmak istiyor musun? Başlamış maçta ayrılmak teslim sayılır.'))return;safe(async()=>{acceptAccount(await api(`api/matches/${room.id}/leave`,'POST',{}));room=null;selected=null;renderLobby();});});
function details(id,unit=null,p=0){const c=CARD_BY_ID[id];$('online-detail-name').textContent=c.name;$('online-detail-stats').textContent=`${c.cost} enerji · ${TYPE[c.type]} · ${RARITY[c.rarity]}${c.type==='warrior'?` · SAL ${unit?attackValue(room.state,p,unit):c.attack} / CAN ${unit?unit.hp+'/'+unit.maxHp:c.hp}`:''}`;$('online-detail-text').textContent=c.text;applyCardArt($('online-detail-art'),id);$('online-detail').showModal();}
$('online-detail-close').addEventListener('click',()=>$('online-detail').close());
function card(id,unit=null,p=0){
  const c=CARD_BY_ID[id],button=el('button',undefined,`card ${c.rarity}${unit?' unit':''}`),head=el('div',undefined,'card-header');
  head.append(el('span',c.name,'card-name'),el('span',c.cost,'cost'));const art=el('div',undefined,'sigil');applyCardArt(art,id);
  button.append(head,art,el('div',`${TYPE[c.type]} · ${RARITY[c.rarity]}`,'card-type'),el('div',c.text,'card-text'),el('div',c.keywords.join(' · '),'keywords'));
  if(c.type==='warrior'){const stats=el('div',undefined,'stats');stats.append(el('span',`SAL ${unit?attackValue(room.state,p,unit):c.attack}`,'attack'),el('span',`CAN ${unit?unit.hp+'/'+unit.maxHp:c.hp}`,'health'));button.append(stats);}
  if(unit){button.dataset.uid=unit.uid;button.classList.toggle('ready',canAttack(room.state,p,unit));button.append(el('div',unit.skipUntil>=room.state.players[p].turns?'Donmuş':canAttack(room.state,p,unit)?'Hazır':'Bekliyor','state'));}
  button.setAttribute('aria-label',`${c.name}, ${c.cost} enerji. ${c.text}`);return button;
}
function choose(target){const action=selected?.options.find(a=>a.target===target);if(action)move(action);}
function hero(root,p){
  const s=room.state,player=s.players[p],button=el('button',undefined,'hero'),name=el('span');name.append(el('strong',p===0?'Sen':'Rakip'),el('small',p===0?'Anadolu Diyarı':room.kind==='friendly'||room.kind==='ranked'?'Destancı':'Gölge'));
  button.append(name,el('span',player.hp,'hp'));button.dataset.target=`hero:${p}`;const targetable=selected?.options.some(a=>a.target===`hero:${p}`);button.classList.toggle('targetable',!!targetable);button.disabled=!targetable||busy||!online;button.addEventListener('click',()=>choose(`hero:${p}`));
  const info=el('div',undefined,'hero-details');info.append(el('div',`Enerji ${player.energy}/${player.maxEnergy}`,'energy'),el('div',`El ${player.hand.length}/7 · Deste ${player.deck.length} · Mezarlık ${player.grave.length}`));
  const traps=el('div',undefined,'traps');for(const t of player.traps)traps.append(el('span',p===0?CARD_BY_ID[t.id].name:'◇ Gizli tuzak','trap'));info.append(traps);$(root).replaceChildren(button,info);
}
function board(root,p){
  $(root).replaceChildren();for(const unit of room.state.players[p].board){const slot=el('div',undefined,'board-slot'),button=card(unit.id,unit,p),target=`unit:${unit.uid}`,targetable=selected?.options.some(a=>a.target===target),usable=p===0&&canAttack(room.state,0,unit);
    button.dataset.target=target;button.disabled=!(targetable||usable)||busy||!online;button.classList.toggle('targetable',!!targetable);button.addEventListener('click',()=>{if(targetable)choose(target);else{selected={options:legalActions(room.state).filter(a=>a.type==='attack'&&a.uid===unit.uid)};renderRoom();}});
    const inspect=el('button','İncele','unit-info');inspect.addEventListener('click',()=>details(unit.id,unit,p));slot.append(button,inspect);$(root).append(slot);
  }
  for(let i=room.state.players[p].board.length;i<5;i++)$(root).append(el('div','·','empty-slot'));
}
function renderRoom(){
  if(!room)return;
  $('online-lobby').hidden=true;$('online-match').hidden=false;const s=room.state;
  $('waiting-room').hidden=room.status!=='waiting';$('room-code').textContent=room.code??'';$('online-arena').hidden=!s;
  if(!s){$('online-hand').replaceChildren();$('online-log').replaceChildren();$('online-decision').hidden=true;$('online-result').hidden=true;$('online-selection').hidden=true;$('online-story-task').hidden=true;$('online-replay').hidden=true;return;}
  hero('online-foe-hero',1);hero('online-my-hero',0);board('online-foe-board',1);board('online-my-board',0);
  $('online-turn').textContent=s.status==='finished'?'Maç tamamlandı':s.status==='mulligan'?'Başlangıç eli':`${s.active===0?'Senin turun':'Rakibin turu'} · ${Math.ceil(s.turn/2)}/20`;
  $('online-phase').textContent=s.phase==='main'?'Kart oynama fazı':'Saldırı fazı';$('online-end').disabled=busy||!online||s.status!=='playing'||s.active!==0||!!s.pending;
  $('online-hand').replaceChildren();const actions=legalActions(s,0),isMulligan=s.status==='mulligan'&&s.active===0,isDiscard=s.pending?.kind==='discard'&&s.active===0;
  s.players[0].hand.forEach((id,index)=>{
    const slot=el('div',undefined,'hand-slot'),button=card(id),options=actions.filter(a=>a.type==='play'&&a.index===index),pinned=isMulligan&&s.players[0].mulliganPinned.includes(id);button.dataset.index=index;
    button.disabled=busy||!online||!(isMulligan&&!pinned||isDiscard||options.length);button.classList.toggle('selected',mulligan.has(index));button.setAttribute('aria-pressed',String(mulligan.has(index)));
    if(pinned)button.append(el('small','Görev kartı · korunur','quest-card-note'));
    button.addEventListener('click',()=>{if(isMulligan){mulligan.has(index)?mulligan.delete(index):mulligan.add(index);renderRoom();}else if(isDiscard)move({type:'discard',index});else if(options.length===1&&!options[0].target)move(options[0]);else{selected={options};renderRoom();}});
    const inspect=el('button','İncele','unit-info');inspect.addEventListener('click',()=>details(id));slot.append(button,inspect);$('online-hand').append(slot);
  });
  const decision=$('online-decision');decision.replaceChildren();decision.hidden=true;
  if(s.active===0&&isMulligan){decision.hidden=false;decision.append(el('p','Değiştirmek istediğin başlangıç kartlarını seç. Hikâye görev kartları korunur.'));const button=el('button',mulligan.size?`${mulligan.size} kartı değiştir`:'Bu elle başla','primary');button.id='online-confirm-mulligan';button.disabled=busy||!online;button.addEventListener('click',()=>move({type:'mulligan',indices:[...mulligan]}));decision.append(button);}
  else if(s.active===0&&s.pending?.kind==='discard'){decision.hidden=false;decision.append(el('p','Pazar Pazarlığı: elinden atılacak kartı seç.'));}
  else if(s.active===0&&s.pending?.kind==='scry'){decision.hidden=false;decision.append(el('p',`Dede Korkut: ${CARD_BY_ID[s.players[0].deck[0]].name}`));for(const bottom of [false,true]){const button=el('button',bottom?'Alta koy':'Üstte tut');button.disabled=busy||!online;button.addEventListener('click',()=>move({type:'scry',bottom}));decision.append(button);}}
  if(selected?.options.some(a=>a.target?.startsWith('grave:'))){decision.hidden=false;decision.append(el('p','Geri getirilecek savaşçıyı seç.'));for(const a of selected.options){const g=s.players[0].grave.find(g=>`grave:${g.uid}`===a.target),button=el('button',CARD_BY_ID[g.id].name);button.addEventListener('click',()=>move(a));decision.append(button);}}
  const chapter=CHAPTERS[room.chapterId-1];$('online-story-task').hidden=!chapter;if(chapter)$('online-story-task').replaceChildren(el('strong',`${chapter.id}. ${chapter.title}`),el('p',`Dede Korkut: “${chapter.dialogue}”`),el('p',chapter.task));
  $('online-selection').hidden=!selected;$('online-log').replaceChildren(...s.log.slice().reverse().map(line=>el('li',line)));
  $('online-result').hidden=s.status!=='finished';$('online-replay').hidden=s.status!=='finished';
  if(s.status==='finished'){
    $('online-result').replaceChildren(el('h2',s.winner==null?'Maç berabere.':s.winner===0?'Kazandın!':'Bu kez rakibin kazandı.'),el('p',`Sonuç: ${s.reason}`));
    if(chapter)$('online-result').append(el('p',chapterCompleted(chapter,s)?'Bölüm görevi tamamlandı; ödül hesabına eklendi.':'Bölüm görevi tamamlanmadı. Yeniden deneyebilirsin.'));
  }
  if(selected)document.querySelector('.targetable')?.focus({preventScroll:true});timer();
}
async function move(action){await safe(async()=>{const result=await mutation(`api/matches/${room.id}/actions`,{version:room.version,action});acceptRoom(result);if(result.status==='finished')acceptAccount(await api('api/me'));});}
$('online-end').addEventListener('click',()=>move({type:'end'}));$('online-cancel').addEventListener('click',()=>{selected=null;renderRoom();});
function timer(){const remaining=room?.deadline==null?null:Math.max(0,Math.ceil((room.deadline-(Date.now()+clockOffset))/1000));$('online-timer').textContent=remaining==null?'Süresiz hikâye/antrenman':`${remaining} sn`;}
setInterval(timer,250);setInterval(refresh,1000);document.addEventListener('visibilitychange',()=>{if(!document.hidden)refresh();});
$('online-replay').addEventListener('click',()=>safe(async()=>download(JSON.stringify(await api(`api/matches/${room.id}/replay`),null,2),`destan-mac-${room.id}.json`,'application/json')));
function showPack(rewards){$('online-pack-result').textContent=rewards.map(r=>r.id?CARD_BY_ID[r.id].name:`${r.dust} toz`).join(' · ');}
function collection(){
  if(!account)return;const p=account.profile;$('online-wallet').textContent=`${p.gold} altın · ${p.dust} toz · ${p.freePacks} ücretsiz paket · ${Object.values(p.inventory).filter(Boolean).length}/40 farklı kart`;
  $('online-pack').textContent=p.freePacks?'Ücretsiz paket aç':'300 altına paket aç';$('online-pack').disabled=busy||!(p.freePacks>0||p.gold>=300);$('online-archive').textContent=p.archiveLeft?`Final arşivinden ${p.archiveLeft} eksik kart seçebilirsin.`:'';
  $('online-collection-cards').replaceChildren();
  for(const c of CARDS){
    const row=el('div',undefined,'collection-row'),name=el('span'),inspect=el('button',`${c.name} · ${p.inventory[c.id]??0}/${capacity(c.id)}`);inspect.addEventListener('click',()=>details(c.id));name.append(inspect,el('small',`${TYPE[c.type]} · ${RARITY[c.rarity]}`));row.append(name);
    for(const [op,text,disabled]of [['craft',`Üret · ${CRAFT[c.rarity]} toz`,p.dust<CRAFT[c.rarity]||(p.inventory[c.id]??0)>=capacity(c.id)],['dismantle',`Parçala · +${DUST[c.rarity]} toz`,!(p.inventory[c.id]>0)],['archive','Arşivden seç',!p.archiveLeft||p.inventory[c.id]>0]]){
      if(op==='archive'&&disabled)continue;const button=el('button',text);button.disabled=disabled||busy;button.dataset.operation=op;button.dataset.cardId=c.id;
      button.addEventListener('click',()=>{if(op==='dismantle'&&!confirm(`${c.name} kartının 1 kopyasını parçalamak istiyor musun? Geri alınamaz.`))return;safe(async()=>{const result=await mutation(`api/collection/${op}`,{cardId:c.id});acceptAccount(result.account);collection();buildDeckEditor();});});row.append(button);
    }
    $('online-collection-cards').append(row);
  }
}
$('online-collection-open').addEventListener('click',()=>{collection();$('online-collection').showModal();});$('online-collection-close').addEventListener('click',()=>$('online-collection').close());
$('online-pack').addEventListener('click',()=>safe(async()=>{const result=await mutation('api/collection/pack',{});acceptAccount(result.account);collection();showPack(result.rewards);buildDeckEditor();}));
$('download-key').addEventListener('click',()=>{if(key)download(key+'\n','destan-hesap-anahtari.txt','text/plain');});
$('rotate-key').addEventListener('click',()=>{if(!confirm('Önceki kurtarma anahtarını geçersiz kılıp yeni anahtar oluşturmak istiyor musun?'))return;safe(async()=>{const result=await api('api/recovery-key','POST',{});key=result.recoveryKey;$('recovery-key').value=key;$('new-key').hidden=false;});});
$('recover-account').addEventListener('click',()=>safe(async()=>{acceptAccount(await api('api/recover','POST',{key:$('recover-input').value.trim()}));key=null;$('new-key').hidden=true;$('recover-input').value='';buildDeckEditor();if(account.matchId)acceptRoom(await api(`api/matches/${account.matchId}`));}));
$('delete-account').addEventListener('click',()=>{if(!confirm('Bu hesabın kartlarını ve sunucudaki ilerlemesini silmek istiyor musun? Geri alınamaz.'))return;safe(async()=>{await api('api/account','DELETE',{});account=null;room=null;key=null;localStorage.removeItem(PENDING);location.href=new URL('index.html',ROOT);});});
try{acceptAccount(await api('api/session','POST',{}));buildDeckEditor();await retryPending();if(account.matchId)acceptRoom(await api(`api/matches/${account.matchId}`));say('');}
catch{say('Hesaplı oyuna bağlanılamadı. Bağlantını kontrol et veya yerel oyundan devam et.');}
