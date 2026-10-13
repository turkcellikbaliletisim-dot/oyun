# Tasarım klasörü (skin)

Oyunun görünümü buradan değişir; kod değiştirmen gerekmez.

| Dosya | Ne yapar |
|---|---|
| `skin.json` | Tüm renk rolleri (hex, `#` olmadan). Silinen satır varsayılana döner. |
| `background.png` | İsteğe bağlı tam ekran arka plan (ör. 1170×2532). |
| `font.ttf` / `font.otf` | İsteğe bağlı oyun yazı tipi. |
| `cards/01.png … 40.png` | İsteğe bağlı kart resmi (3:2 yatay, ör. 768×512). Yoksa `kart-prototipi/gorseller` kullanılır. |

Godot klasörü açınca yeni dosyaları kendisi içe aktarır. Dosya adları küçük harf ve tam olarak yukarıdaki gibi olmalı.
