# Godot ve Mac geliştirmesi

Depo kökündeki `project.godot`, Godot **4.6.3 Standard** projesidir. GDScript kullanır; .NET gerekmez. Sahne `native/main.tscn`, arayüz `native/main.gd`. Kırk resim mevcut atlaslardan okunur; kopya görsel seti yoktur.

## Mac'te aç

1. Node.js 22+ ve [Godot 4.6.3 Standard macOS Universal](https://github.com/godotengine/godot-builds/releases/tag/4.6.3-stable) kur. Universal sürüm Apple Silicon ve Intel içindir.
2. Depoyu indir veya `git clone https://github.com/turkcellikbaliletisim-dot/oyun.git` ile al.
3. Finder'da `native/Mac-Baslat.command` dosyasını aç. Godot uygulaması `/Applications/Godot.app` konumundaysa sunucu ve editör birlikte başlar. Başka konum için Terminal'de `GODOT_BIN="/uygulamanın/yolu/Godot" bash native/Mac-Baslat.command` kullan.
4. Godot'ta **F5** ile oyunu başlat. Terminal penceresini açık tut; editör kapanınca başlatıcının kendi açtığı sunucu normal biçimde kapanır. Var olan sunucuya dokunmaz.

Elle başlatma: depo kökünde `npm run online`; Godot Project Manager → Import → `project.godot` → Edit → F5. Oyun varsayılan olarak `http://127.0.0.1:8080` adresine bağlanır. Paylaşımlı bir sunucu kurulursa arayüzden HTTPS adresini gir. Mac'teki localhost yalnız aynı Mac'ten erişilir; başka cihazla oynama için ortak HTTPS sunucusu gerekir.

## Oynanabilir kapsam

Bot, 10 hikâye bölümü ve görev kartı garantisi; arkadaş odası kodu; final sonrası lig; kart oynama, hedef/saldırı seçimi, mulligan, tuzaklar, scry/discard/diriltme; 40 resimli koleksiyon, paket, üretim/parçalama/arşiv; sahip olunan 20 karttan deste oluşturma; hesap kurtarma ve maç kaydı indirme.

Mac özellikleri: Retina/HiDPI, yeniden boyutlanan pencere, tam ekran, ⌘F tam ekran, ⌘S biten maç kaydı, Escape seçimi iptal; `FileDialog.use_native_dialog` ile macOS dosya kaydetme penceresi. Klavye odağı Tab/Enter ile çalışır. Ses varsayılan kapalı; açıldığında Godot özgün kısa hamle sesi üretir.

Bu Godot sürümü **yerel veya uzak Node sunucusuna bağlıdır**. Kural motoru, bütün kart etkileri, saat ve ekonomi ortak sunucuda çalışır; Godot istemcisi sunucunun görünür durumundan üretilmiş legal hamleleri gönderir. Sunucusuz çevrimdışı Godot motoru henüz port edilmedi. Mevcut web sürümü çevrimdışı oynanabilir.

Godot oturum bilgisi `user://destan-session.cfg` içinde, belirsiz ağ sonucunun tekrar işlem kaydı `user://destan-pending.json` içinde tutulur. Mac'te bunlar `~/Library/Application Support/Godot/app_userdata/Destan Diyarları/` altındadır. Kurtarma anahtarı yalnız bellekte kalır; kullanıcı isterse yerel dosya olarak kaydeder. Hesap anahtarını paylaşma. Anahtar yenileme ve hesap silme mevcut `online.html` arayüzündedir.

## Geliştirme ve doğrulama

Kartları `oyun/cards.js`, desteleri `oyun/decks.js`, hikâyeyi `oyun/chapters.js` üzerinde düzenle; sonra `npm run native:data`. Godot JSON kaynağı otomatik üretilir; elle ikinci kart kaynağı oluşturma.

```sh
npm test
npm run test:native
```

İkinci komut PATH'te `godot` ister; başka yol için `GODOT_BIN=/tam/yol/Godot npm run test:native`. Geçici sunucu ve hesap dizinleri oluşturup temizler. Linux CI'da `scripts/install-godot.sh` resmi 4.6.3 arşivini sabit SHA512 ile doğrular. Node ve Godot kontrolleri GitHub Actions'a eklendi; uzak CI sonucunu çalıştırılmadan geçmiş kabul etme.

Bulutta Godot 4.6.3 ile import, 40 atlas, bütün eğitim maçı, hamle/ödül/paket, tekrar, yeniden bağlantı ve hesap kurtarma geçti. Linux X11/OpenGL yazılımsal çizimde gerçek Godot penceresi de çalıştırıldı. **Fiziksel Mac, Retina ekran, macOS yerel dosya penceresi ve mağaza paketi burada test edilmedi.**

Godot ekran görüntüleri: [kart masası](../dokumanlar/godot-match.png) ve [koleksiyon](../dokumanlar/godot-collection.png).

## Mac uygulaması dışa aktarımı

`export_presets.cfg` içinde **macOS Development** vardır: Universal mimari, geliştirme bundle kimliği, imzasız ZIP. Godot Editor → Manage Export Templates ile **aynı 4.6.3** şablonlarını kur; Export → macOS Development → Export Project. Çıktı `native-builds/` dizinindedir ve Git'e alınmaz.

Bu görevde Mac ZIP oluşturulmadı; export şablonları ortamda yoktu. App Store/başkalarına dağıtım için gerçek bundle kimliği, Apple Developer imzası/notarizasyonu ve fiziksel Mac testi gerekir. Preset geliştirme içindir; imzalı yayın değildir.
