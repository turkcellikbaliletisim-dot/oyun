import test from 'node:test';
import assert from 'node:assert/strict';
import {feedbackRecord,saveFeedback,feedbackCSV} from '../oyun/playtest.js';
const state={status:'finished',winner:0,first:1,turn:12,players:[{stats:{cardPlays:{1:2,30:1}}}]};
const input={matchId:'m1',mode:'story',chapter:2,elapsedMs:125000,experience:'new',fun:4,again:true,confusion:'Koruyucu hedefini anlamadım.',date:'2026-10-12T12:00:00Z'};
test('feedback records actual match metrics and replaces duplicate match responses',()=>{const r=feedbackRecord(state,input);assert.equal(r.seconds,125);assert.deepEqual(r.cardsPlayed,{1:2,30:1});assert.equal(saveFeedback([r],{...r,fun:5}).length,1);assert.equal(saveFeedback([r],{...r,fun:5})[0].fun,5);});
test('unfinished games and invalid ratings are rejected',()=>{assert.throws(()=>feedbackRecord({...state,status:'playing'},input));assert.throws(()=>feedbackRecord(state,{...input,fun:6}));assert.throws(()=>feedbackRecord(state,{...input,confusion:'a'.repeat(501)}));});
test('CSV preserves Turkish/newlines and neutralizes spreadsheet formula injection',()=>{const r=feedbackRecord(state,{...input,confusion:'=HYPERLINK("kötü")\nİkinci satır'});const csv=feedbackCSV([r]);assert.ok(csv.includes("'=HYPERLINK"));assert.ok(csv.includes('""kötü""'));assert.ok(csv.includes('İkinci satır'));});
