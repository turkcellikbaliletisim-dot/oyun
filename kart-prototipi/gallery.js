import { CARDS } from '../oyun/cards.js';
import { applyCardArt } from './art.js';
const types={warrior:'SAVAŞÇI',spell:'BÜYÜ',trap:'TUZAK'},rarities={common:'YAYGIN',rare:'NADİR',legendary:'EFSANEVİ'};
const el=(tag,text,cls)=>{const node=document.createElement(tag);if(text!==undefined)node.textContent=text;if(cls)node.className=cls;return node;};
function render(){
  const search=document.getElementById('search').value.toLocaleLowerCase('tr'),type=document.getElementById('type').value;
  const cards=CARDS.filter(c=>(type==='all'||c.type===type)&&`${c.name} ${c.text} ${c.keywords.join(' ')}`.toLocaleLowerCase('tr').includes(search));
  const root=document.getElementById('cards');root.replaceChildren();
  for(const c of cards){
    const card=el('article',undefined,`card ${c.rarity}`);card.dataset.cardId=c.id;
    const head=el('div',undefined,'card-head');head.append(el('span',c.name,'name'),el('span',c.cost,'cost'));
    const art=el('div',undefined,'art');applyCardArt(art,c.id);
    const type=el('div',undefined,'type');type.append(el('span',types[c.type]),el('span',rarities[c.rarity]));
    const rules=el('div',undefined,'rules');if(c.keywords.length)rules.append(el('div',c.keywords.join(' · '),'keyword'));if(c.text!==c.keywords.join(' · '))rules.append(el('div',c.text));
    const bottom=el('div',undefined,'bottom');bottom.append(el('span',`Anadolu · ${c.id}/40`));
    if(c.type==='warrior'){const stats=el('div',undefined,'stats');stats.append(el('span',`SAL ${c.attack}`),el('span',` · CAN ${c.hp}`));bottom.append(stats);}else bottom.append(el('span',c.type==='spell'?'ANLIK ETKİ':'GİZLİ OYNANIR'));
    card.append(head,art,type,rules,bottom);root.append(card);
  }
  document.getElementById('count').textContent=`${cards.length}/40 kart`;
}
document.getElementById('search').addEventListener('input',render);document.getElementById('type').addEventListener('change',render);render();
