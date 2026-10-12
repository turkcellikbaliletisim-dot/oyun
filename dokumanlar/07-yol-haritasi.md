# 07 — Üretim planı ve karar kapıları

Eski sekiz aylık takvim teslim taahhüdü olmaktan çıkarıldı. İlerleme aşağıdaki kanıt kapılarıyla yönetilir. Süre ve bütçe, atanmış ekibin kapasitesine göre ayrıca tahminlenir.

## Tamamlanan teknik temel

- Tek kart kaynağı, 40 kart etkisi, v0.2 maç kuralları.
- Tarayıcıda çevrimdışı/yerel bot maçı, üç hazır deste ve deste oluşturma.
- 10 hikâye bölümü, görev doğrulama ve yerel bölüm ilerlemesi.
- Maç kaydı, JSON aktarım/yeniden oynatma, isteğe bağlı tur saati.
- Yerel koleksiyon, ücretsiz paket/garanti, üretim/parçalama ve günlük/haftalık/bölüm ödülleri.
- Bağımsız A4 baskı ekranı; 40 ayrı illüstrasyon ve temel erişilebilirlik.
- Motor testleri ve otomatik simülasyon; tarayıcı smoke testi.

40 kart illüstrasyonu ve görsel sayfaları tamamlandı. İnsan denge testleri, kültürel/hak incelemesi, online sunucu ve mobil mağaza uygulaması ayrı kapılardır.

## Aşamalar

| Kapı | İşler | Çıkış ölçütü |
|---|---|---|
| A — Kural/oynanış | İnsanlarla 30+ kayıtlı keşif maçı; kart metni ve kullanıcı sürtünmesini incele | Belirsizlik listesi kapalı; maç süresi, ilk oyuncu ve deste sonuçları kayıtlı |
| B — Kullanıcı deneyimi | İlk 3 bölümü yeni oyuncularla dene; mobil hedefleme ve görev çekişini ölç | Dış yardımsız temel hamle; önemli UI sorunları giderilmiş |
| C — Mobil üretim | Motor/platform kararı; cihaz profilleri; özgün sanat/ses; dağıtım sürümü | Hedef gerçek cihazlarda performans, kayıt ve erişilebilirlik testleri |
| D — Online beta | Yetkili sunucu, hesap, eşleştirme, yeniden bağlantı, servis ölçümü | Hile/geçersiz hamle ve bağlantı testleri; 50–100 gerçek beta oyuncusu |
| E — Ekonomi/yayın | Yerel ekonomiyi sunucuya taşıma ve ücretsiz ilerleme doğrulaması, gerekiyorsa kozmetik ödeme, hukuk/mağaza/işletim | Gerçek ürün ve veri akışına uygun inceleme; satın alma/iade testleri |
| F — Genişleme | Yeni diyarlar, takas veya sponsorlu turnuva | Her özelliğin ayrı denge, operasyon ve hukuki değerlendirmesi |

## Teknik karar

İlk doğrulama için bağımlılıksız JavaScript tarayıcı prototipi seçildi; düşük kurulum maliyetiyle gerçek hamleler test edilir. Bu bir Unity/Godot mobil üretim seçimi değildir. Mobil motoru insan testleri sonrası ekip yetkinliği, hedef cihaz ve maliyetle seçin. Web prototipin UI'dan bağımsız kuralları ve olay testleri yeni motora taşımada referanstır.

## Sorumluluk ve kapsam

Ürün/tasarım: kurallar, hedef oyuncu, denge ve ekonomi. Geliştirme: motor, UI, test, hesap/sunucu ve yayın. Sanat: görsel yönerge, kart illüstrasyonları ve haklar. Ses: efekt/müzik ve lisans. Topluluk/destek: beta, geri bildirim, itiraz. Hukuk/muhasebe: şirket, veri, ödeme ve ülke incelemesi. Gerçek kişi atamaları ürün sahibi tarafından yapılmalı; depoda atanmış çalışan varmış gibi yazılmaz.

Her iş için sahibi, tahmini gün, bağımlılık, maliyet ve kabul testi görev kaydına eklenir. İlk kapsam yalnız Anadolu, 40 kart ve sağlam maç çekirdeği. İlk yayında takas, ücretli rastgele paket, para ödülü ve çoklu diyar yok.

## Bütçe çalışma şablonu

| Kalem | Adet/süre | Birim maliyet | Toplam | Tekrarlayan mı? |
|---|---|---|---|---|
| Geliştirme | Atanacak kişi-ay | Teklif alınacak | Hesaplanacak | Evet |
| 40 kart sanatı + UI | Sanat yönergesine göre | Teklif alınacak | Hesaplanacak | İçerik başına |
| Ses/müzik | Efekt listesi + parça | Teklif alınacak | Hesaplanacak | İçerik başına |
| Hukuk/muhasebe | Kapsam/ülke | Teklif alınacak | Hesaplanacak | Kısmen |
| Sunucu/servis | Aktif oyuncu ve maç yükü | Sağlayıcı ölçümü | Hesaplanacak | Evet |
| Beta/destek/pazarlama | Hedef oyuncu/süre | Test bütçesi | Hesaplanacak | Evet |

Gerçek teklifler ve ekip bilgisi olmadan maliyet uydurulmaz. Oynanış doğrulanmadan büyük sanat veya reklam bütçesi bağlanmaz.
