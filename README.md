# Destan Diyarları

Türkiye temalı kart savaş oyununun **oynanabilir v0.2 prototipi**. 40 kart, bot rakip, üç hazır deste, deste oluşturma, 10 hikâye bölümü, yerel koleksiyon ekonomisi, kayıt ve basılabilir kartlar içerir. Ticari mobil yayın değil; insan denge testleri ve üretim gereksinimleri sürüyor.

## Çalıştırma

Gerekenler: Python 3, modern tarayıcı. Testler için Node.js 22+. Harici JavaScript paketi yok; `npm install` gerekmez.

```sh
cd /workspace/oyun
npm start
```

Alternatif: `python3 -m http.server 8000 --bind 127.0.0.1` (depo kökünde). Sunucu kökündeki `index.html` oyundur. Uygulamayı HTTP üzerinden açın; `file://` ile ES modülleri yüklenmeyebilir. Mevcut bir sunucu varsa ikinci süreç başlatmayın.

## Oyna

1. Serbest maçta üç hazır desteden birini seç veya 20 kartlık kendi desteni oluştur. Serbest denemede tüm kartlar açıktır; istersen yalnız sahip olduğun kartlarla oynarsın. Koleksiyon ekranında altınla ücretsiz paket aç, tozla üret veya kart parçala.
2. Koleksiyon ekranında giriş ödülü, görevler, paket garantisi ve sahip olduğun kartları gör. Finalde eksik kart arşivi açılır. Bu ekonomi yereldir ve gerçek para içermez.
3. Hikâye modunda Anadolu'nun 10 bölümünü sırayla oyna. Görevi yerine getirip kazanırsan sonraki bölüm açılır.
4. Başlangıç elinde değiştirmek istediğin kartlara dokun, onayla.
5. Önce kartlarını oyna, sonra hazır savaşçıyla hedef seçip saldır. Bir savaşçı turda bir kez saldırır; ilk saldırıdan sonra kart oynanmaz.
6. Ana menüden kayıtlı maça devam edebilirsin. JSON indir/yükle aynı kurallarla maçı yeniden oluşturur. Tarayıcı verileri silinirse yerel ilerleme kaybolur; kayıt bulut hesabı değildir.

45 saniyelik tur isteğe bağlı; varsayılan çalışma süresiz. Aynı deste ve tohum aynı başlangıcı verir. Bot açık bilgiyle tek hamle ve seçili kalkan/güçlendirme birleşimlerini değerlendirir; rakibin gizli eline, tuzak kimliğine veya bilinmeyen deste sırasına bakmaz. Eğitim rakibidir. Ses isteğe bağlıdır.

Maç sonunda **Bu maçı değerlendir** ile yerel oyuncu testi kaydı oluşturabilirsin. Ana menüden CSV indir; özet için `python3 scripts/analyze-playtests.py dosya.csv`. Kartları oynamadan okumak için elde/sahada **İncele** düğmesini kullan.

## Kontroller

```sh
npm test
npm run simulate
npm run economy
npm run docs:cards
npm run prototype
```

`docs:cards`, tek kart kaynağından 08 belgesini yeniler. `economy` yoğun katılım senaryolarını hesaplar. `simulate` 60 bot maçı ve aynı sonuç veren kayıt tekrarını doğrular; insan dengesi testi sayılmaz.

Python Playwright ve Chromium bulunan ortamda, sunucu açıkken `python3 tests/browser-smoke.py` gerçek tarayıcı akışını test eder. Bu test aracı oyunun çalışma bağımlılığı değildir.

## Kartları bas

`oyun/baski.html`: güncel 40 kart, beş A4 kart sayfası ve bir deste/kural sayfası. Yazdırma: A4, %100 gerçek boyut, üstbilgi/altbilgi kapalı, arka plan grafikleri açık. Her kart 63×88 mm; fiziksel yazıcıda ilk kartın ölçüsünü kontrol edin. İlk set her karttan bir kopya içerir; iki oyuncunun aynı başlangıç destesi için başlangıç kartlarını dörder kopyaya tamamlayın.

**[kart-prototipi/](kart-prototipi/README.md)** güncel 40 kartın illüstrasyonlarını, galeriyi, PDF'i, bağımsız HTML sayfalarını ve Claude Design tuvalini içerir. `Main.dc.html` ve `Sayfa1.dc.html`–`Sayfa5.dc.html` v0.2 ile güncellendi. Aynı adlı `.html` dosyaları Claude çalışma zamanı gerektirmez. `npm run prototype` tuvali ve sayfaları `oyun/cards.js` ile `kart-prototipi/art.js` kaynaklarından üretir.

## Belgeler

- [Kurallar v0.2](dokumanlar/02-oyun-kurallari.md), [40 kart](dokumanlar/08-turkiye-serisi-kartlar.md)
- [Dünya](dokumanlar/01-hikaye-ve-dunya.md), [10 bölüm](dokumanlar/03-hikaye-bolumleri.md), [ilk hafta](dokumanlar/04-ilk-hafta-deneyimi.md)
- [Sayısal ekonomi taslağı](dokumanlar/05-ekonomi-ve-gelir.md), [hukuk inceleme dosyası](dokumanlar/06-hukuki-cerceve.md)
- [Üretim planı](dokumanlar/07-yol-haritasi.md), [teknik mimari](dokumanlar/09-teknik-mimari.md)
- [Test ve denge](dokumanlar/10-test-ve-denge-plani.md), [sanat/ses/erişilebilirlik](dokumanlar/11-sanat-ses-ve-erisilebilirlik.md)
- [Doğrulama sonuçları](dokumanlar/13-dogrulama-sonuclari.md)
- [Tamamlanan işler ve kalan yayın kapıları](dokumanlar/12-durum-ve-yayin-kapilari.md)

## Kapsam

Şu anda hesap, online lig, sunucu tarafından korunan koleksiyon, gerçek ödeme, takas, mobil mağaza paketi yok. 40 kartın ayrı illüstrasyonu oluşturuldu; görseller proje için yapay zekâ yardımıyla üretildi. Oyun harici analitik/font/CDN isteği yapmaz. Yerel istemci ve kayıtlar güvenilir sunucu otoritesinin yerine geçmez. Hukuk/mağaza uygunluğu ve gerçek oyuncu dengesi doğrulanmış değildir.
