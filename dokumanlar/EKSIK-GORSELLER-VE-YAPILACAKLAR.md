# Eksik görseller ve yapılacaklar

Son güncelleme: 2026-10-13 00:50 UTC (5. saatlik çalışma; önceki: 23:55, 22:45, 21:45, 20:40 UTC) (dal: `otomatik/saatlik`). Kaynak: GitHub `main` (e336526). Mac'teki ~/Desktop/oyun bu çalışmada erişilebilir değildi.

## Yapılanlar
- 2026-10-13 00:50 UTC: main ve ChatGPT dallarında (gorsel-kalite/*) yeni commit yok; hepsi zaten dalda. **Yeni bağlamalar (`native/main.gd`):** `toast_banner.png` (bildirim şeridi, 9-slice 65/43), `tooltip_panel.png` (TooltipPanel teması, 60/40 tahmini kenar), `target_ring.png` ("HEDEF SEÇ" başlığında simge). `integration.gd` skin yükleme testine toast/tooltip/target_ring/drag_arrow eklendi. `npm test` 74/74, `npm run test:native` GEÇTİ (Godot 4.7.2).
- 2026-10-12 23:55 UTC: main'de yeni commit yok (e336526). ChatGPT'nin `gorsel-kalite/denetim-20261013` notu (GORSEL-KALITE-DENETIMI.md) bu dala merge edildi. **Düzeltilen görseller:** `icon_net_ok/bad.png` artık Wi-Fi simgesi (altın halka; kötü olan üstü çizili, kırmızı), `logo.png` `logo_wordmark.png`'den 1024x512 olarak yeniden üretildi (atlas kırpımı değil). **Yeni bağlamalar (`native/main.gd`):** lobide `logo.png`, `divider.png` ayırıcıları, `scrollbar.png` (VScrollBar grabber), `end_turn_ready.png` (tur bitir butonu), `button_red.png` (teslim ol). `integration.gd` içine skin dosyası yüklenebilirlik testi eklendi. `npm test` 74/74, `npm run test:native` GEÇTİ (Godot 4.7.2 linux). Görsel doğrulama (ekran görüntüsü) hâlâ Mac'te yapılmalı.
- 2026-10-12 22:45 UTC: main'de yeni commit yok (e336526). ChatGPT'nin `gorsel-kalite/denetim-20261013` notundaki hata düzeltildi: `native/integration.gd` OGG akışında olmayan `.data` okuyordu → `audio.stream != null` kontrolüne çevrildi. Godot 4.7.2 (linux) bu ortamda indirilip **`npm run test:native` GEÇTİ** (40 atlas, tam eğitim, ödül/paket, replay, reconnect, kurtarma). `npm test`: 74/74. Yeni bağlamalar: `input_field.png` (LineEdit 9-slice 33/22/33/22), buton `focus` durumu altın doku, `play_sound(ad)` ile olay sesleri (`pack_open`, `victory`, `defeat`, varsayılan `click`).
- 2026-10-12 21:45 UTC: main'de yeni commit yok (e336526); `otomatik/saatlik` zaten güncel. İlk görsel bağlama yapıldı (`native/main.gd`): `skin()`/`skin_box()` yardımcıları, tüm butonlarda `button_dark/gold.png` 9-slice (100,32,100,32), `background.png` tam ekran arka plan, `audio/click.ogg` tıklama sesi. Dosya yoksa eski düz stile geri düşer. **Godot ile test edilemedi** (bu ortamda Godot yok); Mac'te `npm run test:native` çalıştırılmalı. `npm test`: 74/74.
- 2026-10-12 20:40 UTC: `main` incelendi. "Yeni görsel" ve "Yeni görsel 2" paketleri main'de; `yeni-gorsel-2-20261012` dalı main'den yalnızca 4 CI workflow dosyası kadar fazla, `yeni-gorsel-import-20261012` eski bir alt kümedir (yeni içerik yok).
- `dokumanlar/skin_v2_expected.json` içindeki 114 PNG'nin hepsi `native/skin/` içinde var, boyutları birebir doğru (Pillow ile doğrulandı). Eksik dosya yok.
- 14 geçici OGG `native/skin/audio/` içinde.
- `npm test`: 74/74 geçti.

## Bu çalışmada bulunan sorunlar
1. **Görsellerin çoğu hâlâ koda bağlı değil (yalnız button_dark/gold, background, click.ogg bağlandı).** `native/main.gd` içinde yalnızca kart atlasları (`kart-prototipi/gorseller/*.png`) yükleniyor; `native/skin/` hiçbir yerde referans edilmiyor (YENI-GORSEL-2.md de "kod tarafına bağlanmadı" diyor). Görev metnindeki `native/mobile.gd` ve `native/art_slice.gd` depoda yok; tüm arayüz `native/main.gd` (662 satır) ve `native/integration.gd` içinde.
2. ~~Native test çalışmıyor~~ — Godot 4.7.2 indirilerek çözüldü (github.com/godotengine/godot-builds, `GODOT_BIN` ile); test geçiyor. Görsel (ekran görüntüsü) doğrulama hâlâ Mac'te yapılmalı.
2b. ChatGPT denetimi: `icon_net_ok/bad.png` Wi-Fi yerine mücevher gösteriyor, `logo.png` atlas kırpımından büyütülmüş; `background*.png`, `card_back.png` inceleme bekliyor (aşağıdaki tabloya eklendi).
3. Fontlar depoda yok; `bash scripts/skin_v2_fonts.command` çalıştırılmadan font rolleri bağlanamaz.
4. Sesler geçici prosedürel; kulakla/oyun içi miks onayı yok.

## Yapılması gereken kod işleri (öncelik sırasıyla)
- [ ] `main.gd`: (button_gold/dark, input_field, button_red, scrollbar, divider bağlandı) kalan: `panel.png` (kenar değeri manifestte yok, 800x800), `chip_*` (9-slice kenar değerleri `manifest_v2.json` içinde).
- [ ] Arka plan/sahne: `background.png`/`background_land.png`, `table_center.png`, `lane.png`/`lane_enemy.png`, `scene_play/story/friends/chest.png`.
- [ ] Giriş ekranı: `splash.png`, (`logo.png` lobide bağlandı) `logo_wordmark.png`, `loading_bar_frame/fill.png`, `progress_frame/fill.png`.
- [ ] Yatay maç ekranı düzeni (landscape): `background_land.png` + hat düzeni; şu an dikey akış.
- [ ] Paket açılış/sandık animasyonu: `chest_closed → chest_open`, `pack_reveal_burst.png`, `pack_open.ogg`.
- [ ] Hedef halkası kısmen bağlandı (başlıkta simge); asıl hedef birimlerin üstüne halka ve `drag_arrow.png` sürükleme oku (sürükle-bırak yok, yapılmalı).
- [ ] Alt gezinme: `nav_bar.png`, `nav_active.png`; tur butonu `end_turn_ready/wait.png`; ipucu için ``tooltip_panel.png` ve `toast_banner.png` bağlandı (kalan: nav_bar/nav_active; alt gezinme çubuğu henüz yok).
- [ ] Kart çerçeveleri `frame_unit/spell/trap/legend.png`, `gem_*`, `icon_type_*`, `fx_*` efektleri.
- [ ] Oyuncu portreleri: `hero_player.png` + `hero_player_alt1/alt2.png` seçici; düşman `enemy_01..10`; bölüm `chapter_01..10`.
- [ ] Ses: `audio/*.ogg` için `AudioStreamPlayer` bağlantısı (`muted` bayrağı mevcut), müzik döngüsü.
- [ ] `integration.gd` içine skin dosyalarının yüklenebildiğini doğrulayan test ekle.

## Hâlâ eksik görseller
Şu an dosya olarak eksik görsel yok (114/114 mevcut). Aşağıdakiler kalite/kapsam açısından yeni üretim gerektirebilir; ChatGPT bu listeyi okuyup tamamlasın:

| Dosya | Boyut | Kısa prompt |
|---|---|---|
| `icon_net_ok.png` / `icon_net_bad.png` (isteğe bağlı, daha süslü) | 256x256 | Geçici vektör Wi-Fi simgeleri yapıldı; istenirse aynı fikirle boyalı/dokulu sürüm. |
| `hero_player_alt3.png` .. `alt5.png` | `hero_player.png` ile aynı | Aynı çizim stili ve çerçevede, farklı yaş/cinsiyet/kıyafetle Anadolu destan kahramanı portresi, şeffaf arka plan. |
| `loading_tip_panel.png` (isteğe bağlı) | 900x160 | Yüklenme ipucu için ahşap-altın kenarlı koyu parşömen şerit, orta düz, şeffaf dış. |
| `badge_rank_*.png` (isteğe bağlı) | 128x128 | Bronz/gümüş/altın rütbe rozeti, Türk motifli, şeffaf arka plan. |

Not: `manifest_v2.json` içinde "bileşik/vektör" ile tamamlanan dosyalar (bkz. YENI-GORSEL-2.md) bağımsız yapay zekâ çizimi değildir; kalite beğenilmezse yeniden üretilebilir.

## Gerçek ses/müzik (eksik)
Geçici sesler yerine gerçek kayıt gerekir: `music_menu.ogg`, `music_battle.ogg` (96 sn, döngüsel; ney/saz/zurna), efektler `click, card_flip, play_card, attack, hit, spell, heal, pack_open, turn_start, end_turn, victory, defeat`. Prompt: "Anadolu ezgili, ney ve bağlama ağırlıklı, 96 sn kesintisiz döngülü menü müziği; ikinci parça savaş için davul/zurna ile tempolu."
