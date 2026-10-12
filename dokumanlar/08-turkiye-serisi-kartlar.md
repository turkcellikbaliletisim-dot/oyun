# 08 — Türkiye Serisi: 40 kart (v0.2)

Bu dosya `oyun/cards.js` kaynağından `npm run docs:cards` ile üretilir. Kart değişikliklerini önce o kaynakta yapın. Kesin zamanlama ve sınırlar için [oyun kurallarına](02-oyun-kurallari.md) bakın. Claude Design tuvali ve bağımsız kart sayfaları `kart-prototipi/` içinde v0.2 olarak güncellenir. Güncel baskı `oyun/baski.html` üzerinden alınır.

20 kartlık deste; aynı karttan en çok 2, her farklı efsaneviden 1 kopya. Y: Yaygın, N: Nadir, E: Efsanevi. Hasar turlar arasında kalıcıdır.

## Savaşçılar (27)

| # | Kart | Enerji | SAL/CAN | Anahtar | Kesin etki | N |
|---|---|---|---|---|---|---|
| 1 | Çoban Çırağı | 1 | 1/2 | — | Etkisi yok. | Y |
| 2 | Akıncı Çırağı | 1 | 2/1 | Hızlı | Hızlı | Y |
| 3 | Kervan Bekçisi | 1 | 1/3 | Koruyucu | Koruyucu | Y |
| 4 | Ney Üfleyen | 1 | 0/2 | — | Oynanınca kendi oyuncunun 1 canını iyileştir. | N |
| 5 | Bozkır Okçusu | 2 | 2/2 | — | Oynanınca rakibe 1 hasar. | Y |
| 6 | Mağara Bekçisi | 2 | 1/4 | Koruyucu | Koruyucu | Y |
| 7 | Zeybek | 2 | 3/2 | — | Etkisi yok. | Y |
| 8 | Meddah | 2 | 1/2 | — | Oynanınca 1 kart çek. | N |
| 9 | Tulpar Sürücüsü | 3 | 3/3 | Hızlı | Hızlı | Y |
| 10 | Kervansaray Tüccarı | 3 | 2/3 | — | Oynanınca bu tur +1 enerji. | Y |
| 11 | Çini Ustası | 3 | 2/4 | — | Oynanınca başka bir dost savaşçıya kalıcı +1/+1 ver. | N |
| 12 | Nasreddin Hoca | 3 | 2/3 | — | Oynanınca en yüksek saldırılı rakip savaşçı rakibin sonraki turunda saldıramaz. Eşitlikte sahaya önce çıkan seçilir. | N |
| 13 | Yeniçeri | 4 | 4/4 | — | Etkisi yok. | Y |
| 14 | Sipahi | 4 | 5/3 | Hızlı | Hızlı | Y |
| 15 | Kale Muhafızı | 4 | 2/6 | Koruyucu | Koruyucu | Y |
| 16 | Şahmaran Yavrusu | 4 | 3/3 | Zehirli | Zehirli | N |
| 17 | Alp Eren | 5 | 5/5 | — | Etkisi yok. | Y |
| 18 | Tepegöz | 5 | 7/3 | — | Oynanınca kendine 1 hasar. | N |
| 19 | Karagöz | 5 | 3/5 | — | Oynanınca rakibe 2 hasar. | N |
| 20 | Hacivat | 5 | 3/5 | — | Oynanınca başka bir dost savaşçının mevcut ve azami canını kalıcı 2 artır. | N |
| 21 | Bozkurt | 6 | 5/6 | — | Sahadaki her diğer dost savaşçı için +1 saldırı. | N |
| 22 | Ocak Topçusu | 6 | 5/5 | — | Oynanınca seçtiğin bir rakip savaşçıya 3 hasar ver. | Y |
| 23 | Dede Korkut | 5 | 3/6 | — | Kendi turunun başında, çekişten önce üst kartına bak; tut veya destenin altına koy. | E |
| 24 | Hızır | 6 | 4/6 | — | Oynanınca tüm dost savaşçıların canı tam dolar. | E |
| 25 | Simurg | 7 | 6/8 | Uçan | Uçan | E |
| 26 | Ergenekon Demircisi | 7 | 5/7 | — | Oynanınca mezarlığından seçtiğin bir dost savaşçıyı temel değerleriyle geri getir. Oynanınca etkisi tekrarlanmaz; boş yer gerekir. | E |
| 27 | Kızılelma | 8 | 8/8 | — | Oynanınca tüm rakip savaşçılara 2 hasar. | E |

