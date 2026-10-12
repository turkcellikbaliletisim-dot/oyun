# 06 — Hukuk ve yayın inceleme dosyası

Bu belge inceleme kapsamını tanımlar; hukuki uygunluk veya yayın izni vermez. Güncel ülke mevzuatı ve mağaza şartları bu görevde dış kaynaklardan doğrulanmadı. Hedef pazar, şirket, yaş grubu ve veri sağlayıcıları kesinleşince yetkin danışmanla değerlendirilmelidir.

## Ürün kararı

Yerel prototipte hesap, ödeme, reklam, kullanıcı takası ve dış analitik yok. Maç, hikâye ilerlemesi ve ücretsiz koleksiyon/altın/toz kayıtları tarayıcıda tutulur. Gerçek ödeme yoktur. Yayımlanacak sürüm için başlangıç adayı: Türkiye, Anadolu seti, ücretsiz kart kazanımı ve kozmetik gelir. Bu aday karar yayın yetkisi değildir.

Kapalı ekonomi tek başına rastgele ücretli paket veya turnuvanın hukuki sınıflandırmasını belirlemez. Beceri odaklı olmak rastgele çekişi ortadan kaldırmaz. Halk anlatısı kullanımı da modern görsel/çeviri/müzik haklarını otomatik sağlamaz.

## Karar ve belge listesi

| Gereksinim | Hazırlanacak kanıt | Sorumlu rol |
|---|---|---|
| Hedef yaş ve ülkeler | Ürün kapsamı, yaş derecelendirme değerlendirmesi | Ürün sahibi + hukuk |
| Şirket/işletmeci | Şirket adı, adres, iletişim, sözleşme tarafı | Ürün sahibi + muhasebe |
| Kişisel veri | Veri envanteri, amaç/dayanak, saklama, aktarım, silme, sağlayıcı sözleşmeleri | Geliştirici + hukuk |
| Çocuk koruması | Yaş ve ebeveyn akışı, izin, harcama sınırı, destek | Ürün + hukuk |
| Ödeme | Mağaza sözleşmesi, ürün tanımı, doğrulama, iade prosedürü | Geliştirici + muhasebe |
| Paketler | Uygulanacak gerçek oranlar, garanti, kopya koruması ve açıklama | Tasarım + hukuk |
| Marka/telif | Ad/marka araştırması, sanat/font/ses lisansları, sanatçı sözleşmeleri | Ürün + sanat |
| Kullanım şartları | Hesap, yaptırım, itiraz, servis, sanal ürün, iade | Hukuk |
| Gizlilik/aydınlatma | Gerçek veri akışına uygun metin, izin arayüzü | Hukuk + geliştirici |
| Turnuva/takas | Ek inceleme; ilk sürümde yok | Ürün + hukuk |

## Veri envanteri başlangıç taslağı

| Veri | Yerel prototip | Online sürüm önerisi / açık karar |
|---|---|---|
| Maç tohumu/hamleler | Tarayıcı localStorage; kullanıcı JSON olarak indirebilir | Sunucuda hata/itiraz amacıyla sınırlı saklama; süre hukukla seçilecek |
| Hikâye ve koleksiyon ilerlemesi | Aynı tarayıcı; hesap yok | Hesaba bağlı; hesap silmeyle ilişkilendirilecek |
| E-posta/kimlik | Toplanmaz | Sağlayıcı ve hesap yöntemi seçilmeden toplanmaz |
| Ödeme bilgisi | Toplanmaz | Ham kart bilgisi uygulamada tutulmaz; mağaza işlem kimliği ihtiyacı incelenir |
| Analitik | Dış servise gönderilmez | 04 sözlüğü üzerinden minimizasyon ve uygun dayanak |
| IP/servis kayıtları | Uygulama dış analitik kullanmaz; hosting logları ayrı değerlendirilir | Hosting sağlayıcısı, log kapsamı ve süreleri envantere alınmalı |

Yerel tarayıcı verisini silmek için tarayıcının site verilerini temizleme işlevi kullanılabilir. İndirilen JSON dosyalarını kullanıcı ayrıca siler. Sunucu hesabı silme, erişim talebi ve ihlal müdahalesi üretim sürümünün ayrı kabul koşullarıdır.

## İncelemeye sunulacak metin iskeletleri

- Gizlilik: işletmeci ve iletişim → veri kategorileri/amaç/dayanak → sağlayıcı/aktarım → saklama/silme → kullanıcı hakları/başvuru → çocuklar → değişiklik bildirimi.
- Kullanım şartları: hizmet kapsamı/yaş → hesap güvenliği → sanal ürünlerin kapsamı → ödeme/iade → yasak davranış → yaptırım/itiraz → kesinti/kapanış → uyuşmazlık/iletişim.
- Satın alma açıklaması: gerçek ürün içeriği/fiyatı → rastgelelik varsa tam açıklama → harcama koruması → mağaza iade yolu → destek.

Şirket, sağlayıcı ve ülke bilgileri bilinmediğinden bu iskeletler kullanıcıya sunulacak nihai sözleşme değildir. Uydurma şirket bilgisi veya incelenmemiş metinle yayın yapılmaz.
