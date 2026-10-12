import { CARDS, CARD_BY_ID } from './cards.js';
import { DECKS } from './decks.js';

// Yerel prototip ekonomisi. Üretimde saat, RNG, sahiplik ve işlemler sunucuda doğrulanmalı.
export const CRAFT = { common:40, rare:100, legendary:400 };
export const DUST = { common:10, rare:25, legendary:100 };
export const capacity = id => CARD_BY_ID[id].rarity === 'legendary' ? 1 : 2;
const requireValue = (ok,message) => { if(!ok)throw new Error(message); };
export function newProfile() {
  const inventory={};for(const id of DECKS.starter.cards)inventory[id]=(inventory[id]??0)+1;
  return {version:1,inventory,gold:0,dust:0,pity:0,freePacks:0,loginDays:[],days:{},weeks:{},chapterRewards:[],matchRewards:[],archiveLeft:0};
}
export function validateProfile(p) {
  requireValue(p?.version===1,'Koleksiyon sürümü uyumsuz.');
  for(const key of ['gold','dust','pity','freePacks','archiveLeft'])requireValue(Number.isSafeInteger(p[key])&&p[key]>=0,'Koleksiyon sayısı geçersiz.');
  requireValue(p.pity<=9 && p.archiveLeft<=7,'Garanti veya arşiv sayacı geçersiz.');
  for(const [id,count] of Object.entries(p.inventory))requireValue(!!CARD_BY_ID[id]&&Number.isInteger(count)&&count>=0&&count<=capacity(id),'Kart sahipliği geçersiz.');
  requireValue(['loginDays','chapterRewards','matchRewards'].every(k=>Array.isArray(p[k]))&&p.days&&p.weeks,'Koleksiyon kaydı eksik.');
  return true;
}
function validDay(day) {
  requireValue(/^\d{4}-\d{2}-\d{2}$/.test(day)&&new Date(day+'T12:00:00Z').toISOString().slice(0,10)===day,'Geçersiz gün.');
}
function weekKey(day) {
  const date=new Date(day+'T12:00:00Z');date.setUTCDate(date.getUTCDate()-(date.getUTCDay()+6)%7);return date.toISOString().slice(0,10);
}
function dayStats(p,day) { return p.days[day]??=( {warriors:0,spells:0,matches:0,wins:0,claimed:[]} ); }
function grant(p,id) {
  if((p.inventory[id]??0)<capacity(id)){p.inventory[id]=(p.inventory[id]??0)+1;return {id,dust:0};}
  const dust=DUST[CARD_BY_ID[id].rarity];p.dust+=dust;return {id,dust};
}
export function loginReward(profile,day) {
  validDay(day);validateProfile(profile);const p=structuredClone(profile);
  if(!p.loginDays.includes(day)){p.loginDays.push(day);p.gold+=30;if(p.loginDays.length%7===0)p.freePacks++;}
  dayStats(p,day);return p;
}
export function craftCard(profile,id) {
  validateProfile(profile);requireValue(!!CARD_BY_ID[id],'Bilinmeyen kart.');const p=structuredClone(profile);
  requireValue((p.inventory[id]??0)<capacity(id),'Bu kartın kopyaları tamam.');
  requireValue(p.dust>=CRAFT[CARD_BY_ID[id].rarity],'Yeterli toz yok.');
  p.dust-=CRAFT[CARD_BY_ID[id].rarity];grant(p,id);return p;
}
export function dismantleCard(profile,id) {
  validateProfile(profile);requireValue(!!CARD_BY_ID[id],'Bilinmeyen kart.');const p=structuredClone(profile);
  requireValue((p.inventory[id]??0)>0,'Bu karta sahip değilsin.');p.inventory[id]--;p.dust+=DUST[CARD_BY_ID[id].rarity];return p;
}
export function archiveCard(profile,id) {
  validateProfile(profile);requireValue(!!CARD_BY_ID[id],'Bilinmeyen kart.');const p=structuredClone(profile);
  requireValue(p.archiveLeft>0,'Arşiv seçimi kalmadı.');requireValue(!(p.inventory[id]>0),'Arşivden yalnız eksik farklı kart seçilir.');
  grant(p,id);p.archiveLeft--;return p;
}
export function openPack(profile, random=Math.random) {
  validateProfile(profile);const p=structuredClone(profile);
  if(p.freePacks>0)p.freePacks--;else {requireValue(p.gold>=300,'Bir paket 300 altın.');p.gold-=300;}
  const roll=()=>{const n=random();requireValue(Number.isFinite(n)&&n>=0&&n<1,'Geçersiz rastgele değer.');return n;};
  const last=p.pity===9?'legendary':((n)=>n<.65?'common':n<.85?'rare':'legendary')(roll());
  p.pity=last==='legendary'?0:p.pity+1;
  const rewards=[];
  for(const rarity of ['common','common','common','rare',last]){
    const available=CARDS.filter(c=>c.rarity===rarity&&(p.inventory[c.id]??0)<capacity(c.id));
    if(available.length)rewards.push(grant(p,available[Math.floor(roll()*available.length)].id));
    else {p.dust+=DUST[rarity];rewards.push({id:null,rarity,dust:DUST[rarity]});}
  }
  return {profile:p,rewards};
}
const CHAPTER_REWARDS={2:[6],3:[19],4:[32],5:[5,14],6:[36],7:[16],8:[33],9:[18],10:[26]};
export function chapterReward(profile,id) {
  validateProfile(profile);requireValue(Number.isInteger(id)&&id>=1&&id<=10,'Geçersiz bölüm.');const p=structuredClone(profile);
  if(p.chapterRewards.includes(id))return p;
  p.chapterRewards.push(id);
  if(id===1){p.gold+=100;p.freePacks++;}
  else for(const card of CHAPTER_REWARDS[id])grant(p,card);
  if(id===10)p.archiveLeft=Math.min(7,CARDS.filter(c=>!(p.inventory[c.id]>0)).length);
  return p;
}
export function matchReward(profile,{id,state,day,chapterId}) {
  validDay(day);validateProfile(profile);requireValue(typeof id==='string'&&id.length>0,'Maç kimliği gerekli.');const p=structuredClone(profile);
  if(state.status!=='finished'||p.matchRewards.includes(id))return p;
  p.matchRewards.push(id);
  if(chapterId===1)return p;
  const actions=state.history.filter(entry=>entry.p===0&&['play','attack'].includes(entry.action.type));
  if(state.turn<4||actions.length<2)return p;
  const daily=dayStats(p,day),week=p.weeks[weekKey(day)]??={matches:0,claimed:false};
  daily.matches++;week.matches++;
  const stats=state.players[0].stats;
  for(const [card,count] of Object.entries(stats.cardPlays)){
    if(CARD_BY_ID[card].type==='warrior')daily.warriors+=count;
    if(CARD_BY_ID[card].type==='spell')daily.spells+=count;
  }
  if(state.winner===0&&daily.wins<3){daily.wins++;p.gold+=20;}
  for(const [key,threshold] of [['warriors',8],['spells',3],['matches',2]]){
    if(daily[key]>=threshold&&!daily.claimed.includes(key)){daily.claimed.push(key);p.gold+=50;}
  }
  if(week.matches>=10&&!week.claimed){week.claimed=true;p.gold+=300;p.freePacks++;}
  return p;
}
export function deckOwned(profile,deck) {
  const counts={};for(const id of deck)counts[id]=(counts[id]??0)+1;
  return Object.entries(counts).every(([id,count])=>(profile.inventory[id]??0)>=count);
}
export function missingDust(profile,deck) {
  const counts={};for(const id of deck)counts[id]=(counts[id]??0)+1;
  return Object.entries(counts).reduce((sum,[id,count])=>sum+Math.max(0,count-(profile.inventory[id]??0))*CRAFT[CARD_BY_ID[id].rarity],0);
}