## Büyüler (8)

| # | Kart | Enerji | SAL/CAN | Anahtar | Kesin etki | N |
|---|---|---|---|---|---|---|
| 28 | Kılıç Bileme | 1 | — | — | Bir dost savaşçıya bu tur +2 saldırı ver. | Y |
| 29 | Şifalı Ot | 1 | — | — | Seçtiğin oyuncunun veya savaşçının 3 canını iyileştir; azami canını aşamaz. | Y |
| 30 | Fırtına Bulutu | 2 | — | — | Seçtiğin oyuncuya veya savaşçıya 3 hasar ver. | Y |
| 31 | Nazar Boncuğu | 2 | — | — | Bir dost savaşçı bu turun sonuna kadar hasar almaz. | Y |
| 32 | Pazar Pazarlığı | 2 | — | — | 2 kart çek, ardından elinden seçtiğin 1 kartı at. Boş deste çekiş başına 1 hasar verir. | N |
| 33 | Kar Fırtınası | 3 | — | — | Rakibin şu an sahada bulunan savaşçıları rakibin sonraki turunda saldıramaz. | N |
| 34 | Tufan | 4 | — | — | Tüm savaşçılara 2 hasar. | N |
| 35 | Ergenekon'dan Çıkış | 5 | — | — | Tüm dost savaşçılara kalıcı +2/+2. | E |

## Tuzaklar (5)

| # | Kart | Enerji | SAL/CAN | Anahtar | Kesin etki | N |
|---|---|---|---|---|---|---|
| 36 | Tuzak Kuyu | 2 | — | — | Rakibin 3 enerji veya daha ucuz bir savaşçısı saldırınca onu yok et. | Y |
| 37 | Yankı | 2 | — | — | Rakip büyü oynayınca büyüyü iptal et. | N |
| 38 | Kale Surları | 3 | — | — | Rakibin ilk geçerli saldırısında açılır. Bu turun sonuna kadar kendi oyuncunun ve savaşçılarının aldığı hasarı yarıya indir (aşağı yuvarla). | Y |
| 39 | Hile | 3 | — | — | Rakibin savaşçısı saldırırken hasardan önce onu eline geri gönder. El doluysa yok edilir; güçlendirmeleri kaybolur. | N |
| 40 | Kervan Yolu Pusu | 4 | — | — | Rakip elinden savaşçı oynadığında, oynanınca etkisinden önce ona 4 hasar ver. | Y |

## Dağılım ve test

20 Yaygın, 14 Nadir, 6 Efsanevi; 27 Savaşçı, 8 Büyü, 5 Tuzak. Sayımlar otomatik testlerle doğrulanır. Denge henüz insan maçlarıyla doğrulanmadı; özellikle Uçan, Hızlı, toplu hasar ve ilk oyuncu avantajı izlenecek. Bot simülasyonu insan testinin yerine geçmez.

## Görsel kaynaklar

İsimler tarihî ve kültürel anlatılardan esinlenir. Bu durum modern görseller, çeviriler ve müzikler için otomatik kullanım hakkı sağlamaz. 40 kart için proje özelinde yapay zekâ yardımıyla üretilmiş ayrı illüstrasyonlar kullanılır. Görsel eşlemesi ve kaynak dosyaları `kart-prototipi/art.js` ve `kart-prototipi/gorseller/` içindedir; kültürel doğruluk ve yayın hakları incelemesi ayrıca yapılmalıdır.
