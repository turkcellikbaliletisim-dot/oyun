import {newProfile,loginReward,matchReward,chapterReward,missingDust} from '../oyun/economy.js';
import {DECKS} from '../oyun/decks.js';
// Yoğun katılım senaryosu; gerçek oyuncu ölçümü değil. Başlangıç pazartesi.
const state={status:'finished',winner:0,turn:16,history:[{p:0,action:{type:'play'}},{p:0,action:{type:'attack'}}],players:[{stats:{cardPlays:{1:8,30:3}}}]};
for(const days of [7,30,90]){
  let p=chapterReward(newProfile(),1);
  for(let i=0;i<days;i++){
    const date=new Date('2026-10-12T12:00:00Z');date.setUTCDate(date.getUTCDate()+i);const day=date.toISOString().slice(0,10);
    p=loginReward(p,day);
    for(let n=0;n<3;n++)p=matchReward(p,{id:`${day}-${n}`,state,day});
  }
  console.log(`${days} gün: ${p.gold} altın; ${Math.floor(p.gold/300)} altın paketi + ${p.freePacks} ücretsiz paket = ${Math.floor(p.gold/300)+p.freePacks} paket; ${p.gold%300} altın kalır.`);
}
let p=newProfile();console.log(`Başlangıç → Bozkır eksik üretim maliyeti: ${missingDust(p,DECKS.tempo.cards)} toz.`);
for(let id=1;id<=10;id++)p=chapterReward(p,id);
console.log(`Hikâye sonrası: ${missingDust(p,DECKS.tempo.cards)} toz; ${Object.values(p.inventory).filter(Boolean).length} farklı kart + 7 arşiv seçimi.`);
