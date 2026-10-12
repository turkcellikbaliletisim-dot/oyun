import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import { CARDS } from '../oyun/cards.js';
import { ART } from '../kart-prototipi/art.js';

test('all forty cards have a unique illustrated atlas cell and accessible description',()=>{
  assert.deepEqual(Object.keys(ART).map(Number),CARDS.map(c=>c.id));
  assert.equal(new Set(CARDS.map(c=>`${ART[c.id].file}:${ART[c.id].position}`)).size,40);
  for(const c of CARDS)assert.ok(ART[c.id].alt.startsWith(c.name+':'));
  const files=[...new Set(Object.values(ART).map(a=>a.file))];assert.equal(files.length,10);
  for(const file of files){
    const png=readFileSync(new URL(`../kart-prototipi/${file}`,import.meta.url));
    assert.deepEqual([...png.subarray(0,8)],[137,80,78,71,13,10,26,10],file);
    const width=png.readUInt32BE(16),height=png.readUInt32BE(20);
    assert.ok(width>=1200&&height>=800,`${file}: çözünürlük düşük`);
    assert.ok(Math.abs(width/height-1.5)<.01,`${file}: 2×2 atlas en-boy oranı`);
  }
});
test('Claude Design boards and ordinary HTML sheets contain the same canonical forty cards and illustrations',()=>{
  const all=[];
  for(let page=1;page<=5;page++){
    const dc=readFileSync(new URL(`../kart-prototipi/Sayfa${page}.dc.html`,import.meta.url),'utf8');
    const source=dc.match(/<script type="text\/x-dc"[^>]*>([\s\S]*?)<\/script>/)[1];
    const cards=vm.runInNewContext(source+'\nnew Component().renderVals().cards',{DCLogic:class{}},{timeout:1000});
    const plain=readFileSync(new URL(`../kart-prototipi/Sayfa${page}.html`,import.meta.url),'utf8');
    assert.ok(!dc.includes('ÇİZİM ALANI')&&!plain.includes('ÇİZİM ALANI'));
    assert.equal(cards.length,page===5?4:9);
    for(const c of cards){
      const canonical=CARDS.find(card=>card.id===c.id);assert.equal(c.name,canonical.name);assert.equal(c.cost,canonical.cost);assert.equal(c.atk,canonical.attack);assert.equal(c.hp,canonical.hp);
      assert.equal(c.text,c.hasText?canonical.text:'');assert.equal(c.artUrl,ART[c.id].file);assert.equal(c.artPosition,ART[c.id].position);
      assert.ok(plain.includes(`data-card-id="${c.id}"`));assert.ok(plain.includes(c.artUrl));all.push(c.id);
    }
  }
  assert.deepEqual(all,CARDS.map(c=>c.id));
});
