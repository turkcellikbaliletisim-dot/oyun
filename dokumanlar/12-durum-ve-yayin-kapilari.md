# 12 — Tamamlanan işler ve kalan yayın kapıları

## Tamamlandı

Kural v0.2, belirsiz kart etkileşimleri, tutarlı bölüm/lig/takas kapsamı, kesin başlangıç ve test desteleri; 40 kartlı yerel oynanabilir motor; bot; deste oluşturma; 10 bölüm ve görev koşulları; yerel kayıt ve JSON tekrar; yerel koleksiyon, paket/garanti, üretim/parçalama ve günlük/haftalık/bölüm ödülleri; isteğe bağlı saat/ses; A4 baskı; otomatik motor/tarayıcı testleri. Ekonomi, mimari, sanat, kullanıcı testi ve yayın planları somutlaştırıldı.

Ekonomi/online/hukuk belgelerinde “taslak/uygulanmadı” belirtilen işleri yazılı plana dönüştürmek, o sistemleri kurmak veya sonuçlarını doğrulamak değildir.

## Açık iş listesi

| Öncelik | İş | Kabul ölçütü | Sorumlu rol |
|---|---|---|---|
| P0 | İnsanlarla kural ve denge testi | 30+ gerçek maç kaydı; kritik kural sorunları çözülmüş | Tasarım |
| P0 | İlk üç bölüm kullanıcı testi | 5+ yeni oyuncu; enerji/faz/hedefleme sorunları kaydedilmiş ve giderilmiş | Ürün + UI |
| P1 | Görev kartı çekiş/zorluk ayarı | Görev çekilemediği için terk oranı ve bölüm başına deneme ölçülmüş | Tasarım |
| P1 | Daha güçlü bot | Gizli bilgi kullanmadan kontrol destesi kararları, regresyon senaryoları | Geliştirme |
| P1 | Kart ayrıntı/erişilebilirlik | Küçük ekran, 200% zoom, klavye ve ekran okuyucu testi | UI |
| P1 | 40 özgün çizim ve ses/müzik | Kaynak dosyaları ve hak kayıtları; küçük ekran onayı | Sanat/ses |
| P1 | Mobil üretim motoru ve cihaz testi | Gerçek Android/iOS sürümü; hedef performans ve kayıt testi | Geliştirme |
| P1 | Ekonomiyi sunucuya taşıma | Yerel sahiplik/garanti/ödülleri güvenilir işlemlere taşıma; ücretsiz ilerleme insan testi | Geliştirme + tasarım |
| P1 | Yetkili maç sunucusu | Gizli bilgi, saat, hamle ve sonuç doğrulama testleri | Backend |
| P1 | Hesap/eşleştirme/yeniden bağlantı | Veri kaybı ve çift işlem yok; beta gerçek oyuncularla | Backend |
| P1 | Şirket/ülke/yaş/hukuk | Gerçek bilgilere göre uzman incelemesi ve nihai metinler | Ürün + hukuk |
| P2 | Kozmetik ödeme | Ürün tanımı, mağaza doğrulama ve iade senaryoları | Geliştirme + muhasebe |
| P2 | Analitik ve destek | Veri dayanağı, olay sözlüğü, hata alarmı ve destek akışı | Operasyon |
| P2 | Bütçe ve oyuncu edinme | Gerçek teklifler, net gelir/gider ve test bütçesi | Ürün |
| P3 | Yeni diyar/takas/turnuva | Ayrı ürün, denge ve hukuki inceleme | Ürün |

## Yayın için karar

Mevcut çıktı **yerel oynanabilir prototiptir**. İnsan dengesi, görsel üretim, hesap/sunucu, üretim ekonomisi güvenliği, ödeme ve hukuki kapılar tamamlanmadan ticari mobil oyun olarak hazır denmez. İlk sonraki çalışma, çalışan prototiple gerçek oyuncu testidir; daha fazla kart eklemek değildir.

## Değişiklik sınırı

v0.1 HTML/Claude tuvali arşiv olarak korunur. Kart ve kural değişimi v0.2 canonical kaynakta, otomatik test ve üretilmiş belgeyle birlikte yapılır. Eski maç kaydının aynı sonuç vermesi yalnız aynı kural sürümü için garanti edilir. Üretim sürümüne geçerken kayıt migrasyonu veya açık uyumsuzluk bildirimi gerekir.
