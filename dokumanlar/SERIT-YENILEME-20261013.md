# Saha şeritleri ve yükleme ipucu paneli - 13 Ekim 2026
Kaynak: claude/mobil-arayuz-skin-v2 / acf6f30562ebb24268ae703429ca5a1cfc5f3b15.

## Üretim ve kapsam
Üç ayrı Adobe Firefly üretimi kullanıldı; eski atlas büyütülmedi. Adobe arka plan kaldırma ve yeşil renk aralığı düzeltmesinden sonra, yarı saydam sınırın iki çıktı pikseli yakınındaki kalıntıya hassas renk temizliği uygulandı. Alfa ve opak iç alan korunur. İlk iki aday renk kalıntısı testinden geçmedi; test eşiği gevşetilmedi.
Uçlar orantılı kalan yatay üç-parça yerleşimiyle hedef boyuta uyarlandı. Yalnız sade orta alanın oranı ayrı değişir; her parça kaynak piksellerinden küçültülür. Bu teknik paketleme AI büyütme veya tüm görselin orantısız esnetilmesi değildir.
lane.png ve lane_enemy.png: 1024x400. loading_tip_panel.png: 900x160. Dış alan gerçek alfa; merkez boyalı, koyu ve yazısızdır.
Tam kaynaklar serit-yenileme-kaynak/ içinde. Hash, kaynak boyutu, kesit ve işlem kayıtları serit-yenileme-kontrol.json ve native/skin/manifest_lane_refresh.json içindedir.
İki eski manifestte yalnız ilgili şerit kaydı yenilendi; eski kayıt previous_revision içinde saklanır. Orijinal 114 dosyalık paket sayımı değişmedi; ipucu paneli ek dosyadır.

## Oyun bağlantısı
mobile.gd ve landscape_match.gd içinde yalnız şerit çizimindeki yatay kesit payı 246 px olarak güncellendi. Dosya adları, oyun kuralları, ağ/hesap işleyişi, diğer PNG'ler, fontlar ve sesler değişmedi.
loading_tip_panel.png dosya olarak eklendi; giriş/yükleme ekranı akışı bu değişiklikte kurulmadı.

## Doğrulama sınırı
Üç PNG'nin boyutları, alfa kenarları, opak merkezleri, yeşil renk kalıntısı ve yeniden açılması; eski 114 PNG'nin kapsamı/boyutları kontrol edildi. Gerçek renderer ekranları ve oyun kontrolleri PR üzerinden ayrıca doğrulanacak. Fiziksel cihaz testi yapılmadı.
Üç yeni kahraman, üç rütbe rozeti, gerçek ses ve mevcut zamanlama/kart metni işleri bu kapsamda değildir.
