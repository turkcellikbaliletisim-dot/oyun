# 11 — Sanat, ses ve erişilebilirlik yönergesi

## Mevcut prototip

Koyu yeşil oyun sahası, kâğıt kart yüzeyi, altın vurgu; tür ve nadirlik adları yazılıdır. SAL/CAN değerleri simge ve metinle gösterilir; yalnız renge bağlı değildir. Kart hedefleri çerçeveyle, hazır savaşçılar durum metniyle belirtilir. Klavye odak halkası, Türkçe aria etiketleri, durum mesajı ve hareket azaltma CSS desteği vardır. Yerel prosedürel ses ve başlangıç müziği ayrı ayrı isteğe bağlı, varsayılan kapalıdır. Ses düzeyi ayarlanır; menüye dönme veya sekmeyi gizleme sesi durdurur. Hazır üçüncü taraf ses kaydı kullanılmaz.

Bunlar tam erişilebilirlik sertifikasyonu değildir. Gerçek ekran okuyucu, dokunma, düşük görme ve farklı cihaz kullanıcılarıyla doğrulama gerekir.

## Tamamlanan kart görselleri

40 ayrı illüstrasyon üretildi; 10 adet 2×2 atlas `kart-prototipi/gorseller/` içinde, kart eşlemesi ve Türkçe alternatif metinler `kart-prototipi/art.js` içinde. Aynı görseller oyun, galeri, güncel Claude Design tuvali ve baskıda kullanılır. Yer tutucu kılıç simgeleri kaldırıldı. Görseller yapay zekâ yardımıyla üretildi.

## Görsel üretim yönergesi

- Ton: sıcak, destansı, masalsı; korku veya gerçekçi vahşet ilk hedef değil.
- Tema: anlatı karakterleri, Anadolu coğrafyası ve el işi dokuları. Tarihî öğeleri basit dekor yerine kültürel araştırmayla ele al.
- Kartta öncelik sırası: isim/enerji → tür/anahtar → etki → saldırı/can. Çizim metni bastırmamalı.
- Nadirlik çerçeveyle birlikte metin/ikon taşımalı; renk körlüğünde kart türü anlaşılmalı.
- 40 kart için ayrı özgün illüstrasyon ve katmanlı kaynak; küçük ekranda siluet okunmalı. Başlangıç siparişi: Çoban Çırağı, Kervan Bekçisi, Bozkır Okçusu, Zeybek, Tulpar, Mağara Bekçisi, Fırtına Bulutu, Tuzak Kuyu, Şahmaran, Dede Korkut.
- Sanat tesliminde kaynak dosya, kullanım hakları, atıf gerekleri, revizyon hakkı ve varsa kullanılan dış kaynak kayıtları bulunmalı.
- `kart-prototipi` tuvali v0.2 ile güncellendi. Güncel resimler ve baskı tek kart/görsel kaynağından üretilir. Yeni kartlarda aynı görsel dil ve resim eşleme düzeni korunur.

## UI ve cihaz kabul koşulları

- Ana etkileşimlerde hedef dokunma alanı en az 44 CSS px; sıkışık savaşçı alanlarında tüm kart düğme olduğu için hedef alanı korunmalı.
- Küçük ekranda el yatay kayar; tüm sayfa yatay taşmaz. Kritik etki metni büyütülerek okunabilir. Koleksiyon ekranındaki kart adına dokununca büyük metinli kart ayrıntı penceresi açılır.
- Geçersiz enerji/hedef metinle açıklanır; yalnız kırmızı yanıp sönmeye dayanılmaz.
- Hareket azaltma ve sessiz oyun desteklenir. Maç sonucunu anlamak için ses zorunlu değil.
- Metin büyütme, 200% yakınlaştırma, klavye sırası, diyalog odak yönetimi ve gerçek ekran okuyucu duyuruları ayrıca test edilir.

## Ses listesi ve haklar

Kart oynama; saldırı; hasar; ölüm; tuzak açılması; çekiş; tur geçişi; zafer/yenilgi; bölüm açılması. Her biri ayrı kısa geri bildirim olabilir. Bir menü ve bir maç müziği yeterli başlangıç kapsamıdır. Ses/müzik içerikleri lisans belgesiyle alınır; oynanışı doğrulamadan büyük ses paketi sipariş edilmez. Bildirim sesleri varsayılan sessiz saat politikasına uyar.

## Font ve dil

Uygulama sistem fontu ve Georgia kullanır; dış font indirme zorunluluğu yok. Özel font eklenecekse lisans ve dağıtım hakları doğrulanıp yerel paketlenir. İlk dil Türkçe. Yeni dillerde UI metinleri anahtar dosyasına çıkarılır; değişken uzunluk, çoğul, kart metni ve Türkçe karakterler test edilir.

## Kart inceleme ve klavye iyileştirmeleri

Sahadaki ve eldeki her kartın ayrı **İncele** düğmesi var; kart oynanamaz durumda olsa da ayrıntıları açılır. Açılan pencerede illüstrasyon, tam kural ve sahadaki güncel SAL/CAN görülür. Hedef seçimi klavyeyle hedefe odaklanır; seçili başlangıç kartları aria-pressed ile belirtilir. İçeriğe geç bağlantısı ve sıra/sonuç duyuruları eklendi. 195 CSS px dar görünümde bütün sayfa yatay taşmaz; beşli saha kendi içinde kayabilir. Gerçek ekran okuyucu ve fiziksel cihaz kullanıcı testi ayrı kapıdır.

## Tamamlanan başlangıç ses/müziği

`oyun/sound.js`: kart, saldırı, tur ve sonuç için kısa farklı tonlar; üçgen/sinüs dalgalarıyla üretilen özgün sekiz notalı sakin döngü. Kayıtlı geleneksel enstrüman veya lisanslı dış müzik kullanmaz. Profesyonel ses miksajı ve gerçek cihaz dinleme testi sonraki üretim kontrolüdür.
