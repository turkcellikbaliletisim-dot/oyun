# 13 — v0.2 doğrulama sonuçları

12 Ekim 2026, mevcut bulut makinesi. Sonuçlar yeni yayımlanmış veya yeniden kurulmuş bir ortamda doğrulama anlamına gelmez.

| Kontrol | Sonuç | Kapsam |
|---|---|---|
| `npm test` | 58 geçti, 0 başarısız/atlanan | Motor, 40 kart, 10 bölüm ve yerel ekonomi |
| `npm run simulate` | 60 maç tamamlandı, 60 tekrar aynı sonucu verdi | Bot, sıra/faz ve saha/el/tuzak sınırları |
| Bölüm erişilebilirliği | 10 görevin tümü yasal maçta kazanılarak tamamlanabildi | Otomatik pilot; insan zorluğu ölçümü değil |
| `npm run economy` | 7/30/90 gün ve 440→260 toz hesabı üretildi | Varsayımsal yoğun katılım; gerçek oyuncu kazanımı değil |
| `python3 tests/browser-smoke.py` | Geçti | Deste/sahiplik, hedefleme, eğitim/bölüm, paket/üretim/parçalama, kayıt, saat, mobil ve baskı |
| Kart belgesi tekrar üretimi | İçerik değişmedi | canonical kart kaynağı ile belge tutarlılığı |
| `git diff --check` ve belge bağlantıları | Geçti | Boşluk hataları ve yerel bağlantılar |
| Baskı PDF | 6 A4 sayfa, 40 adet 63×88 mm kart, taşma kontrolü geçti | Fiziksel yazıcı ölçeği ayrıca kontrol edilmeli |
| GitHub Actions | İş akışı eklendi; uzak çalışma yapılmadı | Komutlar bu makinede çalıştı |
| İnsan maçları / gerçek cihazlar / online / ödeme / hukuk | Çalıştırılmadı veya uygulanmadı | 12 belgesindeki açık kapılar |

Bot karşılaştırmaları: Başlangıç–Bozkır 13/20; Bozkır–Kadim 17/20; Kadim–Başlangıç 8/20. Bunlar hem deste hem bot kararının etkisini içerir; gerçek oyuncu denge oranları olarak sunulmaz. Kontrol botunun karar kalitesi ve görev kartının çekilememesi özellikle sonraki insan/bot testinde incelenecek.

Yerel uygulama mevcut HTTP sunucusundan açıldı. Node.js 24, Python 3.12 ve headless Chromium kullanıldı. Tarayıcı test araçları uygulamanın çalışma bağımlılığı değildir. Başlatma talimatı bulut yapılandırma taslağında güncellendi; ortam yayımlanmadı.

## Kart görselleri ve oyuncu testi araçları

40 karta özgü illüstrasyon, 10 atlas, 6 güncel Claude Design tuvali, 6 bağımsız HTML ve galeri eklendi. Tüm resimler tarayıcıda decode edildi; filtreler, dar görünüm ve beş kart sayfasında metin taşması kontrolleri geçti. PDF 6 A4 sayfadır. Kart ve tuval üretimi tekrar çalıştırıldığında aynı içeriği verdi.

Bot taktik regresyonları; özel başlangıç elinin kart çoğaltmaması ve görev kartını koruması; geri bildirim doğrulaması, tekilleştirme ve CSV formül koruması test edildi. Tarayıcıda kart inceleme, klavye başlangıç onayı/hedef odağı, maç değerlendirmesi ve CSV indirme kontrol edildi. 195 CSS px genişlikte sayfa taşması yok. Gerçek insan değerlendirmesi veya fiziksel ekran okuyucu testi yapılmadı.
