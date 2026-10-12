# 05 — Sayısal ekonomi taslağı v0.2

Bu belge `oyun/economy.js` ile çalışan **yerel ücretsiz ekonomi denemesini** ve yayın kapılarını tanımlar. Başlangıç koleksiyonu, altın/toz, paket, garanti, kopya koruması, üretim/parçalama, günlük/haftalık ve bölüm ödülleri uygulanır. Serbest denemede tüm 40 kartı sahiplikten bağımsız deneyebilirsin; koleksiyon modu sahipliği kontrol eder. Gerçek ödeme, takas ve güvenilir sunucu yok. Bu sayılar gerçek satış fiyatı veya doğrulanmış denge sonucu değildir.

## Erişim ve para birimleri

- Altın: yalnız oyunda kazanılan para. İlk yayın taslağında gerçek parayla altın veya kart satışı yok; önce ücretsiz ekonomi doğrulanacak.
- Toz: fazla/istenmeyen kartları parçalayarak kazanılır; kart üretir. Gerçek paraya çevrilmez.
- İlk monetizasyon adayı sabit içerikli kozmetik ve isteğe bağlı kozmetik sezon hattı. Rastgele ücretli paket, takas ve para ödüllü turnuva ayrı karar ve inceleme kapısıdır.
- Başlangıç destesi ücretsiz 20 karttır; bütün rekabetçi kartlar üretilebilir. Ücretsiz oyuncu için lig yetenek sınırı kart satın almaya bağlanmaz.

## Üretim ve parçalama

| Nadirlik | Bir kart üretimi | Bir kart parçalama | Koleksiyon kopya sınırı |
|---|---:|---:|---:|
| Yaygın | 40 toz | 10 toz | 2 |
| Nadir | 100 toz | 25 toz | 2 |
| Efsanevi | 400 toz | 100 toz | 1 |

Üretip parçalamak değer kaybettirir; ücretsiz tekrar ödülü sınırsız çoğaltılamaz. Kart denge değişimi sonrası iade politikası yayın öncesi belirlenmeli. Koleksiyon sınırını aşan sabit bölüm ödülü aynı nadirliğin parçalama karşılığına dönüşür. Takas olmadığı için üretim–takas arbitraj döngüsü ilk sürümde yok.

## Ücretsiz paket

- Fiyat: 300 altın. Beş kart: 3 Yaygın + 1 Nadir + 1 serbest slot.
- Serbest slot temel oranları ayrı ayrı: %65 Yaygın, %20 Nadir, %15 Efsanevi.
- Son Efsanevi'den sonra 9 paket Efsanevi vermediyse 10. paketin serbest slotu Efsanevi olur. Sayaç her Efsanevi'de sıfırlanır. İlk paket sayaç 0 ile açılır. Tek standart paket türü vardır.
- Garanti sayesinde uzun dönem serbest slot Efsanevi oranı temel %15'ten yüksektir: yaklaşık %18,68. Garanti etkisi dahil oranların nasıl gösterileceği gerçek uygulama ve mağaza incelemesinde doğrulanmalı.
- Önce nadirlik seçilir. Aynı nadirlikte sahiplik sınırı dolmamış kartlar arasında eşit seçim yapılır; paket içinde yeni verilen kopyalar da hesaba katılır. O nadirlikte tüm kopyalar doluysa ilgili slot o nadirliğin parçalama tozunu verir. Başka nadirliğe sessizce çevrilmez.
- Paket açma ve sayaç değişimi sunucuda tek atomik işlem olmalı. Yeniden gönderilen istek ikinci paket harcamamalı.

Garanti için hesap: temel başarı p=0,15, en çok 10 paket bekleme. Beklenen paket aralığı `(1 - 0,85^10) / 0,15 ≈ 5,354`; uzun dönem sıklık `1 / 5,354 ≈ 0,1868`. Bu formül sayacın her Efsanevi'de sıfırlanması varsayımı içindir.

## Kazançlar ve sınırlar

| Kaynak | Ödül | Sınır |
|---|---:|---|
| Günlük giriş | 30 altın | Her gün 1 |
| Üç günlük görev | Her biri 50 altın | Her gün 3; bot/online geçerli, eğitim bölümü 1 geçersiz |
| Maç kazanma | 20 altın | Günlük toplam en çok 60 altın |
| Haftalık 10 tamamlanmış maç | 300 altın + 1 paket | Haftada 1 |
| Her 7 giriş günü | 1 paket | Ardışık gün şartı yok; kaçırınca sayaç sıfırlanmaz |
| İlk eğitim bitişi | 100 altın + 1 paket | Hesap başına 1 |
| Bölüm ödülleri | 03 belgesindeki sabit kartlar | İlk tamamlamada 1 |

