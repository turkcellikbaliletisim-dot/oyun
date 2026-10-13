# Godot ve Mac geliştirmesi

Depo kökündeki `project.godot`, Godot **4.x Standard** projesidir. Bu Mac’te **4.7.2** ile import, gerçek OpenGL çizimi ve oynanış doğrulandı. GDScript kullanır; .NET gerekmez. Sahne `native/main.tscn`, arayüz `native/main.gd`. Kırk resim mevcut atlaslardan okunur; kopya görsel seti yoktur.

## Mac'te aç

1. Node.js 22+ ve [Godot 4.6.3 Standard macOS Universal](https://github.com/godotengine/godot-builds/releases/tag/4.6.3-stable) kur. Universal sürüm Apple Silicon ve Intel içindir.
2. Depoyu indir veya `git clone https://github.com/turkcellikbaliletisim-dot/oyun.git` ile al.
3. Finder'da `native/Mac-Baslat.command` dosyasını aç. Godot uygulaması `/Applications/Godot.app` konumundaysa sunucu ve editör birlikte başlar. Başka konum için Terminal'de `GODOT_BIN="/uygulamanın/yolu/Godot" bash native/Mac-Baslat.command` kullan.
4. Godot'ta **F5** ile oyunu başlat. Başlatıcı mevcut sağlıklı sunucuyu kullanır. Sunucu yoksa Docker çalışıyorsa Compose, aksi halde arka planda Node başlatır. Sunucu editör kapandıktan sonra çalışmaya devam eder.

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

Bulutta Godot 4.6.3 ile import, 40 atlas, bütün eğitim maçı, hamle/ödül/paket, tekrar, yeniden bağlantı ve hesap kurtarma geçti. Linux X11/OpenGL yazılımsal çizimde gerçek Godot penceresi de çalıştırıldı. Bu Mac’te Godot 4.7.2 ile gerçek pencere ve OpenGL çizimi, 360×800 / 390×844 dikey, 844×390 yatay ve 1280×900 masaüstü düzenleri kontrol edildi. iOS/Android cihaz kurulumu, yerel dosya penceresi ve mağaza paketi henüz doğrulanmadı.

Godot ekran görüntüleri: [kart masası](../dokumanlar/godot-match.png) ve [koleksiyon](../dokumanlar/godot-collection.png).

## Mac uygulaması dışa aktarımı

`export_presets.cfg` içinde **macOS Development** vardır: Universal mimari, geliştirme bundle kimliği, imzasız ZIP. Godot Editor → Manage Export Templates ile **aynı 4.6.3** şablonlarını kur; Export → macOS Development → Export Project. Çıktı `native-builds/` dizinindedir ve Git'e alınmaz.

Bu görevde Mac ZIP oluşturulmadı; export şablonları ortamda yoktu. App Store/başkalarına dağıtım için gerçek bundle kimliği, Apple Developer imzası/notarizasyonu ve fiziksel Mac testi gerekir. Preset geliştirme içindir; imzalı yayın değildir.

## Docker ve mobil önizleme

`native/Mobil-Onizle.command` dosyasına çift tıklamak sunucuyu hazırlar ve oyunu 1024×576 yatay telefon önizlemesinde açar. `native/Mac-Baslat.command` Godot editörünü açar. Sunucu adresi ayarlara taşındı; lobi, koleksiyon, deste ve maç ekranları genişliğe göre yerleşir. Dokunma alanları en az 48 birimdir. Tur ve başlangıç eli onayı kaydırılan içerikten bağımsız alt çubuktadır. Mobil platformlarda güvenli ekran kenarları hesaba katılır.

```sh
docker compose up --build -d --wait server
docker compose ps
docker compose logs --tail 50 server
docker compose stop server
```

Docker `127.0.0.1:8080` üzerinden hizmet verir ve mevcut `.data` hesabını/kayıtlarını kullanır. Aynı veri klasörüyle ikinci bir Node süreci başlatma. Bu yerel Docker kurulumu başka telefondan erişilemez; telefondaki Godot istemcisi için ortak HTTPS sunucusu ve Android/iOS dışa aktarımı gerekir. Telefon mağaza paketi bu değişiklikte üretilmedi.

Bağlantı düzeltmesi: önceki Mac testleri geçici sunucu portunu gerçek `user://destan-session.cfg` dosyasına yazıyordu. Test kayıtları artık geçici ayrı klasördedir. Editörde kapanmış yerel portla karşılaşılırsa varsayılan yerel sunucuya dönülür. Çalışan özel sunucu ve HTTPS adresi değiştirilmez.

`GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot npm run test:native` hem oynanışı hem dört ekran boyutunda lobi/koleksiyon/deste/maç düzenlerini ve gerçek hesabın testlerden etkilenmediğini kontrol eder. Gerçek pencere ve PNG kontrolleri için `DESTAN_NATIVE_VISUAL=1` ekle. Normal Mac bağlantısını Docker açıkken kontrol etmek için Godot’ta `--headless --path . --script tests/native-startup.gd` kullanılır; bu komut gerçek oyuncu ayarlarıyla bağlanır.

## Yeni mobil oyun arayüzü

`native/main.tscn` artık `native/mobile.gd` sunum katmanını açar. `native/main.gd` hesap, sunucu bağlantısı ve mevcut oyun davranışlarını sağlar; kart verileri ve kurallar değiştirilmez. Görsel varlıklar `native/mobile-assets/` içindedir.

- Ana menü: illüstrasyonlu hızlı oyun ve hikâye kartları; Oyna düğmesinde bot/arkadaş/lig seçimi.
- Yolculuk: on bölümün görsel kartları, açılma koşulları ve tamamlanma durumu.
- Savaş: yatay masa, kahraman portreleri/canları, enerji, deste yığını, eldeki kartlar ve hedef seçimi. Bir kartı masaya sürükleyerek oyna; saldırmaya hazır savaşçıyı rakip kahramana veya geçerli savaşçıya sürükle. Kartı seçip görünen hamle düğmesiyle de oynayabilirsin. Masanın dışına bırakmak kartı tüketmez.
- Koleksiyon: parşömen kartlar, enerji/saldırı/can rozetleri, tür filtreleri, kart detayında üretme/parçalama ve gerçek sunucu ödüllerini gösteren sandık açılışı.
- Sonuç ekranı ve hasar/tur geri bildirimi. Ses tercihi ve kendi desten aynı hesabın yeniden açılışında korunur.

Varsayılan mobil yön yataydır; Godot mantıksal ekranı 844×390, Mac oyun penceresi 1280×720’dir. Düzen testleri ayrıca 360×800 ve 390×844 dar ekranları denetler. Fiziksel Android/iOS dokunma, güvenli alan ve mağaza paketi hâlâ cihaz üzerinde doğrulanmalıdır. Bu değişiklik bir APK/IPA veya herkese açık HTTPS sunucusu yayımlamaz.

`npm run test:native`, ekran testlerinin yanında gerçek Godot girdi olaylarıyla sürükleyerek kart oynama, geçersiz bırakmayı iptal etme ve sürükleyerek kahramana saldırma testlerini çalıştırır. Geçici test hesapları gerçek oyuncu dosyalarını değiştirmez.
