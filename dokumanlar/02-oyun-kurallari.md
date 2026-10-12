# 02 — Oyun kuralları v0.2

Bu belge `oyun/engine.js` ile uygulanan yerel prototipin kurallarıdır. v0.1'e göre önemli değişiklik: savaşçı hasarı tur sonunda iyileşmez; **kalıcıdır**. Saldırı ve kart etkileri daha kesin tanımlanmıştır. Denge çalışması sürer.

## Hazırlık ve açık/gizli bilgi

- İki oyuncu, her biri tam 20 kartlık bir deste. Bir karttan en çok 2; her farklı Efsanevi karttan en çok 1. Destede birden fazla farklı Efsanevi bulunabilir.
- Başlangıç canı ve azami oyuncu canı 20. Saha 5 savaşçı, el 7 kart, tuzak alanı 2 kart.
- Başlayan oyuncu, deste karıştırma ve başlangıç eli maç tohumu üzerinden belirlenir. Tekrarlanabilir rastgelelik yalnız yerel prototip içindir; güvenli çevrimiçi kullanım değildir.
- Her oyuncu 4 kart alır. Bir kez istediği kartları değiştirir. İade edilen kartlar yeniler çekilirken dışarıda tutulur, sonra desteye karıştırılır. Aynı kartın başka kopyası çekilebilir.
- İlk oyuncu ilk kendi turunda çekmez. İkinci oyuncu ilk kendi turunda normal çekişe ek 1 kart, yani toplam 2 çeker. Sonraki turlarda herkes 1 çeker.
- Saha, can, enerji, el/deste kart sayısı ve savaşçı mezarlığı açıktır. El kimlikleri, deste sırası ve açılmamış tuzak kimlikleri gizlidir. Tuzak sayısı her zaman görünür.

## Tur akışı

1. Kendi tur sayısını artır; azami enerji 1 artsın (en çok 8); kullanılabilir enerji azami enerjiye dolsun. Yeni oyunda azami enerji 0, ilk turda 1'dir.
2. Kendi savaşçıların hazır hale gelsin. Donmuş savaşçı hazır olsa da saldırmaz.
3. Sahadaki Dede Korkut'lar geliş sırasıyla üst karta bakar. Her biri için tut/alta koy seçimi yap; sonra normal çekişleri uygula.
4. **Ana faz:** Enerjin yettiğince savaşçı, büyü ve tuzak oyna. Hedef ve alan şartları sağlanmadan kart oynanamaz, enerji harcanmaz.
5. **Saldırı fazı:** İlk geçerli saldırı fazı başlatır. Sonra kart oynanamaz; ana faza dönülmez. Saldırılar sırayla çözülür. Bir savaşçı kendi turunda en çok 1 kez saldırır. Saldırı fazına geçmeden de tur bitirilebilir.
6. **Bitiş:** Bu tur saldırı artışları, hasar bağışıklıkları ve Kale Surları sona erer. Yaralı savaşçıların canı aynı kalır. Sonraki oyuncunun turu başlar.

Yerel çalışmada süre isteğe bağlıdır. Süreli modda her oyuncunun turu, Dede Korkut ve çekiş seçimleri dahil 45 saniyedir. Süre dolarsa üst kart tutulur, zorunlu atışta elin ilk kartı atılır ve tur biter. Başlangıç eli seçimi süresizdir. Yerel ana menüye dönüş oyunu duraklatır; bu pratik kolaylığı çevrimiçi lig kuralı değildir.

## Kart oynama ve olay sırası

1. Sıra, faz, enerji, hedef, el ve saha sınırları doğrulanır.
2. Kart elden çıkar, enerji harcanır.
3. Büyü için rakipteki ilk uygun Yankı açılır; büyü iptal edilir. Enerji/kart iade edilmez. Diğer Yankılar kullanılmaz.
4. Savaşçı temel değerleriyle sahaya gelir. Rakibin Kervan Yolu Pusu tuzakları kurulduğu sırayla çözülür. Savaşçı ölürse sonraki pusular açılmaz ve oynanınca etkisi çalışmaz.
5. Sağ kalan savaşçının oynanınca etkisi veya iptal edilmemiş büyünün etkisi uygulanır.
6. Etki sonucunda canı 0 veya altına düşen savaşçılar birlikte kaldırılır. Oyuncu canları kontrol edilir; gerekiyorsa maç biter.

