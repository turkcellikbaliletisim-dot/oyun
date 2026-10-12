# Eksik görseller ve yapılacaklar

Son güncelleme: 2026-10-12 20:40 UTC (saatlik otomatik çalışma, dal: `otomatik/saatlik`). Kaynak: GitHub `main` (e336526). Mac'teki ~/Desktop/oyun bu çalışmada erişilebilir değildi.

## Yapılanlar
- 2026-10-12 20:40 UTC: `main` incelendi. "Yeni görsel" ve "Yeni görsel 2" paketleri main'de; `yeni-gorsel-2-20261012` dalı main'den yalnızca 4 CI workflow dosyası kadar fazla, `yeni-gorsel-import-20261012` eski bir alt kümedir (yeni içerik yok).
- `dokumanlar/skin_v2_expected.json` içindeki 114 PNG'nin hepsi `native/skin/` içinde var, boyutları birebir doğru (Pillow ile doğrulandı). Eksik dosya yok.
- 14 geçici OGG `native/skin/audio/` içinde.
- `npm test`: 74/74 geçti.

## Bu çalışmada bulunan sorunlar
1. **Görsellerin hiçbiri oyun koduna bağlı değil.** `native/main.gd` içinde yalnızca kart atlasları (`kart-prototipi/gorseller/*.png`) yükleniyor; `native/skin/` hiçbir yerde referans edilmiyor (YENI-GORSEL-2.md de "kod tarafına bağlanmadı" diyor). Görev metnindeki `native/mobile.gd` ve `native/art_slice.gd` depoda yok; tüm arayüz `native/main.gd` (662 satır) ve `native/integration.gd` içinde.
2. **Native test bu ortamda tamamlanamadı.** Godot 4.4 ile `--editor --import` adım editör ilerleme penceresi hatası verdi (proje 4.7.2 hedefli, sürüm uyumsuzluğu olası); sonraki çalıştırmalar güvenlik denetimi tarafından engellendi. `npm run test:native` Mac'te (Godot 4.7.2) çalıştırılmalı.
3. Fontlar depoda yok; `bash scripts/skin_v2_fonts.command` çalıştırılmadan font rolleri bağlanamaz.
4. Sesler geçici prosedürel; kulakla/oyun içi miks onayı yok.

## Yapılması gereken kod işleri (öncelik sırasıyla)
- [ ] `main.gd`: `Theme`/`StyleBoxTexture` ile `button_gold/dark/red.png`, `panel.png`, `input_field.png`, `chip_*`, `scrollbar.png`, `divider.png` bağla (9-slice kenar değerleri `manifest_v2.json` içinde).
- [ ] Arka plan/sahne: `background.png`/`background_land.png`, `table_center.png`, `lane.png`/`lane_enemy.png`, `scene_play/story/friends/chest.png`.
- [ ] Giriş ekranı: `splash.png`, `logo.png`, `logo_wordmark.png`, `loading_bar_frame/fill.png`, `progress_frame/fill.png`.
- [ ] Yatay maç ekranı düzeni (landscape): `background_land.png` + hat düzeni; şu an dikey akış.
- [ ] Paket açılış/sandık animasyonu: `chest_closed → chest_open`, `pack_reveal_burst.png`, `pack_open.ogg`.
- [ ] Hedef halkası (`target_ring.png`) ve sürükleme oku (`drag_arrow.png`).
- [ ] Alt gezinme: `nav_bar.png`, `nav_active.png`; tur butonu `end_turn_ready/wait.png`; ipucu için `tooltip_panel.png`, bildirim için `toast_banner.png`.
- [ ] Kart çerçeveleri `frame_unit/spell/trap/legend.png`, `gem_*`, `icon_type_*`, `fx_*` efektleri.
- [ ] Oyuncu portreleri: `hero_player.png` + `hero_player_alt1/alt2.png` seçici; düşman `enemy_01..10`; bölüm `chapter_01..10`.
- [ ] Ses: `audio/*.ogg` için `AudioStreamPlayer` bağlantısı (`muted` bayrağı mevcut), müzik döngüsü.
- [ ] `integration.gd` içine skin dosyalarının yüklenebildiğini doğrulayan test ekle.

## Hâlâ eksik görseller
Şu an dosya olarak eksik görsel yok (114/114 mevcut). Aşağıdakiler kalite/kapsam açısından yeni üretim gerektirebilir; ChatGPT bu listeyi okuyup tamamlasın:

| Dosya | Boyut | Kısa prompt |
|---|---|---|
| `hero_player_alt3.png` .. `alt5.png` | `hero_player.png` ile aynı | Aynı çizim stili ve çerçevede, farklı yaş/cinsiyet/kıyafetle Anadolu destan kahramanı portresi, şeffaf arka plan. |
| `loading_tip_panel.png` (isteğe bağlı) | 900x160 | Yüklenme ipucu için ahşap-altın kenarlı koyu parşömen şerit, orta düz, şeffaf dış. |
| `badge_rank_*.png` (isteğe bağlı) | 128x128 | Bronz/gümüş/altın rütbe rozeti, Türk motifli, şeffaf arka plan. |

Not: `manifest_v2.json` içinde "bileşik/vektör" ile tamamlanan dosyalar (bkz. YENI-GORSEL-2.md) bağımsız yapay zekâ çizimi değildir; kalite beğenilmezse yeniden üretilebilir.

## Gerçek ses/müzik (eksik)
Geçici sesler yerine gerçek kayıt gerekir: `music_menu.ogg`, `music_battle.ogg` (96 sn, döngüsel; ney/saz/zurna), efektler `click, card_flip, play_card, attack, hit, spell, heal, pack_open, turn_start, end_turn, victory, defeat`. Prompt: "Anadolu ezgili, ney ve bağlama ağırlıklı, 96 sn kesintisiz döngülü menü müziği; ikinci parça savaş için davul/zurna ile tempolu."
