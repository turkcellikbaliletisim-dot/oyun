# Yeni görsel 2 - teslim durumu

## Dosyalar
114 PNG: ikinci listedeki 104 yeni görsel ve ilk paketten yenilenen 4 kart çerçevesi, 3 buton, 3 rozet. Adlar ve boyutlar `skin_v2_expected.json` ile doğrulanır. Yeni görseller `native/skin/` içindedir. 40 kart sahnesi ve oyun kodu değiştirilmedi.

## Üretim yöntemi
Çoğu kaynak tek tek yapay zekâyla üretildi. Son eksikler ve geometrisi düzeltilen arayüzler, üretilmiş malzemelerle özgün vektör/kompozit olarak tamamlandı; bunlar bağımsız yapay zekâ çizimi değildir. Eski atlas kırpımları büyütülmedi. Kompozit tuvalleri hedefin 2 katında işlendi; kaynak detayları büyütülmeden döşendi/küçültüldü. Bu, bütün parçaların bağımsız 2x AI üretim olduğu anlamına gelmez. Dosya bazında yöntem `manifest_v2.json` içindedir.

## Düzeltmeler
- Tuzak ikonunda ve çerçevesinde kapalı göz.
- Alt menüde tam dört yuva; kart parlamalarında tam kapalı dikdörtgen ve şeffaf orta.
- Geniş başlık/giriş/bildirim şeritleri; çerçeve resim pencereleri ve dolum alanı koordinatları manifestte.
- Uygulama ikonu opak ve köşeleri yuvarlatılmamış; adaptif ön plan orta %66 içindedir.
- Logo yazısı gerçek fontla `DESTAN DİYARLARI` olarak dizildi.

## Fontlar
Font dosyaları depoya/pakete dahil değildir. Proje kökünde `bash scripts/skin_v2_fonts.command` çalıştırılınca resmi kaynaklardan kurulur. Font kurulumu ve Türkçe/rakam glyph test raporu `yeni-gorsel-2/font-validation.json` içindedir. Kurulum yapılmadan oyunun fontu değişmez; rol bağlantıları uygulama kodunda ayrıca yapılmalıdır.

## Ses
`native/skin/audio/` içinde 14 OGG/Vorbis dosyası, 44.1 kHz bulunur. Bunlar özgün, katmanlı **geçici prosedürel ses tasarımıdır**. ElevenLabs/Suno/Udio üretimi veya gerçek saz/ney/zurna kaydı olarak sunulmaz. Müzikler 96 saniye ve döngüye uygun kuyruklarla hazırlandı. Kulakla dinleme, oyun içi miks ve nihai müzik onayı yapılmadı.

## Test kapsamı
PNG açılabilirliği, boyut, hash, alfa ve kenar kontrolü; ses formatı/süresi/örnekleme oranı/taşma kontrolü yapılır. `actual-size.png` font ve 32px ikon önizlemesidir; gerçek cihaz/oynanış testi değildir. Görseller kod tarafına henüz bağlanmadı.