Tuzak kurulunca enerji hemen ödenir; kimliği açılana kadar gizlidir. Kurulduğu anda etkinleşir. Rakip tepki için elinden kart oynayamaz; tepki yalnız kurulmuş tuzaklardan gelir. Bir hedef çözüm sırasında ortadan kalkarsa ilgili etki boşa gider. Başka hedefe otomatik aktarılmaz.

## Savaş ve anahtar kelimeler

- Savaşçı, çıktığı tur saldıramaz; **Hızlı** istisnadır. Her saldırı savaşçıyı tükenmiş yapar; tuzak saldırıyı iptal etse de hakkı kullanılmıştır.
- Oyuncuya doğrudan saldırı, saldırganın güncel saldırı değeri kadar hasar verir.
- İki savaşçı çarpışırken saldırı değerleri önce alınır, iki hasar ölüm temizliğinden önce uygulanır. Bu yüzden öldürülen savunucu da karşı hasar verir.
- **Koruyucu:** Rakipte varsa yalnız rakip Koruyucu savaşçılar saldırı hedefi olabilir. Büyü ve oynanınca etkilerinin hedef seçimini kısıtlamaz.
- **Uçan:** Yerdeki savaşçı onu saldırı hedefi seçemez. Yerdeki savaşçıdan gelen karşı saldırı hasarını da almaz. Uçan savaşçı hem yer hem hava hedeflerine saldırabilir. Büyü, tuzak ve oynanınca hasarı Uçan'ı etkiler. Uçan+Koruyucu varsa yerdeki saldırganın geçerli saldırı hedefi olmayabilir; doğrudan oyuncuya geçemez.
- **Zehirli:** Savaşçıya gerçekten pozitif savaş hasarı verdiğinde onu yok eder. 0 hasar veya engellenmiş hasar tetiklemez; oyuncuya uygulanmaz. Karşı saldırıda da çalışır.
- **Donma:** Etkilenen savaşçı sahibinin bir sonraki turunda saldıramaz. Daha sonra sahaya çıkanları etkilemez. Donma kart oynama veya savunma karşı hasarını engellemez.
- Saldırı değeri negatif olamaz. 0 saldırı ile saldırı başlatılamaz.

## Tuzak çözümü

Saldırı önce geçerli hedefle ilan edilir; ardından savunanın uygun tuzakları kurulma sırasıyla çalışır. Saldırgan sahadan çıkarsa kalan saldırı tuzakları açılmaz. Savunan hedef kaybolursa hasar uygulanmaz.

| Kart | Kesin davranış |
|---|---|
| Tuzak Kuyu | Temel enerji maliyeti 3 veya daha düşük saldırganı hasardan önce yok eder. Hasar bağışıklığı yok edilmeyi önlemez. |
| Yankı | İlk rakip büyüyü etkisi çalışmadan iptal eder. |
| Kale Surları | İlk geçerli rakip saldırısında açılır. Bu turun kalanında kendi oyuncu ve savaşçılarına gelen bütün hasar kaynakları yarıya iner, aşağı yuvarlanır. İki kopya üst üste ikinci kez yarılamaz. |
| Hile | Saldırganı hasardan önce eline geri yollar. El doluysa savaşçı yok olur ve mezarlığa gider. El boşsa mezarlığa gitmez; tüm güçlendirmelerini kaybeder. |
| Kervan Yolu Pusu | Elden oynanan rakip savaşçıya oynanınca etkisinden önce 4 hasar verir. Diriltme bunu tetiklemez. |

Örnek: önce Hile, sonra Tuzak Kuyu kurulmuşsa ucuz saldırgan ele döner; Kuyu kapalı kalır. Önce Kuyu kurulmuşsa saldırgan ölür; Hile kapalı kalır.

## Hedefler, iyileştirme ve özel etkiler

