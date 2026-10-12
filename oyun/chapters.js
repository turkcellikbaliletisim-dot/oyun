import { DECKS } from './decks.js';
import { CARD_BY_ID } from './cards.js';
const replace = (deck, oldId, newId) => deck.map(id => id === oldId ? newId : id);
const played = (stats,id) => (stats.cardPlays[id] ?? 0) > 0;
const typePlayed = (stats,type) => Object.keys(stats.cardPlays).some(id => CARD_BY_ID[id].type === type);
export const CHAPTERS = [
  {id:1,title:'Kervansaray Kapısı',place:'Anadolu yolu',enemy:'Gölge Çırak',
    dialogue:'Evladım, bir destan unutuldu mu bir yürek soğur. İlk savaşçını çağır; bu kapıyı birlikte açalım.',
    task:'En az 1 savaşçı oyna, 1 saldırı yap ve kazan.',deck:DECKS.starter.cards,foe:DECKS.starter.cards,passive:true,
    complete:stats=>typePlayed(stats,'warrior') && stats.attacks>=1},
  {id:2,title:'Mağaranın Sesi',place:'Kapadokya',enemy:'Mağara Gölgesi',
    dialogue:'Mağara sesi geri verir, muhafız saldırıyı. Koruyucu çağır; rakip sana ulaşmadan onu geçmek zorunda.',
    task:'Bir Koruyucu oyna ve kazan.',deck:DECKS.starter.cards,foe:DECKS.starter.cards,
    complete:stats=>[3,6,15].some(id=>played(stats,id))},
  {id:3,title:'Perde Açılıyor',place:'Karagöz-Hacivat perdesi',enemy:'Perde Gölgesi',
    dialogue:'Hacivat der ki sözün gücü vardır. Karagöz der ki o zaman bir büyü göster! Kartını doğru hedefe yönelt.',
    task:'En az 1 büyü oyna ve kazan.',deck:DECKS.starter.cards,foe:DECKS.starter.cards,
    complete:stats=>typePlayed(stats,'spell')},
  {id:4,title:'Pazarın Kalbi',place:'Kapalıçarşı',enemy:'Unutuş Tüccarı',
    dialogue:'İyi pazarlık her şeyi almak değil, neyi bırakacağını bilmektir. İki kart çek, birinden vazgeç.',
    task:'Pazar Pazarlığı oyna ve kazan.',deck:replace(DECKS.starter.cards,28,32),foe:DECKS.starter.cards,
    complete:stats=>played(stats,32)},
  {id:5,title:'Bozkırın Çağrısı',place:'Orta Asya bozkırı',enemy:'Gölge Akıncı',
    dialogue:'Bozkırda bekleyen değil, zamanı bilen kazanır. Hızlı savaşçın geldiği tur saldırabilir.',
    task:'En az 1 Hızlı savaşçı oyna ve kazan.',deck:DECKS.tempo.cards,foe:DECKS.starter.cards,
    complete:stats=>[2,9,14].some(id=>played(stats,id))},
  {id:6,title:'Hoca’nın Kuyusu',place:'Akşehir',enemy:'Hileci Gölge',
    dialogue:'Hoca gülümser: Her kuyu su vermez evladım! Tuzağını gizli kur, rakibin hamlesini bekle.',
    task:'Tuzak Kuyu kur ve kazan.',deck:replace(DECKS.starter.cards,28,36),foe:DECKS.tempo.cards,
    complete:stats=>played(stats,36)},
  {id:7,title:'Şahmaran’ın Sırrı',place:'Toros Dağları',enemy:'Yılan Gölgesi',
    dialogue:'Küçük bir yara büyük bir efsaneyi susturabilir. Zehirli, gerçekten hasar verdiği savaşçıyı yok eder.',
    task:'Şahmaran Yavrusu oyna ve kazan.',deck:replace(DECKS.starter.cards,13,16),foe:DECKS.starter.cards,
    complete:stats=>played(stats,16)},
  {id:8,title:'Kar Fırtınası',place:'Erzurum',enemy:'Buz Elçisi',
    dialogue:'Bazen zafer bir tur kazanmaktır. Fırtına rakibin şu an sahadaki savaşçılarını sonraki turda durdurur.',
    task:'Kar Fırtınası oyna ve kazan.',deck:replace(DECKS.starter.cards,28,33),foe:DECKS.tempo.cards,
    complete:stats=>played(stats,33)},
  {id:9,title:'Tepegöz’ün Mağarası',place:'Dede Korkut destanı',enemy:'Tepegöz Gölgesi',
    dialogue:'Güç bedelsiz gelmez. Tepegöz sahaya çıktığında kendine hasar verir; onu korumayı öğren.',
    task:'Tepegöz oyna ve kazan.',deck:replace(DECKS.tempo.cards,19,18),foe:DECKS.control.cards,
    complete:stats=>played(stats,18)},
  {id:10,title:'Ergenekon',place:'Demir dağ',enemy:'Unutuş’un Elçisi',
    dialogue:'Mühür demirden değil, hatırlayan yüreklerden dövülür. Öğrendiğin bütün yollar şimdi sana açık.',
    task:'Bir savaşçı, bir büyü ve bir tuzak oyna; ardından kazan.',deck:DECKS.control.cards,foe:DECKS.tempo.cards,
    complete:stats=>['warrior','spell','trap'].every(type=>typePlayed(stats,type))},
];
export function chapterCompleted(chapter,state) {
  return state.status === 'finished' && state.winner === 0 && chapter.complete(state.players[0].stats);
}
