# Ses ve müzik üretim promptları (Destan Diyarları)

Hedef klasör: `native/skin/audio/` — format OGG/Vorbis, 44,1 kHz. Dosya adları aynen korunmalı, kod bu adlara bağlı.
Atmosfer: Anadolu efsanesi, ney, bağlama, kopuz, davul, zurna, def. Telifli melodi kullanılmayacak; özgün beste.

## Müzik (96 sn, kesintisiz döngü: başı ve sonu aynı seste birleşmeli)

**music_menu.ogg**
> 96 saniyelik, kesintisiz döngülü, sakin ve destansı Anadolu menü müziği. Ney ve bağlama ağırlıklı, hafif def ritmi, uzun pad dokusu. Tempo 70 BPM, hüzünlü ama umutlu. Sözsüz, özgün beste. Sonu başına yumuşakça bağlansın.

**music_battle.ogg**
> 96 saniyelik, kesintisiz döngülü, tempolu Anadolu savaş müziği. Davul, zurna ve bağlama, güçlü ritim, yükselen gerilim. Tempo 110 BPM. Sözsüz, özgün beste. Sonu başına kesintisiz bağlansın.

## Efektler (kısa, temiz, sonunda sessizlik)

| Dosya | Süre | Prompt |
|---|---|---|
| `click.ogg` | 0,1 sn | Hafif ahşap ve metal düğme tıklaması |
| `card_flip.ogg` | 0,3 sn | Kâğıt kartın çevrilmesi, kısa hışırtı |
| `play_card.ogg` | 0,5 sn | Kartın masaya vurulması, tok ahşap tık ve kısa parıltı |
| `attack.ogg` | 0,5 sn | Kılıç savurma ve vuruş, kısa metalik tını |
| `hit.ogg` | 0,4 sn | Darbe alma, tok çarpma sesi |
| `spell.ogg` | 0,9 sn | Büyü, yükselen mistik çınlama ve kısa patlama |
| `heal.ogg` | 0,8 sn | İyileşme, yumuşak yükselen çan ve ışıltı |
| `pack_open.ogg` | 1,5 sn | Sandık kapağı açılır, gıcırtı ve altın parıltısı |
| `turn_start.ogg` | 0,8 sn | Tur başlangıcı, kısa davul vuruşu ve zil |
| `end_turn.ogg` | 0,4 sn | Tur bitirme, tok kapanış tıkı |
| `victory.ogg` | 3 sn | Zafer, zurna ve davul fanfarı, kısa ve görkemli |
| `defeat.ogg` | 3 sn | Yenilgi, alçalan ney ve boğuk davul |

## Teslim kontrolü
- Müzik dosyalarında döngü noktasında tık sesi olmamalı.
- Tüm efektlerde tepe ses -1 dB altında, ses seviyeleri birbirine yakın.
- Üretimden sonra `native/skin/audio/manifest.json` kaynağı ve araç adı ile güncellenir; geçici sentez README'si değiştirilir.
