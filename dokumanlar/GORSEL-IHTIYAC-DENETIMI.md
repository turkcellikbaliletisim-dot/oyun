# Destan Diyarları – Tasarım ihtiyaç denetimi ve yapay zekâ promptları (2. paket)

Oyunun bütün ekranları tek tek incelendi. Önceki pakette (`YENI-GORSEL.md`) gelen 19 görsel kart, buton, rozet, kahraman ve masayı kapsıyor. Bu belge **geri kalan her şeyi** listeler: yazı tipi, ikonlar, arayüz süslemeleri, ekran illüstrasyonları, efekt sprite'ları, uygulama ikonu, ses.

Dosyaları `native/skin/` içine koy (alt klasör belirtilenler hariç). Dosya adları küçük harf, aynen aşağıdaki gibi olmalı; kod bu adları arayacak.

## 0. Ortak kurallar

**STİL BLOĞU** (her prompt'un başına):
```
Hand-painted fantasy card game UI asset in the style of Hearthstone and Legends of Runeterra, rich saturated colors, glossy painterly rendering, ornate details inspired by Turkish/Anatolian art: Seljuk geometric patterns, Iznik tile blue-turquoise-red, Ottoman gold filigree. Dark warm bronze and walnut base with polished gold accents. Consistent lighting from top-left. No text, no letters, no numbers, no watermark.
```
- **Tutarlılık:** İlk beğendiğin çıktıyı sonraki promptlarda stil referansı olarak ver (Midjourney `--sref`, DALL·E/Imagen için referans görsel).
- **Şeffaflık:** "transparent background, isolated on pure #00FF00 chroma green" iste, sonra yeşili sil. Gölge ve parlama kenarlarında yeşil kalıntı bırakma.
- **Yazı yok:** Yapay zekâ Türkçe karakterleri (İ, ı, ş, ğ, ç, ö, ü) güvenilir çizemez. Görsellere yazı koyma; yazıyı oyun kendi yazı tipiyle basar. Tek istisna logo yazısı (bölüm 2).
- **Boyut:** Verilen boyutun en az 2 katında üret, sonra küçült. Küçültme netlik verir, büyütme vermez.
- **Kenar boşluğu:** Şeffaf parçalarda nesne ile tuval kenarı arasında %3-5 boşluk bırak.

---

## 1. Yazı tipi (en acil)

**Sorun (kanıtlı):** Başlıklarda kullanılan *Cinzel Decorative* çok geniş ve süslü harfli. Küçük boyutta kartlarda okunmuyor, "DESTAN DİYARLARI" gibi satırlarda harfler birbirine giriyor. Rakamları **eski stil (Roman)**: kart maliyeti 1, **"I"** görünüyor, 2-3 de karışık. Oyuncu mana ve can sayılarını yanlış okur. Gövde yazısı (*Alegreya*) kitap yazısı gibi, mobilde ince kalıyor.

Yapay zekâ yazı tipi üretemez. Aşağıdakilerden birini indir (hepsi ücretsiz ve **Türkçe karakterleri tam destekler**; indirdikten sonra `ı İ ş Ş ğ Ğ ç Ç ö Ö ü Ü` yazıp test et).

| Rol | Dosya | Öneri (Google Fonts, OFL) | Neden |
|---|---|---|---|
| Başlık, buton | `font_title.ttf` | **Cinzel** (Bold) veya **Marcellus SC** | Süssüz, okunaklı, hâlâ destansı |
| Gövde | `font.ttf` | **Nunito Sans** (SemiBold) veya **Source Sans 3** | Küçük boyutta net, mobilde dolgun |
| Sayılar (maliyet, saldırı, can) | `font_numbers.ttf` | **Lilita One** veya **Alfa Slab One** | Kalın, düz rakamlar, rozet içinde güçlü durur |
| Kart adı (küçük) | `font_card.ttf` | **Cinzel** SemiBold veya **Philosopher** Bold | 8-12 px'te okunur |

Kısa liste: Cinzel + Nunito Sans + Lilita One. Üçü birlikte Hearthstone benzeri bir his verir.

---

## 2. Marka ve uygulama

| Dosya | Boyut | Prompt (stil bloğundan sonra) |
|---|---|---|
| `logo_wordmark.png` | 1600×400 şeffaf | Game logo lettering that reads "DESTAN DİYARLARI" in carved gold metal capital letters with turquoise tile inlay, a crescent and star emblem above, soft glow. **Kontrol et:** noktalı "İ" doğru mu, harfler tam mı. Yanlışsa en az 8 kez dene ya da yazıyı font ile bas. |
| `app_icon.png` | 1024×1024 opak, köşe yuvarlama yok | App icon: a golden crescent and eight-pointed Seljuk star over a crossed sword and quill, deep teal and burgundy background with Iznik pattern frame, centered, high contrast, readable at 48 px |
| `app_icon_foreground.png` | 1024×1024 şeffaf | Same emblem alone on transparent background, centered in the middle 66% (Android adaptive icon safe zone) |
| `splash.png` | 1242×2688 | Vertical splash art: a lone hero silhouette on a hill at dusk facing a giant glowing red apple (Kızılelma) between minarets and mountains, painterly, empty lower third for a loading bar |
| `loading_bar_frame.png` | 800×80 şeffaf | Ornate horizontal progress bar frame, gold with turquoise end caps, empty inside |
| `loading_bar_fill.png` | 800×64 | Glowing amber liquid-gold fill texture, horizontal gradient, seamless horizontally |

---

## 3. İkonlar (hepsi 256×256 şeffaf, aynı stil ve ışık)

Şu an ikonlar düz çizgi SVG ve Unicode karakterleri (✓ ◆ ◇ ‹ ›). Bunlar oyunun diğer görselleriyle uyumsuz. Hepsini aynı sette yenile.

Ortak ek prompt: "single icon, centered, thick gold-bronze beveled metal rim around an enamel or gem core, game UI icon style, isolated on green".

| Dosya | Nerede kullanılıyor | İçerik |
|---|---|---|
| `icon_play.png` | Alt menü "Oyna" | crossed swords over a shield |
| `icon_story.png` | Alt menü "Yolculuk" | open ancient scroll map with a winding road |
| `icon_cards.png` | Alt menü "Kartlar" | fanned three cards with gold edge |
| `icon_deck.png` | Alt menü "Destem" | stacked card deck with a wax seal |
| `icon_settings.png` | Sağ üst ayarlar | ornate gear with a Seljuk star center |
| `icon_sound_on.png` / `icon_sound_off.png` | Ses düğmesi | war horn with sound waves / same horn with a cross |
| `icon_back.png` | Maçtan çıkış "‹" | gold arrow pointing left in a round plate |
| `icon_close.png` | Pencere kapatma | gold X in a round plate |
| `icon_check.png` | Tamamlandı, seçili kart | green gem checkmark in gold ring |
| `icon_lock.png` | Kilitli bölüm | iron padlock with gold trim |
| `icon_gold.png` | Altın yazısı yanı | stack of three ornate gold coins with crescent stamp |
| `icon_dust.png` | Toz yazısı yanı | small pile of glittering blue-violet magic dust in a pouch |
| `icon_energy_full.png` / `icon_energy_empty.png` | Enerji kristalleri (şimdi ◆ ◇) | glowing blue crystal / same crystal dark and hollow |
| `icon_turn.png` | Tur sayacı | bronze hourglass with gold sand |
| `icon_deck_count.png` | Deste sayısı | tiny card stack |
| `icon_rarity_common.png` / `_rare` / `_legendary` | Kart nadirliği | bronze gem / blue sapphire gem / radiant gold crowned gem |
| `icon_type_warrior.png` / `_spell` / `_trap` | Kart türü | sword / swirling blue flame / closed iron eye with chains |
| `icon_league.png` | Lig / rütbe | laurel wreath with star |
| `icon_net_ok.png` / `icon_net_bad.png` | Bağlantı durumu (şimdi "ON" yazısı) | green gem / red gem in small bronze ring |
| `icon_surrender.png` | Teslim ol | white flag on a spear |
| `icon_replay.png` | Maç kaydı | scroll with a circular arrow |

---

## 4. Ekran bazlı arayüz parçaları

Önceki pakette gelen çerçeve, buton, panel, rozet ve masa dışında eksik olanlar:

| Dosya | Boyut | Nerede | Prompt |
|---|---|---|---|
| `header_bar.png` | 1170×160 şeffaf | Üst başlık şeridi | Slim ornate top bar, dark walnut with a gold lower edge line and a small Seljuk star in the center notch, left and right ends open, seamless horizontally in the middle |
| `nav_bar.png` | 1170×200 şeffaf | Alt menü zemini | Bottom navigation bar base, dark leather with gold top rail and four recessed round sockets evenly spaced, seamless |
| `nav_active.png` | 256×256 şeffaf | Seçili sekme vurgusu | Glowing gold halo ring behind an icon, soft light, transparent center |
| `chip_gold.png` / `chip_dust.png` | 400×120 şeffaf | Altın ve toz sayacı | Small pill-shaped plate, gold-bronze rim with amber / violet glass inside, left end has an empty circular socket for an icon |
| `chip_filter.png` / `chip_filter_active.png` | 300×100 şeffaf | Tümü, Savaşçı, Büyü, Tuzak filtreleri | Small rounded rectangle plate, dark bronze (inactive) / glowing gold (active), tiny corner studs |
| `badge_count.png` | 128×128 şeffaf | Koleksiyonda "×2" sayacı | Small round dark-steel badge with gold rim, empty center |
| `badge_new.png` | 256×128 şeffaf | Yeni kart etiketi | Small gold ribbon tag, empty center |
| `toast_banner.png` | 1200×260 şeffaf | "SENİN TURUN", "RAKİBİN TURU" bildirimi | Wide ceremonial banner scroll with gold-fringed ends and a central empty cartouche, glowing edges, transparent background |
| `result_victory.png` | 1200×700 şeffaf | Zafer penceresi üstü | Triumphant golden laurel and crossed swords crest with rays of light and turquoise tiles, empty center |
| `result_defeat.png` | 1200×700 şeffaf | Yenilgi penceresi üstü | Cracked iron crest with a broken sword and dim ember glow, muted purple-grey, empty center |
| `input_field.png` | 800×120 şeffaf | Oda kodu girişi | Recessed dark leather text field with a thin gold inner border, empty |
| `progress_frame.png` / `progress_fill.png` | 800×40 | Yolculuk ilerleme çubuğu | Ornate thin bar frame with end studs / glowing gold fill |
| `scrollbar.png` | 64×400 şeffaf | Kaydırma çubuğu | Slim vertical bronze rail with a gold thumb |
| `divider.png` | 1000×60 şeffaf | Bölüm ayırıcı | Thin gold line with a small central Seljuk star and fading ends |
| `tooltip_panel.png` | 600×300 şeffaf | Kart detay penceresi | Small parchment-and-leather note panel with gold corners, empty center |
| `drag_arrow.png` | 256×256 şeffaf | Sürükle-bırak hedef oku | Glowing golden arrowhead pointing up, light trail |
| `target_ring.png` | 256×256 şeffaf | Hedef seçilebilir birim/kahraman | Pulsing green-gold targeting reticle ring with four notches, transparent center |
| `end_turn_ready.png` / `end_turn_wait.png` | 700×260 şeffaf | "Turu bitir" büyük düğme (hazır / bekliyor) | Large jeweled ornamental button plate, glowing amber (ready) / dim iron (waiting), empty center |
| `lane_enemy.png` | 1024×400 | Rakip şeridi | Same stone slab as `lane.png` but with dark red runes and ember cracks |
| `table_center.png` | 1024×1024 şeffaf | Masa ortası süsü | Inlaid Seljuk 8-pointed star medallion carved in the table, subtle gold, transparent outside |

---

## 5. İllüstrasyon ve sahneler (içinde yazı yok)

| Dosya | Boyut | Prompt |
|---|---|---|
| `backdrop.png` | 1170×2532 | App shell background, dark teal-black stone wall with faint Iznik tile pattern and distant mountain silhouette at the top, vignette, very low contrast so UI stays readable (şu an düz SVG) |
| `scene_play.png` | 1200×800 | Hero scene: a warrior and a wolf at sunrise facing the sky with a glowing red apple, sweeping sky (lobby "Efsaneni yaz" kartı) |
| `scene_story.png` | 1200×800 | Anatolian road at dusk, caravan, castle, light beams (lobby "Anadolu Yolculuğu") |
| `scene_chest.png` | 1200×800 | Ancient ornate treasure chest, lid cracked open with golden light spilling out, cave setting (kart sandığı) |
| `scene_friends.png` | 1200×800 | Two warriors toasting across a lantern-lit table, warm light (arkadaşla düello) |
| `chest_closed.png` / `chest_open.png` | 512×512 şeffaf | Same chest, closed with golden lock / open with rays and floating cards |
| `chapter_01.png … chapter_10.png` | 1200×600 | 10 bölüm kapak resmi, her biri farklı mekân (`native/data.json` ile aynı): 01 Kervansaray Kapısı (Anadolu yolu, kervan), 02 Mağaranın Sesi (Kapadokya peri bacaları ve mağaralar), 03 Perde Açılıyor (Karagöz-Hacivat gölge tiyatrosu), 04 Pazarın Kalbi (Kapalıçarşı), 05 Bozkırın Çağrısı (Orta Asya bozkırı, atlı), 06 Hoca’nın Kuyusu (Akşehir, Nasreddin Hoca ve kuyu), 07 Şahmaran’ın Sırrı (Toros Dağları, Şahmaran), 08 Kar Fırtınası (Erzurum karlı dağlar), 09 Tepegöz’ün Mağarası (Dede Korkut destanı, dev), 10 Ergenekon (demir dağ, eriyen kapı) |
| `enemy_01.png … enemy_10.png` | 512×512 şeffaf | Bölüm rakibi portreleri (hero_foe.png gibi, kendi halkasıyla). Rakipler: Gölge Çırak, Mağara Gölgesi, Perde Gölgesi, Unutuş Tüccarı, Gölge Akıncı, Hileci Gölge, Yılan Gölgesi, Buz Elçisi, Tepegöz Gölgesi, Unutuş’un Elçisi. Şu an hepsi aynı iki portreyi paylaşıyor |
| `hero_player_alt1.png`, `_alt2.png` | 512×512 şeffaf | Oyuncu için 2 ek kahraman: a female archer, an old wise dervish. `hero_player.png` ile aynı çizim ve halka stili |
| `pack_reveal_burst.png` | 1024×1024 şeffaf | Burst of golden light rays and sparks radiating from the center, transparent background (sandık açılışı) |
| `empty_collection.png` | 600×400 şeffaf | Empty open book with a single glowing page and a small dust cloud (kart yokken boş durum) |
| `offline.png` | 800×600 şeffaf | Sleeping lantern in a dark cave with a broken chain, sad tone (bağlantı yok) |

---

## 6. Efekt sprite'ları (şimdi kodla çizilen parçacıklar ve düz yazılar)

Hepsi 256×256 şeffaf, siyah arka planlı değil. Oyun bunları parçacık dokusu ve animasyon karesi olarak kullanacak.

| Dosya | Prompt |
|---|---|
| `fx_hit.png` | Impact burst with red-orange shards and white core, comic-style hit flash |
| `fx_slash.png` | White-gold diagonal sword slash arc with motion blur |
| `fx_heal.png` | Green-gold healing sparkles rising, soft glow, plus-shaped glints |
| `fx_fire.png` | Stylized fire burst, painterly |
| `fx_frost.png` | Blue ice crystals bursting outward (Kar Fırtınası) |
| `fx_flood.png` | Stylised water wave splash, turquoise foam (Tufan) |
| `fx_shield.png` | Golden hexagonal-tile shield dome flash |
| `fx_summon.png` | Swirling turquoise ring with rising sparks (birim oynama) |
| `fx_death.png` | Dark smoke puff with fading ember sparks |
| `fx_spark.png` | Single soft round golden spark, for particles (64×64) |
| `fx_dust.png` | Single soft round warm dust mote, for ambient particles (64×64) |
| `fx_glow_ready.png` | Soft green-gold rounded-rectangle glow, hollow center (oynanabilir kart parlaması) |
| `fx_glow_legend.png` | Soft golden-white rounded-rectangle glow, hollow center (efsanevi kart) |
| `fx_number_bg.png` | Small dark splat shape behind floating damage numbers |

---

## 7. Ses (yazı tipi gibi bu da şu an eksik)

Oyundaki sesler kodla üretilen basit bip sesleri. Görsel kalite yükselince ses geri kalıyor. Yapay zekâ ses/müzik araçlarıyla (ElevenLabs Sound Effects, Suno, Udio) şu dosyaları üret, `native/skin/audio/` içine koy (OGG, 44.1 kHz).

| Dosya | Süre | Prompt |
|---|---|---|
| `click.ogg` | 0.1 sn | Soft wooden-metal UI tap, short |
| `play_card.ogg` | 0.5 | Heavy card slapped on a wooden table with a low whoosh |
| `attack.ogg` | 0.6 | Sword swing and clash, dry, punchy |
| `hit.ogg` | 0.4 | Armored impact thud |
| `heal.ogg` | 0.8 | Soft magical chime rising, warm |
| `spell.ogg` | 0.9 | Mystical whoosh with a ney flute accent |
| `turn_start.ogg` | 1.2 | Short ceremonial drum hit and brass fanfare, Mehter flavor |
| `end_turn.ogg` | 0.4 | Low gong |
| `victory.ogg` | 3 | Triumphant orchestral fanfare with davul and zurna |
| `defeat.ogg` | 3 | Somber low strings and a lone ney |
| `pack_open.ogg` | 2.5 | Chest creak, magical shimmer, sparkle burst |
| `card_flip.ogg` | 0.3 | Paper card flip |
| `music_menu.ogg` | 90-120 loop | Calm Anatolian ambient: saz, ney, soft drone, loopable |
| `music_battle.ogg` | 90-120 loop | Tense epic percussion with davul, kemençe, rising pulse, loopable |

---

## 8. Öncelik sırası

1. **Yazı tipi** ve rakamlar (kart üstündeki 1 → I hatası, okunabilirlik).
2. **İkonlar** (bölüm 3): alt menü, ayar, ses, enerji, nadirlik ve türler.
3. **Arayüz parçaları** (bölüm 4): chip, filtre, toast, sonuç, end_turn butonu, header, nav.
4. **Efektler** (bölüm 6): maç hissini en çok bunlar yükseltir.
5. **Sahneler** (bölüm 5): lobi, bölüm kapakları, sandık.
6. **Marka** (bölüm 2) ve **ses** (bölüm 7).

## 9. Bilinen kısıtlar (önceki pakettekilere ek)

- Mevcut `frame_*`, `button_*` ve `gem_*` görselleri tek atlastan kırpıldı. Büyük ekranda bulanıklık görülebilir; ikinci pakette bunları bağımsız ve yüksek çözünürlükte yenilemen iyi olur.
- Tuzak çerçevesindeki göz açık; kapalı olarak yenilenmeli.
- Her görseli oyun içinde **gerçek boyutunda** kontrol et (kart adı ~10 px, rozet ~30 px). Büyük görselde güzel duran süs küçükte karışabilir.
