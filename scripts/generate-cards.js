import { writeFileSync } from 'node:fs';
import { CARDS } from '../oyun/cards.js';
const rarity={common:'Y',rare:'N',legendary:'E'};
const groups=[['Savaşçılar','warrior'],['Büyüler','spell'],['Tuzaklar','trap']];
let out='# 08 — Türkiye Serisi: 40 kart (v0.2)\n\nBu dosya `oyun/cards.js` kaynağından `npm run docs:cards` ile üretilir. Kart değişikliklerini önce o kaynakta yapın. Kesin zamanlama ve sınırlar için [oyun kurallarına](02-oyun-kurallari.md) bakın. Eski Claude Design kaynakları v0.1 arşividir; güncel baskı `oyun/baski.html` üzerinden alınır.\n\n20 kartlık deste; aynı karttan en çok 2, her farklı efsaneviden 1 kopya. Y: Yaygın, N: Nadir, E: Efsanevi. Hasar turlar arasında kalıcıdır.\n';
for(const [name,type] of groups){
 const cards=CARDS.filter(c=>c.type===type);
 out+=`\n## ${name} (${cards.length})\n\n| # | Kart | Enerji | SAL/CAN | Anahtar | Kesin etki | N |\n|---|---|---|---|---|---|---|\n`;
 for(const c of cards)out+=`| ${c.id} | ${c.name} | ${c.cost} | ${type==='warrior'?`${c.attack}/${c.hp}`:'—'} | ${c.keywords.join(', ')||'—'} | ${c.text} | ${rarity[c.rarity]} |\n`;
}
out+='\n## Dağılım ve test\n\n20 Yaygın, 14 Nadir, 6 Efsanevi; 27 Savaşçı, 8 Büyü, 5 Tuzak. Sayımlar otomatik testlerle doğrulanır. Denge henüz insan maçlarıyla doğrulanmadı; özellikle Uçan, Hızlı, toplu hasar ve ilk oyuncu avantajı izlenecek. Bot simülasyonu insan testinin yerine geçmez.\n\n## Görsel kaynaklar\n\nİsimler tarihî ve kültürel anlatılardan esinlenir. Bu durum modern görseller, çeviriler ve müzikler için otomatik kullanım hakkı sağlamaz. Prototipte soyut simgeler kullanılır; özgün illüstrasyon ve hak belgeleri yayın kapısıdır.\n';
writeFileSync(new URL('../dokumanlar/08-turkiye-serisi-kartlar.md',import.meta.url),out);
console.log('08-turkiye-serisi-kartlar.md: 40 kart güncellendi.');
