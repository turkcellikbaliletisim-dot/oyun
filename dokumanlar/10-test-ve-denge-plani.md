# 10 — Test, denge ve beta planı

## Otomatik kontrol

```sh
npm test
npm run simulate
npm run economy
```

Motor testleri yasal desteler, mulligan, enerji, hedef, saldırı, faz, kalıcı hasar, tuzak sırası, donma, Uçan/Zehirli, diriltme, çekiş/atış, el/saha sınırları, galibiyet ve kayıt tekrarını doğrular. Hikâye testleri on bölümün yasal destelerini ve görev + galibiyet şartını kontrol eder. Ekonomi testleri kopya koruması, 10 paket garantisi, tekil ödüller, giriş, görev/haftalık sınırlar, üretim/parçalama ve 25 farklı kart hedefini doğrular.

Simülasyon 60 deterministik bot maçını üç deste çifti ve dönüşümlü ilk oyuncuyla bitirir; sonuçlar kayıt yeniden oynatımı ve sınır kontrollerinden geçer. Bu maçlar insan davranışı veya kart dengesi kanıtı değildir. Mevcut botun kontrol destesiyle zayıf karar vermesi, kartları tek başına zayıf saymak için yeterli değildir.

Yerel sunucu açıkken, Python Playwright ve Chromium bulunan ortamda:

```sh
python3 tests/browser-smoke.py
```

Bu smoke testi gerçek düğmelerle deste oluşturma, hedefleme, eğitim maçı tamamlanması, bölüm açma, koleksiyon/paket/üretim/parçalama, JSON dışa/içe aktarım, sayfa yenileme, tur saati, 390px mobil taşma ve 40 baskı kartının ölçülerini doğrular. PDF ve ekran görüntüsü geçici dizine yazılır. Chromium/Playwright oyun için gerekli değildir; bu tarayıcı kontrolünün araçlarıdır.

GitHub Actions için `.github/workflows/checks.yml` motor/simülasyon/ekonomi ve kart belgesi eşleşme kontrollerini tanımlar. Bu görevde uzak GitHub Actions çalıştırılması yapılmadı; aynı komutlar bulut ortamında çalıştırıldı.

## İnsan keşif testi: ilk 30 maç

Üç deste: Başlangıç, Bozkır, Kadim. Her çift için 10 maç; oyuncular deste ve başlangıç tarafını değiştirir. Oyuncu becerisi kaydedilir. Önce kuralları öğret, sonra sonuçları topla. Süreyi kullanıcı saatinden ölç; otomatik maçın çalışma süresi gerçek oyun süresi değildir.

Şablon: `sablonlar/mac-testleri.csv`. Gerçek maç yokken satır doldurulmaz.

Kaydedilecekler: maç/deste sürümü, iki oyuncu anonim kodu ve deneyimi, ilk oyuncu, sonuç, tur, süre, kullanılan/kullanılamayan kartlar, kritik etkileşim, kural tartışması ve eğlence puanı. Her maçtan sonra “Ne yapacağını anlayamadığın an oldu mu?”, “Bir sonraki maçı oynamak ister misin?” sorularını sor.

İzlenecek hipotezler:

- İlk oyuncu ve Hızlı kartlar açık sahada fazla avantaj sağlıyor mu?
- Uçan karşı seçenekleri yeterli mi?
- Kalıcı hasarla Hızır ve savunma faydalı mı?
- Tuzakların sırası anlaşılır mı? Aynı olayda iki tuzak kullanıcıya doğru gösteriliyor mu?
- Bölüm görev kartını çekememe tekrar denemeyi gereksiz artırıyor mu?
- 20 tam tur limiti kaç maçta sonucu belirliyor?
- Güçlü kart ile güçlü pilot etkisi ayrılabiliyor mu?

30 maç yön gösterir; güvenilir denge için daha büyük örnek gerekir. Her güncellemede tek hipotez, kart/kural sürümü ve beklenen etki kaydedilir. Kart maliyetini yalnız birkaç galibiyete bakarak değiştirme.

## İlk kullanıcı testi

En az 5 yeni oyuncu, farklı mobil ekranlar. Müdahale etmeden bölüm 1–3'ü izleyin. Enerji, saldırı hedefi, Koruyucu, faz geçişi, kayıt ve deste ekranında takıldıkları yerleri kaydedin. Erişilebilirlik için yalnız renk dışındaki işaretleri, klavye odaklarını ve hareket azaltmayı kontrol edin.

Gerçek Android/iOS cihazlarında Safari/Chrome, düşük bellek, arka plana geçme ve dokunma testleri yapılmadan mağaza hazırlığı iddia edilmez. Headless Chromium bu kontrollerin tamamı değildir.

## Online/ödeme sürümü için zorunlu senaryolar

Bağlantı kesilmesi ve tekrar bağlanma; aynı hamlenin iki kez gönderilmesi; sahte sonuç; rakibin gizli eline erişim denemesi; eski sıra numarası; saat manipülasyonu; eşzamanlı ödül talepleri; satın alma doğrulama/iade; hesabı bağlama/silme; envanter kopya sınırı; servis kesintisi ve geri yükleme.

Ödeme ve sunucu henüz yok; bu kontroller bugün çalıştırılmış değildir. Açık kritik hatayla online yayın yapılmaz.
