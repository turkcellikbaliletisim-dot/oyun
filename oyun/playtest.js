export const FEEDBACK_VERSION=1;
const fields=['matchId','date','mode','chapter','first','winner','turns','seconds','experience','fun','again','confusion','cardsPlayed'];
export function feedbackRecord(state,{matchId,mode,chapter=0,elapsedMs,experience,fun,again,confusion='',date=new Date().toISOString()}) {
  if(state.status!=='finished')throw new Error('Önce maçı tamamla.');
  if(!['new','familiar','experienced'].includes(experience))throw new Error('Deneyim düzeyini seç.');
  if(!Number.isInteger(fun)||fun<1||fun>5)throw new Error('Eğlence puanı 1–5 olmalı.');
  if(typeof again!=='boolean'||typeof confusion!=='string'||confusion.length>500)throw new Error('Geri bildirim alanları geçersiz.');
  if(typeof matchId!=='string'||!matchId||!Number.isFinite(elapsedMs)||elapsedMs<0)throw new Error('Maç bilgisi geçersiz.');
  return {version:FEEDBACK_VERSION,matchId,date,mode,chapter,first:state.first,winner:state.winner,turns:state.turn,seconds:Math.round(elapsedMs/1000),experience,fun,again,confusion,cardsPlayed:{...state.players[0].stats.cardPlays}};
}
export function saveFeedback(records,record) {
  return [...records.filter(item=>item.matchId!==record.matchId),record];
}
function csvCell(value) {
  let text=typeof value==='object'?JSON.stringify(value):String(value??'');
  // Kullanıcı yorumunu elektronik tabloda formül olarak çalıştırma.
  if(/^[=+\-@\t\r]/.test(text))text="'"+text;
  return '"'+text.replaceAll('"','""')+'"';
}
export function feedbackCSV(records) {
  return fields.join(',')+'\r\n'+records.map(record=>fields.map(field=>csvCell(record[field])).join(',')).join('\r\n')+'\r\n';
}
