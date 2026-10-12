import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {CARDS} from '../oyun/cards.js';
import {DECKS} from '../oyun/decks.js';
import {CHAPTERS} from '../oyun/chapters.js';
test('Godot card, deck and story data exactly matches the authoritative game source',()=>{
  const actual=JSON.parse(readFileSync(new URL('../native/data.json',import.meta.url),'utf8'));
  assert.deepEqual(actual,JSON.parse(JSON.stringify({cards:CARDS,decks:DECKS,chapters:CHAPTERS})));
});
