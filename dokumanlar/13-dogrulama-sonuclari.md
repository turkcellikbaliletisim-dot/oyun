# 13 — Doğrulama sonuçları

Bu kayıt otomatik kontrolleri gerçek oyuncu ve gerçek cihaz testlerinden ayırır. Kontroller buluttaki Linux ortamında yapıldı; tarihler: 12 Ekim 2026.

| Kontrol | Sonuç |
|---|---|
| `npm test` | 74/74 geçti: kart etkileri, kurallar, hikâye, ekonomi, bot, geri bildirim, 15 sunucu regresyonu ve Godot veri eşitliği |
| `node tests/run-online-browser.js` | İki ayrı tarayıcı hesabı: oda/katılma, gerçek hamleler, mobil görünüm, yeniden bağlantı, hikâye ödülü, paket, tekrar indirme, üçüncü tarayıcıda hesap kurtarma geçti |
| `python3 tests/pwa-browser.py` | İnternet kapalıyken yeni hikâye maçı, 40 görsel, galeri, baskı, ses/müzik geçti; API yanıtları önbelleğe alınmaz |
| `npm run test:native` | Godot 4.6.3 import; 40 atlas, native koleksiyon, bütün eğitim maçı, legal hamleler, ödül/paket, biten maç tekrarı, cookie yeniden bağlantısı ve kurtarma geçti |
| Godot gerçek pencere | Linux X11 + Mesa llvmpipe OpenGL ile aynı entegrasyon geçti; koleksiyon ve maç ekranları görüntülendi |
| Godot kurucu | Resmi 4.6.3 Linux arşivi indirildi, sabit resmi SHA512 doğrulandı; kurulan binary ile native test geçti |
| Kart/prototip üreticileri | Önceki aşamada 40 ayrı atlas hücresi, galeri, A4 sayfaları ve PDF kontrol edildi; Godot aynı atlasları kullanır |
| Bot simülasyonu | Önceki aşamada 60 maç ve deterministik tekrar geçti; starter–tempo 13/20, tempo–control 17/20, control–starter 8/20 |

Godot arayüzünde Mac için HiDPI, Command kısayolları ve native dosya penceresi ayarlandı. Fiziksel Mac'te bu özellikler **henüz doğrulanmadı**. Mac export şablonları bulunmadığından imzalı veya imzasız Mac ZIP üretilmedi. Godot motoru Linux'ta 4.6.3 Standard ile çalıştırıldı.

Godot istemcisi Node sunucusuna bağlıdır. Mevcut web prototipi çevrimdışı oynanır; Godot'a sunucusuz offline motor portu tamamlandı denmez. Hesaplı oyun tek yazıcılı dosya deposu kullanır; çok süreç/veritabanı ve üretim operasyonu ayrı çalışmadır.

GitHub Actions'a Node kontrolleri ve doğrulanmış Godot kurulumuyla native test eklendi. Buradaki yerel test sonuçları uzak CI çalışmasının sonucu değildir.

Gerçek insan denge/yeni oyuncu testi, fiziksel iOS/Android/Mac, üretim hosting/yük/yedekten dönüş tatbikatı, Apple imza/notarizasyon, mağaza/ödeme ve uzman hukuk incelemesi yapılmadı. Güncel açık işler [12 durum belgesinde](12-durum-ve-yayin-kapilari.md), Mac başlangıcı [native README'de](../native/README.md).
