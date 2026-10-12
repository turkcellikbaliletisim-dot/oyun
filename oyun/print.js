import { CARDS } from './cards.js';
import { DECKS } from './decks.js';
import { applyCardArt } from '../kart-prototipi/art.js';
const type = {warrior:'SAVAŞÇI',spell:'BÜYÜ',trap:'TUZAK'};
const rarity = {common:'YAYGIN',rare:'NADİR',legendary:'EFSANEVİ'};
const node = (tag,text,cls) => { const el=document.createElement(tag); if(text!==undefined)el.textContent=text; if(cls)el.className=cls; return el; };
const root=document.getElementById('sheets');
document.getElementById('print-cards').addEventListener('click',()=>window.print());
for(let i=0;i<5;i++){
  const page=node('section'); page.append(node('div',`Türkiye Serisi · v0.2 · Sayfa ${i+1}/5 · 63×88 mm`,'sheet-title'));
  const grid=node('div',undefined,'grid');
  for(const c of CARDS.slice(i*9,i*9+9)){
    const el=node('article',undefined,`card ${c.rarity}`),head=node('div',undefined,'head');
    const illustration=node('div',undefined,'art');applyCardArt(illustration,c.id);
    head.append(node('span',c.name),node('span',c.cost,'cost'));el.append(head,illustration,node('div',`${type[c.type]} · ${rarity[c.rarity]}`,'type'));
    const text=node('div',undefined,'text');
    if(c.keywords.length)text.append(node('div',c.keywords.join(' · '),'keywords'));
    if(c.text!==c.keywords.join(' · '))text.append(node('div',c.text));el.append(text);
    const foot=node('div',undefined,'foot');foot.append(node('span',`Anadolu · ${c.id}/40`));
    if(c.type==='warrior')foot.append(node('span',`SAL ${c.attack} · CAN ${c.hp}`,'stats'));el.append(foot);grid.append(el);
  }
  page.append(grid);root.append(page);
}
const rules=node('section',undefined,'rules');rules.append(node('h1','Başlangıç destesi ve kısa kurallar'),node('p','İki oyuncunun aynı başlangıç destesini kurması için aşağıdaki 10 karttan ikişer kopya gerekir. Bu baskı seti her karttan bir kopya içerir: iki aynı deste için başlangıç kartlarını toplam dört kopyaya tamamlayın.'));
const list=node('ul');for(const id of [...new Set(DECKS.starter.cards)])list.append(node('li',`2 × ${CARDS.find(c=>c.id===id).name}`));rules.append(list);
rules.append(node('p','20 can · 4 başlangıç kartı · 1 kez el değiştirme · 5 savaşçı · 7 el kartı · 2 tuzak. İlk oyuncu ilk tur çekmez; ikinci oyuncu ilk tur 2 kart çeker. Enerji her kendi turunda 1 artar (en çok 8) ve dolar.'),node('p','Kartlarını önce oyna, sonra saldır. Bir savaşçı turda bir kez saldırır, çıktığı tur bekler; Hızlı hemen saldırır. Koruyucu varsa önce ona saldırılır. Savaş hasarı eşzamanlıdır ve turlar arasında kalır. Zehirli yalnız pozitif hasarla savaşçıyı yok eder. Yerdeki savaşçı Uçan’a saldıramaz.'),node('p','Tuzaklar kurulduğu sırayla ve hasardan önce açılır. Bir saldırgan ortadan kalkarsa sonraki saldırı tuzakları açılmaz. 20 tam tur sonunda fazla can kazanır, eşitlik beraberliktir. Ayrıntılı etkileşimler: dokumanlar/02-oyun-kurallari.md.'));root.append(rules);