- “Rakibe hasar”: rakip oyuncuya. “Bir hedef”: iki oyuncudan biri veya sahadaki herhangi bir savaşçı. Bilinçli olarak kendi hedefini de seçebilirsin.
- Bir savaşçının iyileşmesi kendi güncel azami canıyla sınırlı; oyuncu iyileşmesi 20 ile sınırlıdır.
- Çini Ustası başka bir mevcut dost savaşçıya kalıcı +1 saldırı, +1 mevcut/azami can verir. Hacivat başka bir mevcut dosta +2 mevcut/azami can verir. Kendilerini seçemezler. Başka dost yoksa oynanabilirler, etki boşa gider.
- Ocak Topçusu seçilen rakip savaşçıya 3 hasar verir. Rakip saha boşsa oynanabilir, etki boşa gider.
- Nasreddin Hoca en yüksek güncel saldırılı rakibi dondurur; eşitlikte sahaya önce gelen seçilir. Rakibin bir sonraki kendi turu boyunca sürer.
- Bozkurt saldırı artışı dinamiktir: sahadaki diğer dostların sayısı değişince artış da değişir.
- Kervansaray Tüccarı o tur kullanılabilir enerjiye +1 verir, azami enerjiyi artırmaz; kullanılabilir enerji 8'i aşmaz.
- Tepegöz kendi savaşçısına 1 hasar verir. Hızır kendisi dahil tüm dost savaşçıları azami canına iyileştirir.
- Ergenekon Demircisi savaşçı mezarlığındaki bir kaydı seçer; kendi gelişi sonrası boş yer varsa temel değerlerle diriltir. Kayıt mezarlıktan çıkar. Oynanınca etkisi tekrarlanmaz; Hızlı olan hemen saldırabilir. Başlangıçta 4 savaşçı varsa Demirci beşinci olur, diriltme olmaz. Mezarlıkta kart yokken de oynanabilir.
- Pazar Pazarlığı iki çekişi yapar, sonra elden 1 kart seçilerek atılır. El boş kaldıysa atış yok. Maç çekiş hasarıyla biterse kalan işlemler yapılmaz. Zorunlu seçim bitmeden başka hamle yapılamaz.
- Dede Korkut yalnız sahibinin tur başında ve çekişten önce çalışır; boş destede seçim yok.

## Sınırlar ve kartların kaderi

- Dolu sahaya savaşçı, dolu tuzak alanına tuzak oynanamaz; kart elde ve enerji aynı kalır.
- Dolu ele çekilen veya geri dönen kart yok olur. Yakılan/atılan el kartları savaşçı mezarlığına girmez. Mezarlık yalnız sahada yok olan savaşçıları tutar.
- Boş desteden **her başarısız çekiş** oyuncuya 1 hasar verir; sabit kalır, artmaz. Ek kart çekme etkileri de buna dahildir.
- Deste bitmesi tek başına yenilgi değildir. İyileştirme, tuzak ve kalkan yalnız tanımlanan hedef ve etki kapsamına uygulanır.

## Kazanma, süre ve kayıt

- Bir oyuncunun canı 0 veya altına düşerse diğer kazanır. Aynı olayın sonunda ikisi de ölürse beraberlik.
- En çok 20 tam tur: toplam 40 oyuncu turu. Son tur sonunda canı fazla olan kazanır; eşitlik beraberlik. Otomatik iyileşme veya ek uzatma yok.
- Teslim olan kaybeder. Yerel uygulamayı kapatma teslim sayılmaz; son kayıt yeniden yüklenebilir.
- Maç tohumu, ilk desteler ve hamle dizisi JSON'a kaydedilir. v0.2 kayıtları v0.2 motoruyla yeniden oynatılır; farklı kurallarla sessizce açılmaz.
- Yerel kayıt ve tüm kartların açık olması beta kolaylığıdır. İstemci hileye karşı güvenli değildir; çevrimiçi lig yoktur. Ekonomik sahiplik yalnız düzenlenebilir yerel kayıttadır; güvenli sunucu sahipliği uygulanmamıştır.

## Rekabet tasarımı — henüz uygulanmayan

Ligler: Çırak, Kalfa, Usta, Destancı, Efsane. Çevrimiçi yayın için sunucu otoritesi, eşleştirme ve sezon kuralları 09 belgesinde tanımlıdır. Kart çekişi ve başlangıç sırası rastgeledir; “beceri odaklı” hedef bir denge iddiasıdır, şanssız oyun veya hukuki sınıflandırma değildir.
