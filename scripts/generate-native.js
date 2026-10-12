import {writeFileSync} from 'node:fs';
import {CARDS} from '../oyun/cards.js';
import {DECKS} from '../oyun/decks.js';
import {CHAPTERS} from '../oyun/chapters.js';
writeFileSync(new URL('../native/data.json',import.meta.url),JSON.stringify({cards:CARDS,decks:DECKS,chapters:CHAPTERS},null,2)+'\n');
