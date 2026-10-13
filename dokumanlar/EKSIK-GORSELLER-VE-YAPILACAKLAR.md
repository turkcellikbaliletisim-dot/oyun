# Eksik görseller ve yapılacaklar

Son güncelleme: 2026-10-13 07:55 UTC — dal: `claude/mobil-arayuz-skin-v2` (arayüz `native/mobile.gd` + `native/skin_chrome.gd` + `native/art_slice.gd`). Eski `otomatik/saatlik` dalındaki tek dosyalı `main.gd` çalışması esas alınmadı; yalnızca düzeltilmiş PNG'ler (`icon_net_ok/bad.png`, `logo.png`) taşındı.

## Yapılanlar
- 2026-10-13 07:55 UTC: Yeni ChatGPT yüklemesi yok (main e336526; tüm gorsel-kalite dalları zaten birleşik). Kart plakasına `icon_type_spell/trap` ve `icon_rarity_*` simgeleri, maç ekranına `icon_turn` (tur sayacı) ve `icon_deck_count` (deste sayısı), efektlere `fx_dust` (birim çağırma) ve `fx_spark` (kahraman iyileşme) bağlandı. `npm test` 78/78, `test:native` GEÇTİ (Godot 4.7.2, xvfb), koleksiyon ekran görüntüsü gözle kontrol edildi.
- 2026-10-13 06:55 UTC: Enerji kristalleri `icon_energy_full/empty.png` ile (eski soluk gem_mana kaldırıldı), ses düğmesine `icon_sound_on/off.png`, "Teslim ol" düğmesine `icon_surrender.png`, boş koleksiyon filtresinde `empty_collection.png` bağlandı. Yeni ChatGPT yüklemesi yoktu (main'de yeni commit yok). `npm test` 78/78, `test:native` GEÇTİ, ekran görüntüleri gözle kontrol edildi.
- 2026-10-13: ChatGPT dalları birleştirildi: `gorsel-kalite/mobil-skin-baglantilari` (skin_chrome.gd: arka plan, ağ rozeti, 4 soketli alt gezinme), `gorsel-ihtiyac-denetimi`, `gorsel-kalite/denetim`. Wi-Fi simgeleri ve `logo.png` yeniden üretilmiş sürümle değiştirildi (ekranda doğrulandı).
- Yatay maç düzeni yeniden yazıldı: solda kahramanlar + deste + tur sayacı, ortada iki şerit (`lane_enemy/lane.png`) ve el, sağda "Turu bitir" + enerji. Kartlar ~40 → ~60 px, düğme artık şeride binmiyor. Dikeyde "Turu bitir" kahramanın sağına alındı. Rakip turunda `end_turn_wait.png`.
- Ana ekran: başlıkta `logo_wordmark.png`; alt yarı için "Sandık" ve "Düello" kutuları (`scene_chest/friends.png`, tüm kutu dokunulabilir); yolculuk ilerlemesi `progress_frame/fill.png`.
- `divider.png` (yolculuk/koleksiyon/arkadaş başlıkları), `input_field.png` (LineEdit, yarı ölçekli 9 parça), `scrollbar.png`, `tooltip_panel.png` tema olarak bağlandı.
- Hedef halkası (`target_ring.png`, hedeflenebilir kahramanda nabız animasyonu) ve sürükleme oku (`drag_arrow.png`) bağlandı.
- Paket açılışı: `show_pack_reveal()` — `chest_closed` sallanır → `chest_open` + `pack_reveal_burst`, dokununca kapanır.
- Hesap ekranında kahraman seçici (`hero_player`, `alt1`, `alt2`, seçili olana `hero_ring.png`); seçim oturum dosyasında saklanır, maçta oyuncu portresi buna göre.
- `.import` dosyaları `.gitignore`'a eklendi. `tests/shots.gd` hesap/sandık ekranlarıyla genişletildi.
- Testler: `npm test` 78/78; `npm run test:native` (Godot 4.7.2 linux, xvfb) GEÇTİ. Çıkıştaki "resources still in use" uyarısı zararsız sayıldı (run-native.js bunu hata saymıyor; integration.gd önbellekleri temizliyor).

## Hâlâ eksik / yapılacak (kod)
- [ ] `loading_bar_frame/fill.png`, `splash` giriş/yükleme ekranı akışı (proje splash'ı hariç uygulama içi yükleme ekranı yok).
- [ ] `header_bar.png`, `table_center.png` bağlı değil.
- [ ] Kalan küçük simgeler bağlı değil: `icon_check/close/lock/replay/league`, `fx_fire/flood/frost/shield/number_bg` (büyü efektleri kart bazlı eşlenmedi), `gem_*` (eski), `icon_cards/deck/play/story` (alt gezinme soketlerinde kullanılmıyor olabilir, denetle).
- [ ] Hedef halkası birim kartlarında yok (yalnızca kahraman); kartta dikdörtgen vurgu kullanılıyor.
- [ ] `hero_player_alt3..5` ve hero_ring maç içi çerçeve olarak kullanılmıyor.
- [ ] Gerçek ses/müzik (aşağıda).
- [ ] `tests/native-interaction.gd` bazen (nadiren) "freed instance" ile düşüyor; yeniden çalışınca geçiyor — zamanlama kaynaklı, incelenmeli.
- [ ] Gerçek cihaz/Mac'te görsel kabul; Linux llvmpipe ekran görüntüleri gözle kontrol edildi.

## Sorunlar
- Yatay maç düzeninde seçili kart bilgi paneli (sağ sütun) uzun efekt metninde dar kalabilir.
- `lane*.png` 9 parçalı çizimde kenarlar hafif dikdörtgen görünüyor (alfa 0.7 ile yumuşatıldı); şeffaf kenarlı yeni sürüm iyi olur.

## Hâlâ eksik görseller (ChatGPT için)
Dosya olarak eksik yok (114/114 mevcut). İsteğe bağlı yeni üretimler:

| Dosya | Boyut | Kısa prompt |
|---|---|---|
| `hero_player_alt3.png` .. `alt5.png` | 512x512 | `hero_player.png` ile aynı stil ve altın çerçeve; farklı yaş/cinsiyet/kıyafetle Anadolu destan kahramanı portresi, şeffaf arka plan. |
| `lane.png` / `lane_enemy.png` (yenileme) | 1024x400 | Aynı ahşap-altın şerit, ama dış kenarı şeffaf ve köşeleri yuvarlak; ortası sade, kart okunabilirliği için koyu-mat. |
| `loading_tip_panel.png` | 900x160 | Koyu parşömen şerit, ahşap-altın kenar, ortası düz, şeffaf dış. |
| `badge_rank_bronze/silver/gold.png` | 128x128 | Türk motifli rütbe rozeti, şeffaf arka plan. |

## Gerçek ses/müzik (eksik)
Geçici sesler yerine gerçek kayıt: `music_menu.ogg`, `music_battle.ogg` (96 sn, döngüsel; ney/saz/zurna), efektler `click, card_flip, play_card, attack, hit, spell, heal, pack_open, turn_start, end_turn, victory, defeat`. Prompt: "Anadolu ezgili, ney ve bağlama ağırlıklı, 96 sn kesintisiz döngülü menü müziği; ikinci parça savaş için davul/zurna ile tempolu."
