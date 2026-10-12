// v0.2: oyun ve baskı için tek kart kaynağı.
export const CARDS = [
  {
    "id": 1,
    "name": "Çoban Çırağı",
    "cost": 1,
    "type": "warrior",
    "attack": 1,
    "hp": 2,
    "keywords": [],
    "rarity": "common",
    "text": "Etkisi yok."
  },
  {
    "id": 2,
    "name": "Akıncı Çırağı",
    "cost": 1,
    "type": "warrior",
    "attack": 2,
    "hp": 1,
    "keywords": [
      "Hızlı"
    ],
    "rarity": "common",
    "text": "Hızlı"
  },
  {
    "id": 3,
    "name": "Kervan Bekçisi",
    "cost": 1,
    "type": "warrior",
    "attack": 1,
    "hp": 3,
    "keywords": [
      "Koruyucu"
    ],
    "rarity": "common",
    "text": "Koruyucu"
  },
  {
    "id": 4,
    "name": "Ney Üfleyen",
    "cost": 1,
    "type": "warrior",
    "attack": 0,
    "hp": 2,
    "keywords": [],
    "rarity": "rare",
    "text": "Oynanınca kendi oyuncunun 1 canını iyileştir."
  },
  {
    "id": 5,
    "name": "Bozkır Okçusu",
    "cost": 2,
    "type": "warrior",
    "attack": 2,
    "hp": 2,
    "keywords": [],
    "rarity": "common",
    "text": "Oynanınca rakibe 1 hasar."
  },
  {
    "id": 6,
    "name": "Mağara Bekçisi",
    "cost": 2,
    "type": "warrior",
    "attack": 1,
    "hp": 4,
    "keywords": [
      "Koruyucu"
    ],
    "rarity": "common",
    "text": "Koruyucu"
  },
  {
    "id": 7,
    "name": "Zeybek",
    "cost": 2,
    "type": "warrior",
    "attack": 3,
    "hp": 2,
    "keywords": [],
    "rarity": "common",
    "text": "Etkisi yok."
  },
  {
    "id": 8,
    "name": "Meddah",
    "cost": 2,
    "type": "warrior",
    "attack": 1,
    "hp": 2,
    "keywords": [],
    "rarity": "rare",
    "text": "Oynanınca 1 kart çek."
  },
  {
    "id": 9,
    "name": "Tulpar Sürücüsü",
    "cost": 3,
    "type": "warrior",
    "attack": 3,
    "hp": 3,
    "keywords": [
      "Hızlı"
    ],
    "rarity": "common",
    "text": "Hızlı"
  },
  {
    "id": 10,
    "name": "Kervansaray Tüccarı",
    "cost": 3,
    "type": "warrior",
    "attack": 2,
    "hp": 3,
    "keywords": [],
    "rarity": "common",
    "text": "Oynanınca bu tur +1 enerji."
  },
  {
    "id": 11,
    "name": "Çini Ustası",
    "cost": 3,
    "type": "warrior",
    "attack": 2,
    "hp": 4,
    "keywords": [],
    "rarity": "rare",
    "text": "Oynanınca başka bir dost savaşçıya kalıcı +1/+1 ver."
  },
  {
    "id": 12,
    "name": "Nasreddin Hoca",
    "cost": 3,
    "type": "warrior",
    "attack": 2,
    "hp": 3,
    "keywords": [],
    "rarity": "rare",
    "text": "Oynanınca en yüksek saldırılı rakip savaşçı rakibin sonraki turunda saldıramaz. Eşitlikte sahaya önce çıkan seçilir."
  },
  {
    "id": 13,
    "name": "Yeniçeri",
    "cost": 4,
    "type": "warrior",
    "attack": 4,
    "hp": 4,
    "keywords": [],
    "rarity": "common",
    "text": "Etkisi yok."
  },
  {
    "id": 14,
    "name": "Sipahi",
    "cost": 4,
    "type": "warrior",
    "attack": 5,
    "hp": 3,
    "keywords": [
      "Hızlı"
    ],
    "rarity": "common",
    "text": "Hızlı"
  },
  {
    "id": 15,
    "name": "Kale Muhafızı",
    "cost": 4,
    "type": "warrior",
    "attack": 2,
    "hp": 6,
    "keywords": [
      "Koruyucu"
    ],
    "rarity": "common",
    "text": "Koruyucu"
  },
  {
    "id": 16,
    "name": "Şahmaran Yavrusu",
    "cost": 4,
    "type": "warrior",
    "attack": 3,
    "hp": 3,
    "keywords": [
      "Zehirli"
    ],
    "rarity": "rare",
    "text": "Zehirli"
  },
  {
    "id": 17,
    "name": "Alp Eren",
    "cost": 5,
    "type": "warrior",
    "attack": 5,
    "hp": 5,
    "keywords": [],
    "rarity": "common",
    "text": "Etkisi yok."
  },
  {
    "id": 18,
    "name": "Tepegöz",
    "cost": 5,
    "type": "warrior",
    "attack": 7,
    "hp": 3,
    "keywords": [],
    "rarity": "rare",
    "text": "Oynanınca kendine 1 hasar."
  },
  {
    "id": 19,
    "name": "Karagöz",
    "cost": 5,
    "type": "warrior",
    "attack": 3,
    "hp": 5,
    "keywords": [],
    "rarity": "rare",
    "text": "Oynanınca rakibe 2 hasar."
  },
  {
    "id": 20,
    "name": "Hacivat",
    "cost": 5,
    "type": "warrior",
    "attack": 3,
    "hp": 5,
    "keywords": [],
    "rarity": "rare",
    "text": "Oynanınca başka bir dost savaşçının mevcut ve azami canını kalıcı 2 artır."
  },
  {
    "id": 21,
    "name": "Bozkurt",
    "cost": 6,
    "type": "warrior",
    "attack": 5,
    "hp": 6,
    "keywords": [],
    "rarity": "rare",
    "text": "Sahadaki her diğer dost savaşçı için +1 saldırı."
  },
  {
    "id": 22,
    "name": "Ocak Topçusu",
    "cost": 6,
    "type": "warrior",
    "attack": 5,
    "hp": 5,
    "keywords": [],
    "rarity": "common",
    "text": "Oynanınca seçtiğin bir rakip savaşçıya 3 hasar ver."
  },
  {
    "id": 23,
    "name": "Dede Korkut",
    "cost": 5,
    "type": "warrior",
    "attack": 3,
    "hp": 6,
    "keywords": [],
    "rarity": "legendary",
    "text": "Kendi turunun başında, çekişten önce üst kartına bak; tut veya destenin altına koy."
  },
  {
    "id": 24,
    "name": "Hızır",
    "cost": 6,
    "type": "warrior",
    "attack": 4,
    "hp": 6,
    "keywords": [],
    "rarity": "legendary",
    "text": "Oynanınca tüm dost savaşçıların canı tam dolar."
  },
  {
    "id": 25,
    "name": "Simurg",
    "cost": 7,
    "type": "warrior",
    "attack": 6,
    "hp": 8,
    "keywords": [
      "Uçan"
    ],
    "rarity": "legendary",
    "text": "Uçan"
  },
  {
    "id": 26,
    "name": "Ergenekon Demircisi",
    "cost": 7,
    "type": "warrior",
    "attack": 5,
    "hp": 7,
    "keywords": [],
    "rarity": "legendary",
    "text": "Oynanınca mezarlığından seçtiğin bir dost savaşçıyı temel değerleriyle geri getir. Oynanınca etkisi tekrarlanmaz; boş yer gerekir."
  },
  {
    "id": 27,
    "name": "Kızılelma",
    "cost": 8,
    "type": "warrior",
    "attack": 8,
    "hp": 8,
    "keywords": [],
    "rarity": "legendary",
    "text": "Oynanınca tüm rakip savaşçılara 2 hasar."
  },
  {
    "id": 28,
    "name": "Kılıç Bileme",
    "cost": 1,
    "type": "spell",
    "attack": 0,
    "hp": 0,
    "keywords": [],
    "rarity": "common",
    "text": "Bir dost savaşçıya bu tur +2 saldırı ver."
  },
  {
    "id": 29,
    "name": "Şifalı Ot",
    "cost": 1,
    "type": "spell",
    "attack": 0,
    "hp": 0,
    "keywords": [],
    "rarity": "common",
    "text": "Seçtiğin oyuncunun veya savaşçının 3 canını iyileştir; azami canını aşamaz."
  },
  {
    "id": 30,
    "name": "Fırtına Bulutu",
    "cost": 2,
    "type": "spell",
    "attack": 0,
    "hp": 0,
    "keywords": [],
    "rarity": "common",
    "text": "Seçtiğin oyuncuya veya savaşçıya 3 hasar ver."
  },
  {
    "id": 31,
    "name": "Nazar Boncuğu",
    "cost": 2,
    "type": "spell",
    "attack": 0,
    "hp": 0,
    "keywords": [],
    "rarity": "common",
    "text": "Bir dost savaşçı bu turun sonuna kadar hasar almaz."
  },
  {
    "id": 32,
    "name": "Pazar Pazarlığı",
    "cost": 2,
    "type": "spell",
    "attack": 0,
    "hp": 0,
    "keywords": [],
    "rarity": "rare",
    "text": "2 kart çek, ardından elinden seçtiğin 1 kartı at. Boş deste çekiş başına 1 hasar verir."
  },
  {
    "id": 33,
    "name": "Kar Fırtınası",
    "cost": 3,
    "type": "spell",
    "attack": 0,
    "hp": 0,
    "keywords": [],
    "rarity": "rare",
    "text": "Rakibin şu an sahada bulunan savaşçıları rakibin sonraki turunda saldıramaz."
  },
  {
    "id": 34,
    "name": "Tufan",
    "cost": 4,
    "type": "spell",
    "attack": 0,
    "hp": 0,
    "keywords": [],
    "rarity": "rare",
    "text": "Tüm savaşçılara 2 hasar."
  },
  {
    "id": 35,
    "name": "Ergenekon'dan Çıkış",
    "cost": 5,
    "type": "spell",
    "attack": 0,
    "hp": 0,
    "keywords": [],
    "rarity": "legendary",
    "text": "Tüm dost savaşçılara kalıcı +2/+2."
  },
  {
    "id": 36,
    "name": "Tuzak Kuyu",
    "cost": 2,
    "type": "trap",
    "attack": 0,
    "hp": 0,
    "keywords": [],
    "rarity": "common",
    "text": "Rakibin 3 enerji veya daha ucuz bir savaşçısı saldırınca onu yok et."
  },
  {
    "id": 37,
    "name": "Yankı",
    "cost": 2,
    "type": "trap",
    "attack": 0,
    "hp": 0,
    "keywords": [],
    "rarity": "rare",
    "text": "Rakip büyü oynayınca büyüyü iptal et."
  },
  {
    "id": 38,
    "name": "Kale Surları",
    "cost": 3,
    "type": "trap",
    "attack": 0,
    "hp": 0,
    "keywords": [],
    "rarity": "common",
    "text": "Rakibin ilk geçerli saldırısında açılır. Bu turun sonuna kadar kendi oyuncunun ve savaşçılarının aldığı hasarı yarıya indir (aşağı yuvarla)."
  },
  {
    "id": 39,
    "name": "Hile",
    "cost": 3,
    "type": "trap",
    "attack": 0,
    "hp": 0,
    "keywords": [],
    "rarity": "rare",
    "text": "Rakibin savaşçısı saldırırken hasardan önce onu eline geri gönder. El doluysa yok edilir; güçlendirmeleri kaybolur."
  },
  {
    "id": 40,
    "name": "Kervan Yolu Pusu",
    "cost": 4,
    "type": "trap",
    "attack": 0,
    "hp": 0,
    "keywords": [],
    "rarity": "common",
    "text": "Rakip elinden savaşçı oynadığında, oynanınca etkisinden önce ona 4 hasar ver."
  }
];
export const CARD_BY_ID = Object.fromEntries(CARDS.map(card => [card.id, card]));
