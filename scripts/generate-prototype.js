import { writeFileSync, readFileSync } from 'node:fs';
import { CARDS } from '../oyun/cards.js';
import { ART } from '../kart-prototipi/art.js';

const type={warrior:{name:'SAVAŞÇI',accent:'#a64d35',foot:''},spell:{name:'BÜYÜ',accent:'#287777',foot:'ANLIK ETKİ'},trap:{name:'TUZAK',accent:'#67538b',foot:'GİZLİ OYNANIR'}};
const rarity={common:{label:'YAYGIN',rim:'#a77d4c'},rare:{label:'NADİR',rim:'#6c9fc4'},legendary:{label:'EFSANEVİ',rim:'#d5ae42'}};
const escape=value=>String(value).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;');
const styles=`
*{box-sizing:border-box}body{margin:0;color:#25342b;background:#ece5d4;font-family:system-ui,sans-serif}
.paper{width:794px;height:1123px;padding:0 40px;background:#fff}.sheet-head{height:62px;display:flex;justify-content:space-between;align-items:center;font-size:11px;color:#63563e}.grid{display:grid;grid-template-columns:repeat(3,238px);grid-auto-rows:333px;gap:0}.card{width:238px;height:333px;padding:5px;border-radius:14px;box-shadow:inset 0 0 0 1px #6b4c32}.face{width:100%;height:100%;padding:6px;border-radius:9px;background:#f6ecd4;display:flex;flex-direction:column;gap:4px}.head{height:32px;flex:none;display:flex;align-items:center;justify-content:space-between;gap:6px}.name{font:700 16px/1.05 Georgia,serif;flex:1;min-width:0}.cost{width:28px;height:28px;flex:none;border-radius:50%;background:#286969;border:2px solid #7ca6a0;color:#fff;display:flex;align-items:center;justify-content:center;font:700 18px Georgia,serif}.art{width:100%;height:141px;flex:none;border:1px solid #b8a684;border-radius:6px;background-size:200% 200%;background-repeat:no-repeat;background-color:#d8c9a6}.type{height:11px;flex:none;display:flex;justify-content:space-between;font-size:9px;letter-spacing:.05em;font-weight:700;color:#62503a}.rules{flex:1;min-height:0;background:#fffbef;border:1px solid #d5c6a5;border-radius:5px;padding:4px 6px;display:flex;flex-direction:column;justify-content:center;gap:3px;font-size:10.5px;line-height:1.23}.keyword{font-weight:750;color:#655083}.foot{height:25px;flex:none;display:flex;justify-content:space-between;align-items:center;font-size:9px;color:#675b45}.stats{display:flex;gap:4px;font-size:13px;font-weight:800}.sal,.can{padding:3px 6px;border-radius:12px;color:#fff}.sal{background:#a84a32}.can{background:#2e7156}.stats small{font-size:8px}.page-foot{font-size:10px;color:#6c5b43;margin-top:14px}.reference{width:1180px;height:560px;padding:32px 40px;background:#f1e7ce}.reference h1{font:700 40px Georgia,serif;margin:0 0 8px}.reference p{font-size:13px;line-height:1.5}.reference-layout{display:flex;gap:24px;margin-top:22px}.reference-cards{display:flex;gap:12px}.legend{width:300px;font-size:13px;line-height:1.5}.legend h2{font:700 20px Georgia,serif;margin:0 0 10px}.legend p{margin:8px 0}.legend a{color:#28584d}@page{size:A4;margin:0}@media print{body{background:#fff}.paper{width:210mm;height:297mm;print-color-adjust:exact;-webkit-print-color-adjust:exact}}
`;
function values(ids){return ids.map(id=>{
  const c=CARDS.find(c=>c.id===id),a=ART[id],t=type[c.type],r=rarity[c.rarity],kw=c.keywords.join(' · ');
  return {id,name:c.name,cost:c.cost,atk:c.attack,hp:c.hp,kw,hasKw:!!kw,text:c.text===kw?'':c.text,hasText:c.text!==kw&&!!c.text,isWarrior:c.type==='warrior',isOther:c.type!=='warrior',typeName:t.name,accent:t.accent,foot:t.foot,rarityLabel:r.label,rim:r.rim,artUrl:a.file,artPosition:a.position,artAlt:a.alt};
});}
function markup(c=null,dc=false){
  const val=key=>dc?`{{c.${key}}}`:escape(c[key]);
  const keyword=dc?'<sc-if value="{{c.hasKw}}" hint-placeholder-val="{{true}}"><div class="keyword">{{c.kw}}</div></sc-if>':c.hasKw?`<div class="keyword">${val('kw')}</div>`:'';
  const text=dc?'<sc-if value="{{c.hasText}}" hint-placeholder-val="{{true}}"><div>{{c.text}}</div></sc-if>':c.hasText?`<div>${val('text')}</div>`:'';
  const stats=`<div class="stats"><span class="sal"><small>SAL</small> ${val('atk')}</span><span class="can"><small>CAN</small> ${val('hp')}</span></div>`;
  const end=dc?`<sc-if value="{{c.isWarrior}}" hint-placeholder-val="{{true}}">${stats}</sc-if><sc-if value="{{c.isOther}}" hint-placeholder-val="{{false}}"><span>{{c.foot}}</span></sc-if>`:c.isWarrior?stats:`<span>${val('foot')}</span>`;
  return `<article class="card" data-card-id="${val('id')}" style="background:${val('rim')}"><div class="face" style="border:2px solid ${val('accent')}"><div class="head"><div class="name">${val('name')}</div><div class="cost">${val('cost')}</div></div><div class="art" role="img" aria-label="${val('artAlt')}" style="background-image:url('${val('artUrl')}');background-position:${val('artPosition')}"></div><div class="type"><span>${val('typeName')}</span><span>${val('rarityLabel')}</span></div><div class="rules">${keyword}${text}</div><div class="foot"><span>Anadolu · ${val('id')}/40</span>${end}</div></div></article>`;
}
function board(cards,{main,page},dc){
  const rendered=dc?`<sc-for list="{{cards}}" as="c" hint-placeholder-count="${cards.length}">${markup(null,true)}</sc-for>`:cards.map(c=>markup(c)).join('\n');
  if(main)return `<div class="reference"><h1>Türkiye Serisi</h1><p>40 illüstrasyonlu kart · Anadolu Diyarı · Kurallar v0.2</p><div class="reference-layout"><div class="reference-cards">${rendered}</div><aside class="legend"><h2>Kartı okuma</h2><p>Üstteki daire enerji maliyeti. SAL saldırı, CAN can değeridir. Savaşçı hasarı turlar arasında kalır.</p><p><strong>Savaşçı:</strong> sahaya çıkar ve savaşır.<br><strong>Büyü:</strong> anlık etkidir.<br><strong>Tuzak:</strong> gizli kurulur, olay gerçekleşince açılır.</p><h2>Nadirlik</h2><p>Bronz: Yaygın · Mavi: Nadir · Altın: Efsanevi. Nadirlik adı kartta yazılıdır.</p><p>63×88 mm kartlar; beş A4 sayfa. Her kart için ayrı bir illüstrasyon.</p>${dc?'':'<p><a href="index.html">40 kartı incele</a> · <a href="../oyun/baski.html">Tüm seti bas</a></p>'}</aside></div></div>`;
  return `<div class="paper"><div class="sheet-head"><span>Türkiye Serisi · Sayfa ${page}/5 · v0.2</span><span>Kartları kenarlarından kes · 63×88 mm</span></div><div class="grid">${rendered}</div><div class="page-foot">A4 · %100 ölçek · üstbilgi/altbilgi kapalı · arka plan grafikleri açık</div></div>`;
}
for(let page=0;page<=5;page++){
  const main=page===0,name=main?'Main':`Sayfa${page}`,ids=main?[9,30,36]:CARDS.slice((page-1)*9,page*9).map(c=>c.id),cards=values(ids),width=main?1180:794,height=main?560:1123;
  const title=main?'Kart şablonu ve rehber':`Kart Sayfası ${page}`;
  const html=`<!doctype html>\n<html lang="tr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${title} · v0.2</title><style>${styles}</style></head><body>${board(cards,{main,page},false)}</body></html>\n`;
  const dc=`<!doctype html>\n<html lang="tr"><head><meta charset="utf-8"><title>${title} · v0.2</title><script src="./support.js"></script></head><body><x-dc><helmet><style>${styles}</style></helmet>${board(cards,{main,page},true)}</x-dc><script type="text/x-dc" data-dc-script data-props='{"$preview":{"width":${width},"height":${height}}}'>\nclass Component extends DCLogic {\nrenderVals() { return { cards: ${JSON.stringify(cards,null,2)} }; }\n}\n</script></body></html>\n`;
  writeFileSync(new URL(`../kart-prototipi/${name}.html`,import.meta.url),html);
  writeFileSync(new URL(`../kart-prototipi/${name}.dc.html`,import.meta.url),dc);
}
const canvasPath=new URL('../kart-prototipi/canvas.json',import.meta.url),canvas=JSON.parse(readFileSync(canvasPath,'utf8'));
canvas.title='Türkiye Serisi Kart Prototipi v0.2';canvas.notes.sheets.text='40 illüstrasyonlu kart · A4, 3×3 · 63×88 mm · v0.2';
writeFileSync(canvasPath,JSON.stringify(canvas,null,2)+'\n');
console.log('6 Claude Design tuvali ve 6 bağımsız HTML sayfası güncellendi.');
