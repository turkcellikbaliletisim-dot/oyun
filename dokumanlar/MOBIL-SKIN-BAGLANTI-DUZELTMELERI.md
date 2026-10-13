# Mobil skin bağlantıları - dar kapsamlı düzeltme

Kaynak dal: `claude/mobil-arayuz-skin-v2`, başlangıç commit'i `abbfe8c2c79849281fed870ec9d03f029a2354d6`.
Çalışma dalı: `gorsel-kalite/mobil-skin-baglantilari-20261013`.

## Değişiklikler

- `native/data.json`: kanonik üreticinin iki boşluklu çıktısına döndürüldü. Kart, deste ve bölüm değerleri değiştirilmedi. Kaynak eşleşme kontrolü kaldırılmadı.
- `native/skin_chrome.gd`: mevcut mobil arayüz üzerine ayrı bir sunum katmanı. `backdrop.png`, bağlantı durumu için mevcut `icon_net_ok/bad.png`, alt menü için `nav_bar.png` ve `nav_active.png` bağlandı.
- Menüdeki dört dairesel yuva yatay ekranda esnetilmez; yalnız yuvalar arasındaki şeritler uzatılır. Mevcut ikon ve yazıların dokunma davranışı korunur. Seçili sekme halkası, yazı rengi ve klavye odak çerçevesi ayrıdır.
- Ağ koduna ikinci bir asenkron sarmalayıcı eklenmez. Görünüm, mevcut bağlantı durumunu izler. PNG bulunmazsa açıklayıcı metin kalır.
- `native/main.tscn`, bu sunum katmanını çalıştırır; hesap, ekonomi ve oyun kuralları değiştirilmez.

## Doğrulama

`tests/native-skin-chrome.gd`, dört ekran boyutunda dört sekmeyi, tek aktif halkayı, en az 44px dokunma alanlarını, bağlantı ikonlarının iki durumunu ve maçtan sonra menünün geri gelmesini sınar. Mevcut native testler korunur.

`Mobile skin visual review` iş akışı, GitHub üzerindeki commit'ten Godot/OpenGL çıktıları alır. Çıktılar ve teknik rapor Actions artifact'i olarak saklanır; font dosyası dağıtılmaz. Bu ekran görüntüleri fiziksel iOS/Android testi değildir.

Test ve görsel inceleme sonuçları, tamamlandıkça ilgili PR'a yazılır. Başarılı olmayan kontrol atlanmaz. Bu belge tek başına testlerin başarılı olduğunu iddia etmez.

## Kapsam dışında

Yeni görsel üretimi, eski atlasların yeniden çizilmesi, `otomatik/saatlik` dalıyla birleştirme, ana dala yayın, seslerin nihai müzik olarak onayı ve saatlik görevi yeniden açma yapılmadı.
