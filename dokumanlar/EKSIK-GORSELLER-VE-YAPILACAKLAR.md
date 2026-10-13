# Eksik görseller ve yapılacaklar

Son kod listesi güncellemesi: 2026-10-13 14:00 UTC. Görsel eki: 2026-10-13, PR #4 — dal: `claude/mobil-arayuz-skin-v2` (arayüz `native/mobile.gd` + `native/skin_chrome.gd` + `native/landscape_match.gd` + `native/art_slice.gd`). Eski `otomatik/saatlik` dalındaki tek dosyalı `main.gd` çalışması esas alınmadı; yalnızca düzeltilmiş PNG'ler (`icon_net_ok/bad.png`, `logo.png`) taşındı.

## Yapılanlar
- 2026-10-13 (kullanıcı isteği): **Çevrimdışı mod eklendi.** Sunucu yokken oyun artık kilitlenmiyor. `native/offline_engine.gd` (oyun/engine.js + bot.js'nin GDScript karşılığı) ve `native/offline.gd` (hesap, yolculuk, bot maçı, sandık/üret/parçala/arşiv, ödüller; kayıt `user://destan-offline.json`) eklendi. `connect_account` sunucuya 5 sn dener, ulaşamazsa ya da adres geçersizse `enter_offline()` ile cihazdaki motora geçer; ayarlardaki 'Bağlan' önce çevrimiçini dener. Arkadaş odası ve lig çevrimiçi kalır (açık hata mesajı). Doğrulama: `tests/offline-parity.js` + `.gd` JS motoru ile 50 oyun / ~3400 adımı (bot kararları dahil) birebir karşılaştırır → 0 fark; `tests/native-offline.gd` sunucusuz açılış, bölüm 1 kazanma/ödül, bot maçı, paket, kalıcılık. `npm test` 78/78, `test:native` GEÇTİ. Not: çevrimdışı hesap, çevrimiçi hesaptan ayrıdır (eşitleme yok).
- 2026-10-13 11:50 UTC: Yeni ChatGPT yüklemesi yoktu (main hâlâ e336526; diğer dallar zaten birleşik ya da eski). `claude/oynanis-duzeltmeleri-2` (bildirim kartları örtmesin, dikey 'Turu bitir' okunur, can eksiye düşmesin) bu dala birleştirildi. `npm test` 78/78, `test:native` GEÇTİ (Godot 4.7.2, xvfb), yatay lobi ekran görüntüsü gözle kontrol edildi. Eksik görsel kalmadı; kalanlar: gerçek ses/müzik ve fiziksel cihaz kabulü.
- 2026-10-13 (Mac, commit): yeni kahramanlar, rozetler, temiz splash ve yerel kod bağlantıları GitHub'a gönderildi.
- Yerel tamamlamalar (2026-10-13): `header_bar` ve `table_center`; küçük kontrol/lig/tekrar simgeleri; birim hedef halkaları; maçta kahraman çerçevesi; altı kahraman seçeneği; karta göre büyü efektleri ve hasar sayı zemini bağlandı. Sağ sütunda tam kart inceleme düğmesi var. Yükleme ilerlemesi tamamlanan yerel kaynak hazırlığı ve sunucu bağlantı kontrolüne bağlı; sabit 1,6 saniyelik dolum kaldırıldı. Temiz splash ve alt3–5 kahramanlar, üç lig rozeti üretildi.
- Aralıklı test hatası yeniden üretildi: sürükleme yordamı beş kare beklerken arayüz yenileniyor ve elindeki kart düğümü siliniyordu. Test semantik el indeksi/birim UID'sini saklayıp beklemeden sonra canlı düğümü buluyor. `DESTAN_INTERACTION_STRESS=1` bu araya gerçek yeniden çizim koyarak regresyonu kontrol eder. Oyun, ekran yenilenirken aktif sürüklemeyi iptal etmeyi korur.
- Mac Godot 4.7.2 / Apple M5 OpenGL kontrolleri: üst/alt çubuk, dört ekran boyutu, 667×375–1280×720 savaş geometrisi, dokunma, stres girdileri, yaşam döngüsü ve eğitim/ödül/paket/tekrar/kurtarma geçti. Görsel kabul örnekleri `native-builds/previews/acceptance/` içinde. Bir ara gerçek hesap izolasyonu kontrolü açık editördeki eşzamanlı kayıt nedeniyle başarısız oldu; son gerçek renderer çalışması bu kontrol dahil geçti.
- 2026-10-13 10:50 UTC: Yeni ChatGPT yüklemesi/dal yoktu (main hâlâ e336526). `claude/oynanis-duzeltmeleri` (Turu bitir düğmesi / yatay kart büyütme) bu dala birleştirildi. `icon_replay` (Maç kaydı), `icon_league` (Lig maçı), `icon_close` (paket kapat) düğmelere bağlandı (`icon_on` yardımcısı). `npm test` 78/78, `test:native` GEÇTİ (Godot 4.7.2, xvfb).
- 2026-10-13 09:50 UTC: Son saatte yeni ChatGPT yüklemesi/dal yoktu (tüm uzak dallar bu dalda birleşik; `otomatik/saatlik`, `yeni-gorsel-*`, `ogg-ci-dogrulama` yalnızca eski çalışma). Bölüm kartı düğmesine `icon_check.png` (tamamlandı) ve `icon_lock.png` (kilitli) bağlandı. `npm test` 78/78, `test:native` GEÇTİ (Godot 4.7.2, xvfb).
- 2026-10-13 08:45 UTC: `gorsel-kalite/serit-yenileme-20261013` dalı (şeffaf şeritler, `loading_tip_panel.png`) bu dala birleştirildi; `gorsel-kalite/ogg-ci-dogrulama` ve `otomatik/saatlik` dallarında yeni olan şey yalnızca eski `main.gd` çalışmasıydı, kopyalanmadı. `mobile.gd`'ye uygulama içi yükleme ekranı eklendi (`show_loading_screen`): `splash.png` + `loading_bar_frame/fill.png` (1,2 sn dolum) + `loading_tip_panel.png` içinde rastgele ipucu, 1,6 sn sonra solar; test ortamında (`DESTAN_SESSION_DIR` tanımlı) açılmaz. `tests/shots.gd` `0-yukleme` görüntüsü alır. `npm test` 78/78, `test:native` GEÇTİ (Godot 4.7.2, xvfb), yükleme ve ana ekran gözle kontrol edildi.
- 2026-10-13 08:20 UTC: PR #4 (2897925) alındı: şeffaf kenarlı `lane.png`/`lane_enemy.png` yatay ve dikey maçta opaklık 0.7→0.92 ile ekranda doğrulandı; `loading_tip_panel.png` bağlantı bekleyen lobide "İPUCU" paneli olarak bağlandı (şu an yalnızca çevrimdışı lobide; gerçek yükleme ekranı hâlâ yok). Testler geçti.
- 2026-10-13, PR #4: `lane.png` ve `lane_enemy.png` bağımsız çizimlerle yenilendi: 1024×400, gerçek alfa dış kenar, yuvarlak köşe, koyu ve boş merkez. İki şerit çizim çağrısı köşeleri koruyan yatay üç-parça düzenine uyarlandı. `loading_tip_panel.png` (900×160) eklendi; yükleme akışı hâlâ yapılacak. Üç PNG, kaynaklar, hash/geometri ve inceleme notları [SERIT-YENILEME-20261013.md](SERIT-YENILEME-20261013.md) içinde. Oyun/renderer kontrolleri geçti; 844×390 yatay saha ve 390×844 dikey maç gözle incelendi. Fiziksel cihaz testi yapılmadı.
- 2026-10-13 07:55 UTC: Bu çalışma sırasında yeni ChatGPT yüklemesi yoktu (o anki kayıt: main e336526; gorsel-kalite dalları birleşik). Kart plakasına `icon_type_spell/trap` ve `icon_rarity_*` simgeleri, maç ekranına `icon_turn` (tur sayacı) ve `icon_deck_count` (deste sayısı), efektlere `fx_dust` (birim çağırma) ve `fx_spark` (kahraman iyileşme) bağlandı. `npm test` 78/78, `test:native` GEÇTİ (Godot 4.7.2, xvfb), koleksiyon ekran görüntüsü gözle kontrol edildi.
- 2026-10-13 06:55 UTC: Enerji kristalleri `icon_energy_full/empty.png` ile (eski soluk gem_mana kaldırıldı), ses düğmesine `icon_sound_on/off.png`, "Teslim ol" düğmesine `icon_surrender.png`, boş koleksiyon filtresinde `empty_collection.png` bağlandı. Yeni ChatGPT yüklemesi yoktu (main'de yeni commit yok). `npm test` 78/78, `test:native` GEÇTİ, ekran görüntüleri gözle kontrol edildi.
- 2026-10-13: ChatGPT dalları birleştirildi: `gorsel-kalite/mobil-skin-baglantilari` (skin_chrome.gd: arka plan, ağ rozeti, 4 soketli alt gezinme), `gorsel-ihtiyac-denetimi`, `gorsel-kalite/denetim`. Wi-Fi simgeleri ve `logo.png` yeniden üretilmiş sürümle değiştirildi (ekranda doğrulandı).
- Yatay maç düzeni yeniden yazıldı: solda kahramanlar + deste + tur sayacı, ortada iki şerit (`lane_enemy/lane.png`) ve el, sağda "Turu bitir" + enerji. Kartlar ~40 → ~60 px, düğme artık şeride binmiyor. Dikeyde "Turu bitir" kahramanın sağına alındı. Rakip turunda `end_turn_wait.png`.
- Ana ekran: başlıkta `logo_wordmark.png`; alt yarı için "Sandık" ve "Düello" kutuları (`scene_chest/friends.png`, tüm kutu dokunulabilir); yolculuk ilerlemesi `progress_frame/fill.png`.
- `divider.png` (yolculuk/koleksiyon/arkadaş başlıkları), `input_field.png` (LineEdit, yarı ölçekli 9 parça), `scrollbar.png`, `tooltip_panel.png` tema olarak bağlandı.
- Hedef halkası (`target_ring.png`, hedeflenebilir kahramanda nabız animasyonu) ve sürükleme oku (`drag_arrow.png`) bağlandı.
- Paket açılışı: `show_pack_reveal()` — `chest_closed` sallanır → `chest_open` + `pack_reveal_burst`, dokununca kapanır.
- Hesap ekranında kahraman seçici (`hero_player`, `alt1`, `alt2`, seçili olana `hero_ring.png`); seçim oturum dosyasında saklanır, maçta oyuncu portresi buna göre.
- `.import` dosyaları `.gitignore`'a eklendi. `tests/shots.gd` hesap/sandık ekranlarıyla genişletildi.
- Önceki kod çalışmasının test kaydı: `npm test` 78/78; `npm run test:native` (Godot 4.7.2 linux, xvfb) GEÇTİ. Güncel `tests/run-native.js`, `ERROR:` / `SCRIPT ERROR` kayıtlarını başarısızlık sayar; eski "resources still in use yok sayılıyor" notu güncel değildir. Önbellek/oynatım temizliği korunur. Yaşam döngüsü kapanış uyarısı hâlâ ayrıdır.

## Güncel durum
- [x] Gerçek hazırlık adımlarına bağlı uygulama yükleme ilerlemesi; bağlantı beklemesi en fazla 8 saniye, başarısızlıkta adres ayarlarına dönüş.
- [x] `header_bar.png`, `table_center.png` bağlı.
- [x] `icon_check/close/lock/replay/league` bağlı; `fx_fire/flood/frost/shield/number_bg` kullanılıyor. `icon_cards/deck/play/story` dört gezinme soketinde zaten bağlı ve Mac görüntülerinde kontrol edildi. Eski `gem_*` yerine mevcut kristal/stat varlıkları korunuyor; eski varlıkları sırf kullanılmaları için eklemek gerekmiyor.
- [x] Birim kartlarında hedef halkası; kahramanlarda nabız ve maç içi `hero_ring`.
- [x] Alt3–5 kahramanlar ve oturuma kaydedilen altı seçenekli seçim; dar ekranda satırlara bölünür.
- [x] Stale kart referansı regresyonu ve düğme yeniden giydirme callback düzeltmesi.
- [x] Mac gerçek renderer görsel kontrolü ve tam test akışı.
- [ ] Çevrimdışı hesabı çevrimiçi hesapla birleştirme/eşitleme (şimdilik ayrı kayıt).
- [ ] Fiziksel Android cihaz kabulü (çevrimdışı mod dahil). Emülatör/masaüstü testi telefon kabulü sayılmaz.
- [x] 12 yeni Runway ses efekti, OGG/Vorbis 44,1 kHz; süre, tepe ve seviye teknik kontrolleri geçti. İşiterek miks kabulü bekler.
- [ ] İki yeni Anadolu müziği: mevcut ücretsiz Runway planında engellendi; önceki geçici sentez müzikler korunur. Canlı enstrüman kaydı olarak sunulmaz.

## Görsel üretimleri
Orijinal 114'lük paket manifesti korunmuştur. Yeni ekler `native/skin/generated-manifest.json` içinde boyut, kaynak ve SHA256 ile kayıtlıdır.

| Dosya | Boyut | Durum |
|---|---|---|
| `hero_player_alt3.png` .. `alt5.png` | 512×512 | Üretildi, şeffaf dış; hesap seçicisine ve maç portresine bağlı. |
| `splash_clean.png` | 1242×2688 | Gömülü iki çubuk temizlendi; motor ve uygulama yükleme ekranı bu dosyayı kullanır. Eski `splash.png` korunur. |
| `badge_rank_bronze/silver/gold.png` | 128×128 | Üretildi, şeffaf; mevcut sunucu MMR'sinden gösterilir. Lig kuralları değiştirilmedi. |
| `lane.png` / `lane_enemy.png` | 1024×400 | Önceki şeffaf şeritler korunur. |
| `loading_tip_panel.png` | 900×160 | Gerçek hazırlık ekranına bağlı. |

## Paket ve Web doğrulaması
Güncel kaynaklardan Web ve Android geliştirme APK'si yeniden üretildi; APK v2/v3 imzası doğrulandı. Yeni Web paketinde gerçek sürükleme saldırısı ile rakip canı 19→17 oldu; tarayıcı hata günlüğü boştu. Görüntü `native-builds/previews/mobile-web-final.jpg` içinde. Son APK'nin emülatör kurulum denemesi cihaz bağlantısı beklerken 90 saniyede zaman aşımına uğradı; yeni paketin Android açılış testi tamamlanmış sayılmaz. Paket içine HTTPS adresi henüz eklenmedi.

## Kalan sınırlamalar
Uzun kart metni sağ sütunda kaydırılır; “Kartı büyüt” tam açıklamayı açar. Yükleme ilerlemesi yerel hazırlık adımlarının tamamlanmasını ölçer; ağ indirmesinin bayt ilerlemesi değildir. Godot Web motorunun ilk indirme ekranı ayrıca bulunur. Fiziksel telefon, çentik/ısı/batarya ve ses miks kabulü bekler.

## Gerçek ses/müzik (eksik)
Geçici sesler yerine gerçek kayıt: `music_menu.ogg`, `music_battle.ogg` (96 sn, döngüsel; ney/saz/zurna), efektler `click, card_flip, play_card, attack, hit, spell, heal, pack_open, turn_start, end_turn, victory, defeat`. Prompt: "Anadolu ezgili, ney ve bağlama ağırlıklı, 96 sn kesintisiz döngülü menü müziği; ikinci parça savaş için davul/zurna ile tempolu."

Ses teslimi: `dokumanlar/SES-PROMPTLARI.md`, `native/skin/audio/spec.json` ve dosya bazlı kaynak/kalite bilgileri için `native/skin/audio/manifest.json`.

## Verilen kararlar (2026-10-13, kullanıcı: "sen karar ver")
1. **Sunucu barındırma:** Fly.io (tek küçük Node örneği, kalıcı disk/volume, ücretsiz-ucuz katman). Alternatif: Render. Çevrimdışı mod her durumda çalışır, sunucu yalnızca çevrimiçi oyun/eşleşme içindir.
2. **Sıradaki mod:** Önce **birleştirme (merge)**. Otomatik savaş, totem ve yeniden doğuş sonra gelir. Gerekçe: UGACHA'nın çekirdek döngüsü, tamamen çevrimdışı çalışır, sunucu gerektirmez.
3. **Yayın:** Önce Android, Google Play iç test kanalı. Yayın imzası (release keystore) ayrı üretilecek, debug anahtarı yayında kullanılmaz. Geliştirici hesabı (25 USD) kullanıcı tarafından açılmalı.
4. **Görseller:** 21 yeni görsel ChatGPT'den `gorsel-yeni/` klasörüne istendi; yerleştirme sonraki çalışmada.

## Birleştirme modu (2026-10-13)
- Eklendi: `native/merge_engine.gd` (5x4 tahta, 4 tür, 8 seviye, dalga/can/altın, yeniden doğuş yıldızı), çevrimdışı rotalar `merge/*`, ana sayfada "Birleştir" kutusu ve `render_merge` ekranı. Testler: `tests/merge-engine.gd` + `native-offline.gd`.
- Eksik görseller: `merge_frame`, `merge_burst`, `glow_*`, `totem_*` (şimdilik düz renkli düğmeler). Sıradaki: otomatik savaş animasyonu, totemler, bosslar.
- Eklendi (aynı gün): 4 totem (savaş/kalkan/altın/can; en iyi dalga 0/5/10/15'te açılır), her 5. dalgada boss (Kara Kurt, Demir Dev, Gölge Ejder; ödül ×2), tur tur savaş animasyonu (can çubukları). Görsel olarak totem_1..4, boss_1..3 ve merge_burst gelince arayüze takılacak.
