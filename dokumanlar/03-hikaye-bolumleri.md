# 03 — Anadolu hikâyesi: 10 oynanabilir bölüm

Bölümlerin diyalogları, hazır desteleri, rakipleri ve görev doğrulamaları `oyun/chapters.js` içindedir. Oyunun giriş ekranında Hikâye modu seçilir. Bir bölümü geçmek için **hem maçı kazanmak hem görevi yerine getirmek** gerekir. Sonraki bölüm o zaman açılır. Yenilgi veya eksik görev sonrası tekrar deneme serbesttir. İlerleme bu tarayıcıda saklanır; hesap ve bulut eşitleme yoktur.

| # | Bölüm / yer | Rakip | Maç içi görev | Oyuncu destesi |
|---|---|---|---|---|
| 1 | Kervansaray Kapısı / Anadolu yolu | Gölge Çırak | Savaşçı oyna, saldırı yap, kazan | Başlangıç |
| 2 | Mağaranın Sesi / Kapadokya | Mağara Gölgesi | Koruyucu oyna ve kazan | Başlangıç |
| 3 | Perde Açılıyor / Karagöz-Hacivat perdesi | Perde Gölgesi | Büyü oyna ve kazan | Başlangıç |
| 4 | Pazarın Kalbi / Kapalıçarşı | Unutuş Tüccarı | Pazar Pazarlığı oyna ve kazan | Başlangıç; Kılıç Bileme yerine Pazar Pazarlığı |
| 5 | Bozkırın Çağrısı / Orta Asya bozkırı | Gölge Akıncı | Hızlı savaşçı oyna ve kazan | Bozkır Akıncıları |
| 6 | Hoca’nın Kuyusu / Akşehir | Hileci Gölge | Tuzak Kuyu kur ve kazan | Başlangıç; Kılıç Bileme yerine Tuzak Kuyu |
| 7 | Şahmaran’ın Sırrı / Toros | Yılan Gölgesi | Şahmaran Yavrusu oyna ve kazan | Başlangıç; Yeniçeri yerine Şahmaran |
| 8 | Kar Fırtınası / Erzurum | Buz Elçisi | Kar Fırtınası oyna ve kazan | Başlangıç; Kılıç Bileme yerine Kar Fırtınası |
| 9 | Tepegöz’ün Mağarası | Tepegöz Gölgesi | Tepegöz oyna ve kazan | Bozkır; Karagöz yerine Tepegöz |
| 10 | Ergenekon / Demir dağ | Unutuş’un Elçisi | Savaşçı, büyü ve tuzak oyna; kazan | Kadim Muhafızlar |

## Öğretim ve tekrar oynama

- Bölüm 1'de bot saldırmaz ve kart oynamaz: oyuncu enerji, saha, saldırı ve tur bitirmeyi baskısız öğrenir. Bu senaryolu eğitimdir; gerçek rakibin gücünü temsil etmez. Kazanmayı garanti etmek yerine hata düzeltme ve yeniden deneme sunulur.
- Sonraki bölümlerde açık saha ve kendi elinden karar veren bot aktiftir. Bot rakibin gizli eline bakmaz.
- Diyalog, görev ve sonucun nedeni maç ekranında görünür. Ana menüde nasıl oynanır penceresi vardır.
- Eğitim yardımcı ekranı hikâye içeriğinden bağımsızdır. Şimdiki görevler mekanik kullanmayı ölçer; doğru strateji veya tam ustalık ölçmez.
- Bölüm ödülleri yerel koleksiyona bir kez verilir. Serbest denemede tüm kartlar açıktır; koleksiyonla oynama seçeneği sahipliği kontrol eder. Hikâye desteleri ödünçtür; eksik kart öğretimi engellemez. Koleksiyon işlemleri gerçek paraya veya güvenli sunucu hesabına bağlı değildir.

## Uygulanan yerel bölüm ödülleri

Başlangıç destesinin 20 kartı bölüm 1 maçından **önce** verilir; böylece ödül için önce desteye ihtiyaç duyma döngüsü yoktur. Bölüm 1 bitince aynı deste ikinci kez verilmez.

| Bölüm | İlk tamamlama ödülü |
|---|---|
| 1 | 100 altın |
| 2 | Mağara Bekçisi ×1 |
| 3 | Karagöz ×1 |
| 4 | Pazar Pazarlığı ×1 |
| 5 | Bozkır Okçusu ×1, Sipahi ×1 |
| 6 | Tuzak Kuyu ×1 |
| 7 | Şahmaran Yavrusu ×1 |
| 8 | Kar Fırtınası ×1 |
| 9 | Tepegöz ×1 |
| 10 | Ergenekon Demircisi ×1, Anadolu Mühür Parçası, Arşiv Seçimi |

Arşiv Seçimi: koleksiyonda bulunmayan 7 farklı kartı seçip birer kopya almak. Başlangıçta 10 farklı kart, bölüm ödülleriyle 18 farklı kart ve final arşiviyle en az 25 farklı kart olur; paketler bu tabana eklenir. Yerel prototip eksik kart seçimini doğrular; toplam eksik kart 7’den azsa yalnız kalan sayı kadar seçim verir. Online sürümde doğrulama sunucuya taşınmalıdır. Tekrar oynama ilk tamamlama ödülünü tekrarlamaz; günlük maç ödülleri normal sınırlarıyla uygulanır.

Online lig için tek açılış koşulu **bölüm 10 + çevrimiçi yayın sürümü**. Takas ilk sürüm kapsamından çıkarılmıştır; gün veya bölüm tamamlamak takası açmaz. Başka diyar seçimi gelecek sezonlara bırakılmıştır.

## İnsan testi kabul ölçütleri

Bölüm 1–3'ün ilk oturumda tamamlanması, oyuncunun Koruyucu ve saldırı fazını açıklayabilmesi ve hedef seçimini dış yardım almadan yapması izlenir. 3–6 dakikalık bölüm hedefi henüz doğrulanmamıştır. Görev kartının çekilmemesi yüzünden tekrar denemeye zorlanma oranı ölçülmelidir; gerekirse gelecekte senaryolu başlangıç eli veya eğitici kart üretimi kullanılabilir.
