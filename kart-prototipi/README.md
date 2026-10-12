# Türkiye Serisi — 40 illüstrasyonlu kart (v0.2)

Bu klasör güncel kart tasarımlarını, görsellerini ve basılabilir sayfaları içerir. Her kartın kendi sahnesi vardır; genel kılıç simgesi veya çizim yer tutucusu kullanılmaz.

## Dosyalar

- `index.html`: 40 kartlık galeri; Türkçe arama ve tür filtresi. Depo kökünde HTTP sunucusu çalışırken açılır.
- `Main.html`: kart şablonu ve rehber. `Sayfa1.html`–`Sayfa5.html`: sırayla kart 1–9, 10–18, 19–27, 28–36, 37–40. Bu altı HTML dosyası bağımsızdır; Claude çalışma zamanı gerektirmez, yerel dosya olarak da açılabilir.
- `Main.dc.html`, `Sayfa1.dc.html`–`Sayfa5.dc.html`, `canvas.json`: aynı içeriklerin Claude Design tuvali biçimi. `.dc.html` dosyaları Claude tarafından sağlanan çalışma zamanını kullanır; depoya bir sahte `support.js` eklenmemiştir.
- `Turkiye-Serisi-v0.2.pdf`: 40 kartın beş A4 sayfası ve bir kısa kural/deste sayfası.
- `gorseller/01-04.png`–`gorseller/37-40.png`: proje için yapay zekâ yardımıyla üretilen 40 illüstrasyonu taşıyan 10 atlas. Her atlas 1536×1024, 2×2 yerleşim; her sahne 768×512. Dosyalar orijinal çözünürlükte tutulur.
- `art.js`: hangi kartın hangi atlas hücresini kullandığı, konumu ve Türkçe alternatif açıklaması.

Bir atlasın sırası: sol üst ilk kart, sağ üst ikinci, sol alt üçüncü, sağ alt dördüncü. Örneğin `01-04.png`: Çoban Çırağı, Akıncı Çırağı, Kervan Bekçisi, Ney Üfleyen. Kart resimleri CSS arka plan konumuyla gösterilir; atlas dosyaları fiziksel olarak kesilmez.

## Güncelleme

Kartların tek veri kaynağı `../oyun/cards.js`. Oyun, galeri ve PDF bu kaynağı kullanır. Tuval ve bağımsız kart sayfalarını yeniden üretmek için depo kökünde:

```sh
npm run prototype
npm run docs:cards
npm test
```

`canvas.json` içindeki tuval konumları korunur. Kart kuralını yalnız üretilmiş HTML'de değiştirmeyin; sonraki üretim bunu geri yazar. Yeni bir resim oluşturulduğunda `art.js` eşlemesini ve ilgili atlası birlikte güncelleyin.

## Baskı

A4, %100/gerçek boyut, üstbilgi/altbilgi kapalı, arka plan grafikleri açık. Kartlar 63×88 mm. Fiziksel yazıcıda ilk kartın ölçüsünü kontrol edin. Tek set her karttan bir kopya içerir; aynı başlangıç destesini kullanan iki oyuncu için gerekli kartların kopyalarını tamamlayın.

Tüm sayfaları tek seferde PDF/yazıcıya göndermek için `../oyun/baski.html`. Tarayıcı test ortamında `python3 tests/art-browser.py` galeriyi, resimlerin decode edilmesini ve sayfa taşmalarını kontrol eder, bu klasördeki PDF'i üretir.
