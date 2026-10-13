# Eksik görseller ve yapılacaklar

Son kod listesi güncellemesi: 2026-10-13 09:50 UTC. Görsel eki: 2026-10-13, PR #4 — dal: `claude/mobil-arayuz-skin-v2` (arayüz `native/mobile.gd` + `native/skin_chrome.gd` + `native/landscape_match.gd` + `native/art_slice.gd`). Eski `otomatik/saatlik` dalındaki tek dosyalı `main.gd` çalışması esas alınmadı; yalnızca düzeltilmiş PNG'ler (`icon_net_ok/bad.png`, `logo.png`) taşındı.

## Yapılanlar
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

## Hâlâ eksik / yapılacak (kod)
- [x] Uygulama içi yükleme ekranı bağlandı (süre sabit 1,6 sn; gerçek yükleme ilerlemesine bağlı değil — yapılacak).
- [ ] `header_bar.png`, `table_center.png` bağlı değil.
- [ ] Kalan küçük simgeler bağlı değil: `icon_close/replay/league` (`icon_check/lock` bağlandı), `fx_fire/flood/frost/shield/number_bg` (büyü efektleri kart bazlı eşlenmedi), `gem_*` (eski), `icon_cards/deck/play/story` (alt gezinme soketlerinde kullanılmıyor olabilir, denetle).
- [ ] Hedef halkası birim kartlarında yok (yalnızca kahraman); kartta dikdörtgen vurgu kullanılıyor.
- [ ] `hero_player_alt3..5` ve hero_ring maç içi çerçeve olarak kullanılmıyor.
- [ ] Gerçek ses/müzik (aşağıda).
- [ ] `tests/native-interaction.gd` bazen (nadiren) "freed instance" ile düşüyor; yeniden çalışınca geçiyor — zamanlama kaynaklı, incelenmeli. PR #4'ün başarılı çalışması bu aralıklı hatanın çözüldüğü anlamına gelmez.
- [ ] Gerçek cihaz/Mac'te görsel kabul; Linux llvmpipe ekran görüntüleri gözle kontrol edildi.

## Sorunlar
- `splash.png` içinde iki boş çubuk/çerçeve çizimi gömülü; yükleme ekranında kendi çubuğumuzla çakışıyor (aşağıdaki tabloda temiz splash isteniyor).
- Yatay maç düzeninde seçili kart bilgi paneli (sağ sütun) uzun efekt metninde dar kalabilir.
- [x] `lane*.png` opak/dikdörtgen dış kenar sorunu için yeni şeffaf şeritler ve kesit bağlantısı hazırlandı; sınırlı yatay/dikey ekran kontrolü yapıldı. Fiziksel cihaz kabulü ayrıca gerekli.

## Ek görsel üretimleri (ChatGPT için)
Orijinal paket dosyalarında eksik yok (114/114 mevcut). İpucu paneli bu pakete ek dosyadır; eski 114'lük manifest sayımı değiştirilmedi.

| Dosya | Boyut | Durum / kısa prompt |
|---|---|---|
| `hero_player_alt3.png` .. `alt5.png` | 512x512 | YAPILACAK: Mevcut kahramanla aynı stil ve altın çerçeve; farklı yaş/cinsiyet/kıyafetle Anadolu kahramanı; şeffaf dış. |
| `lane.png` / `lane_enemy.png` | 1024x400 | GÖRSEL YENİLENDİ: Ahşap-altın şerit, şeffaf yuvarlak dış kenar, koyu-mat ve sade merkez. |
| `loading_tip_panel.png` | 900x160 | DOSYA HAZIR: Yazısız ahşap-altın panel, şeffaf dış. Yükleme akışı BAĞLI DEĞİL. |
| `splash.png` (temiz) | 1242x2688 | YAPILACAK: Mevcut splash'ın aynısı (elma, kahraman, minareler, gün batımı) ama alt kısımdaki çubuk/çerçeve çizimleri OLMADAN; alt %25 koyu sade zemin. |
| `badge_rank_bronze/silver/gold.png` | 128x128 | YAPILACAK: Türk motifli rütbe rozeti, şeffaf arka plan. |

## Gerçek ses/müzik (eksik)
Geçici sesler yerine gerçek kayıt: `music_menu.ogg`, `music_battle.ogg` (96 sn, döngüsel; ney/saz/zurna), efektler `click, card_flip, play_card, attack, hit, spell, heal, pack_open, turn_start, end_turn, victory, defeat`. Prompt: "Anadolu ezgili, ney ve bağlama ağırlıklı, 96 sn kesintisiz döngülü menü müziği; ikinci parça savaş için davul/zurna ile tempolu."
