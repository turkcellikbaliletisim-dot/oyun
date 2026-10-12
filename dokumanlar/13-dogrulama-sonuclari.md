# 13 — v0.2 doğrulama sonuçları

12 Ekim 2026, mevcut bulut makinesi. Sonuçlar yeni yayımlanmış veya yeniden kurulmuş bir ortamda doğrulama anlamına gelmez.

| Kontrol | Sonuç | Kapsam |
|---|---|---|
| `npm test` | 46 geçti, 0 başarısız/atlanan | Motor, 40 kart, 10 bölüm ve yerel ekonomi |
| `npm run simulate` | 60 maç tamamlandı, 60 tekrar aynı sonucu verdi | Bot, sıra/faz ve saha/el/tuzak sınırları |
| Bölüm erişilebilirliği | 10 görevin tümü yasal maçta kazanılarak tamamlanabildi | Otomatik pilot; insan zorluğu ölçümü değil |
| `npm run economy` | 7/30/90 gün ve 440→260 toz hesabı üretildi | Varsayımsal yoğun katılım; gerçek oyuncu kazanımı değil |
| `python3 tests/browser-smoke.py` | Geçti | Deste/sahiplik, hedefleme, eğitim/bölüm, paket/üretim/parçalama, kayıt, saat, mobil ve baskı |
| Kart belgesi tekrar üretimi | İçerik değişmedi | canonical kart kaynağı ile belge tutarlılığı |
| `git diff --check` ve belge bağlantıları | Geçti | Boşluk hataları ve yerel bağlantılar |
| Baskı PDF | 6 A4 sayfa, 40 adet 63×88 mm kart, taşma kontrolü geçti | Fiziksel yazıcı ölçeği ayrıca kontrol edilmeli |
| GitHub Actions | İş akışı eklendi; uzak çalışma yapılmadı | Komutlar bu makinede çalıştı |
| İnsan maçları / gerçek cihazlar / online / ödeme / hukuk | Çalıştırılmadı veya uygulanmadı | 12 belgesindeki açık kapılar |

Bot karşılaştırmaları: Başlangıç–Bozkır 9/20; Bozkır–Kadim 19/20; Kadim–Başlangıç 7/20. Bunlar hem deste hem bot kararının etkisini içerir; gerçek oyuncu denge oranları olarak sunulmaz. Kontrol botunun karar kalitesi ve görev kartının çekilememesi özellikle sonraki insan/bot testinde incelenecek.

Yerel uygulama mevcut HTTP sunucusundan açıldı. Node.js 24, Python 3.12 ve headless Chromium kullanıldı. Tarayıcı test araçları uygulamanın çalışma bağımlılığı değildir. Başlatma talimatı bulut yapılandırma taslağında güncellendi; ortam yayımlanmadı.