Günlük görev örnekleri: 8 savaşçı oyna; 3 büyü oyna; 2 maçı tamamla. Kazanma zorunluluğu günlük öğrenme görevlerine konmaz. Teslim olma/kısa maç suistimali için geçerlilik koşulu: en az 4 oyuncu turu ve 2 gerçek hamle; sunucu kaydından doğrulanır. Normal maç kazanma ödülü bu koşulla uygulanır.

## 7/30/90 günlük senaryolar

Aktif ücretsiz oyuncu varsayımı: her gün giriş, üç görevin tamamı, 3 geçerli galibiyet; her hafta haftalık görev tamam. Günlük 240 altın, haftalık ek 300 altın. İlk gün 100 altın ve 1 paket, her 7 girişte 1 paket. Başlangıç altını sıfır.

| Süre | Toplam altın kazanımı | Altınla paket | Ücretsiz paket | Toplam paket | Kalan altın |
|---|---:|---:|---:|---:|---:|
| 7 gün | 2.080 | 6 | 3 | 9 | 280 |
| 30 gün | 8.500 | 28 | 9 | 37 | 100 |
| 90 gün | 25.600 | 85 | 26 | 111 | 100 |

Senaryo pazartesi başlar; 90. güne kadar 13 haftada 10 maç eşiği geçilir (son kısmi hafta dahil). `npm run economy` hesabı uygulanan ödül kurallarıyla yeniden üretir. Bu yoğun katılım senaryosudur; günlük ödül garanti gelir değildir. Hafif oyuncu yalnız giriş ve bir günlük görev yaparsa günde 80 altın kazanır, maç/haftalık ödülü yok: 7 günde 660 altınla 2 paket, giriş/eğitimden 2 ücretsiz paket; toplam 4 paket. İlk haftada tam koleksiyon garantisi verilmez.

Koleksiyon: başlangıç 10 farklı kart; sabit hikâye ile 18; finalde 7 eksik kart seçimiyle en az 25 farklı kart. Paketler ayrıca eklenir. Aynı kartın iki kopyasına ulaşmak farklı kart sayısından ayrı ölçülür.

Deste erişim örneği: başlangıçtan Bozkır Akıncıları'na geçiş için 6 Yaygın ve 2 Nadir eksik kopya gerekir; paket/ödül olmadan 440 toz. Hikâye Sipahi, Karagöz ve Tuzak Kuyu'dan birer kopya verince kalan maliyet 260 toz olur. Arşiv/paket yeni kopyaları bunu azaltabilir. Birkaç gün içinde erişim iddiası gerçek açılış ve görev simülasyonuyla sınanmalıdır; bu hesap yalnız gerekli tozu verir.

## Gelir ve maliyet modeli

Önceki örnek 10.000 aktif × %3 ödeme × 150 TL = 45.000 TL aylık brüt satıştı. Bu kâr değildir. Kozmetik fiyatları ve ödeme dönüşümü kullanıcı araştırması yapılana kadar açık karar olarak tutulur; keyfî gerçek para fiyatı uygulanmaz.

İş modeli tablosu her ay şu satırları içerir: brüt satış; iadeler; mağaza komisyonu; vergiler; net tahsilat; sunucu/servis; sanat/ses; geliştirme; destek; pazarlama; toplam gider; nakit farkı. Komisyon ve vergi gerçek sözleşme ve muhasebeyle doğrulanır. Oyuncu edinme maliyeti, yaşam boyu net katkıyla karşılaştırılmadan reklam bütçesi artırılmaz.

## Yayına geçiş kapısı

Ücretsiz deste erişimi, paket oranları ve garanti testi; kopya koruması; ödeme/iade varsa sunucu doğrulaması; hedef yaş/pazar incelemesi; ekonomi suistimal senaryoları tamamlanmalı. Kayıp bağlantıda ödül iki kez verilmemeli. Yerel paket ve ödül mantığı test edilmiştir; sunucu atomikliği ve ödeme/iade akışları uygulanmış değildir.
