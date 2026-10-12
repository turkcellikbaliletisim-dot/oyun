# 02 - Oyun Kuralları (v0.1)

Kart listesi için `08-turkiye-serisi-kartlar.md` dosyasına bakın.

## Hazırlık
- Her oyuncu 20 kartlık deste kurar. Aynı karttan en fazla 2 adet, Efsanevi karttan en fazla 1 adet.
- Başlangıç canı 20.
- Başlangıç eli 4 kart. Oyuncu bir kez "mulligan" yapıp istediği kartları desteye karıştırıp aynı sayıda yeni kart çekebilir.
- Başlayan oyuncu ilk turda kart çekmez. İkinci oynayan oyuncu ilk turunda 1 ekstra kart alır (denge için).

## Tur akışı
1. **Çekiş:** 1 kart çek.
2. **Enerji:** Enerji 1 artar (en fazla 8) ve tam dolar.
3. **Ana faz:** Kart oyna (Savaşçı, Büyü, Tuzak), sırayla ve istediğin kadar, enerjin yettiği sürece.
4. **Saldırı:** Hazır savaşçılarınla saldır.
5. **Bitiş:** Hasar gören savaşçıların canı yenilenir, "bu tur" etkileri biter.

Tur süresi 45 saniyedir. Süre dolarsa tur otomatik biter.

## Savaş
- Saldıran savaşçı bir hedef seçer: rakibin bir savaşçısı veya doğrudan rakip.
- Rakipte **Koruyucu** savaşçı varsa, önce onlar hedef alınmak zorundadır.
- İki savaşçı çarpışınca ikisi de birbirine saldırı değeri kadar hasar verir. Canı sıfırlanan yok olur.
- Savaşçı sahaya çıktığı tur saldıramaz (Hızlı olanlar hariç).
- Rakibe doğrudan saldırıda savaşçının saldırı değeri kadar can düşer.

## Sınırlar
- Sahada en fazla 5 savaşçı.
- Elde en fazla 7 kart. Fazla çekilen kart yok olur.
- Gizli en fazla 2 Tuzak.
- Deste biterse her turun başında 1 hasar alınır.

## Tuzaklar
- Ana fazda gizli oynanır ve enerjisi hemen harcanır.
- Tetikleyici gerçekleşince açılır ve etki uygulanır, sonra yok olur.
- Rakip aynı turda oynanan tuzağı göremez.

## Kazanma
Rakibin canını 0'a indiren kazanır. 20 turdan sonra hâlâ bitmemişse canı fazla olan kazanır.

## Anahtar kelimeler
- **Hızlı:** Sahaya çıktığı tur saldırabilir.
- **Koruyucu:** Rakip önce bu kartlara saldırmak zorundadır.
- **Zehirli:** Hasar verdiği savaşçıyı yok eder.
- **Uçan:** Sadece Uçan savaşçılar ve büyüler ona zarar verebilir.

## Beceriyi öne çıkaran tasarım kuralları
- Zar, yazı-tura veya "%X ihtimalle çalışır" etkisi yoktur.
- Rakibin açık bilgisi (saha, can, enerji) herkese açık, gizli bilgi sadece el ve tuzaklardır.
- Güç farkı nadirlikten değil kart sinerjisinden gelir.

## Sıralama (lig) sistemi
- Eşleşme Elo benzeri bir puanla yapılır.
- Ligler: Çırak, Kalfa, Usta, Destancı, Efsane.
- Ücretli kartı olmayan oyuncu da en üst lige çıkabilmelidir (başlangıç destesi ve günlük görevlerle iyi bir deste kurulabilmeli).
