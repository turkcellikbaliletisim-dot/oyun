# Yeni görsel - Destan Diyarları

Bu paket, A bölümündeki 17 arayüz parçasını ve B bölümündeki 2 kahraman portresini içerir. Dosyalar `native/skin/` içindedir. Oyunun çalışan koduna dokunulmamıştır.

## Üretim durumu

**İlk prototip paketidir.** Görseller, tek bir yapay zekâ atlasından ayrıştırılmış ve istenen PNG tuval boyutlarına orantılı olarak uyarlanmıştır; her biri ayrı ayrı bu çözünürlükte üretilmiş değildir. Büyütme yeni çizim ayrıntısı eklemez. Tam ekran ve yakın plan kullanımı için nihai, bağımsız yüksek çözünürlük üretimi ayrı bir kalite adımıdır.

Kaynak atlas: [`yeni-gorsel-kaynak.png`](yeni-gorsel-kaynak.png). Atlas üzerindeki dosya adı etiketleri, oyun varlıklarına dahil edilmemiştir.

## Dosyalar

| Dosya | PNG boyutu | Gerçek alfa |
|---|---:|:---:|
| `background.png` | 1170×2532 | Hayır |
| `background_land.png` | 2532×1170 | Hayır |
| `frame_unit.png` | 512×680 | Evet |
| `frame_spell.png` | 512×680 | Evet |
| `frame_trap.png` | 512×680 | Evet |
| `frame_legend.png` | 512×680 | Evet |
| `card_back.png` | 512×680 | Evet |
| `button_gold.png` | 600×180 | Evet |
| `button_dark.png` | 600×180 | Evet |
| `button_red.png` | 600×180 | Evet |
| `panel.png` | 800×800 | Evet |
| `gem_mana.png` | 256×256 | Evet |
| `gem_attack.png` | 256×256 | Evet |
| `gem_health.png` | 256×256 | Evet |
| `hero_ring.png` | 512×512 | Evet |
| `lane.png` | 1024×400 | Hayır |
| `logo.png` | 1024×512 | Evet |
| `hero_player.png` | 512×512 | Evet |
| `hero_foe.png` | 512×512 | Evet |

## Entegrasyon notları

- Kart çerçevelerinin üst resim pencereleri ve `hero_ring.png` merkezi gerçekten şeffaftır. Panel, buton ve rozetlerin yalnızca dışı şeffaftır; yazı/rakam alanları boyalı kalır.
- Görseller esnetilmemiştir. Şeffaf tuval kenar boşlukları ile çerçeve resim penceresi sınırları `native/skin/manifest.json` içindedir. Bu sınırlar piksel koordinatlarıdır; üst ve sol dahil, alt ve sağ hariçtir.
- Kahraman portreleri bu prototipte kendi çizili dekoratif halkalarını içerir. Ayrı `hero_ring.png` üzerine yeniden halka eklerken bunu dikkate alın.
- Arka planların oyun alanı boştur; kenarlarda dekoratif masa nesneleri bulunur. Bu, nesnesiz arka plan isteğine tam uyan nihai üretim değildir.
- Tuzak çerçevesindeki göz süsü kaynak çizimde açıktır. Briefteki kapalı göz isteği nihai çizimde düzeltilmelidir.
- 40 kart sahnesi, mevcut kartlar, font dosyaları ve oyun kodu değiştirilmemiştir. Font dosyası bu pakete dahil değildir.
- Yüklemeden önce 19 PNG’nin açılabilirliği, tam boyutları ve gereken alfa kanalları kontrol edilmiştir. Oyun içi entegrasyon veya cihaz testi yapılmamıştır.
