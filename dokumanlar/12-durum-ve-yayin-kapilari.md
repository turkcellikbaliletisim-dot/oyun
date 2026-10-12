# 12 — Tamamlanan işler ve kalan yayın kapıları

## Tamamlandı

Kural v0.2, belirsiz kart etkileşimleri, tutarlı bölüm/lig/takas kapsamı, kesin başlangıç ve test desteleri; 40 kartlı yerel oynanabilir motor; bot; deste oluşturma; 10 bölüm ve görev koşulları; yerel kayıt ve JSON tekrar; yerel koleksiyon, paket/garanti, üretim/parçalama ve günlük/haftalık/bölüm ödülleri; isteğe bağlı saat, prosedürel ses/müzik ve ses düzeyi; PWA kurulum ve isteğe bağlı 40 resimli çevrimdışı kullanım; 40 ayrı illüstrasyon, güncel kart tuvali/galerisi ve A4 baskı; otomatik motor/tarayıcı testleri. Ekonomi, mimari, sanat, kullanıcı testi ve yayın planları somutlaştırıldı.

Ekonomi/online/hukuk belgelerinde “taslak/uygulanmadı” belirtilen işleri yazılı plana dönüştürmek, o sistemleri kurmak veya sonuçlarını doğrulamak değildir.

## Açık iş listesi

| Öncelik | İş | Kabul ölçütü | Sorumlu rol |
|---|---|---|---|
| P0 | İnsanlarla kural ve denge testi | 30+ gerçek maç kaydı; kritik kural sorunları çözülmüş | Tasarım |
| P0 | İlk üç bölüm kullanıcı testi | 5+ yeni oyuncu; enerji/faz/hedefleme sorunları kaydedilmiş ve giderilmiş | Ürün + UI |
| P1 | Hikâye zorluk insan testi | Görev kartı başlangıç garantisi uygulandı; deneme/terk oranı gerçek oyuncularla ölçülecek | Tasarım |
| P1 | Botun ileri strateji değerlendirmesi | Görünür bilgiyle planlama, ölümcül hamle ve takas/kalkan regresyonları tamam; gerçek oyuncu zorluk testi kaldı | Tasarım |
| P1 | Gerçek ekran okuyucu ve cihaz testi | Kart inceleme, klavye odakları, duyurular ve dar görünüm kontrolleri tamamlandı | UI |
| P1 | Görsel inceleme ve ses/müzik | 40 görsel hazır; kültürel doğruluk/hak incelemesi, küçük ekran kullanıcı testi ve ses miksajı/gerçek cihaz dinleme kontrolü | Sanat/ses |
| P1 | Mobil üretim motoru ve cihaz testi | Kurulabilir web uygulaması hazır; gerçek Android/iOS cihaz ve gerekirse native mağaza paketi testi | Geliştirme |
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

HTML/Claude tuvali v0.2 verileri ve 40 illüstrasyonla güncellendi; önceki tasarım Git geçmişinde korunur. Kart ve kural değişimi v0.2 canonical kaynakta, otomatik test ve üretilmiş belgeyle birlikte yapılır. Eski maç kaydının aynı sonuç vermesi yalnız aynı kural sürümü için garanti edilir. Üretim sürümüne geçerken kayıt migrasyonu veya açık uyumsuzluk bildirimi gerekir.
