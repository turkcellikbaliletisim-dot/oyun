# Yatay mac duzeltmesi ve eszamanli dal uzlastirmasi

Kaynaklar: mobil dal `7b0bf33d30bc0eeae5e758689e912e04b686f55b` ve PR #3 duzeltmesi `928bfdda7e533443c23ca4b0d63b26e208ea9586`.

Onceki incelemede yatay yolculuk ekraninin dogrulanmasi, yatay mac ekraninin dogrulanmasi degildi. Yeni `native/landscape_match.gd`, skin_chrome -> mobile -> main zincirinde yalniz yatay mac sunumunu duzenler. Kahraman, iki saha seridi, kaydirilabilir el ve komut alani ayridir; sonuc penceresi ekran icinde kalir.

Mobil daldaki eszamanli degisiklikler korunur: ana ekran, tema dokulari, hedef halkasi/ok, paket acilisi, kahraman secici, PNG degisiklikleri, shot araclari ve mevcut kaynak dosyalari. `native/mobile.gd` aynen korunur. Etkin yatay duzen yeni alt siniftadir; dikey duzen mobil daldan gelir.

Iki tarafta degisen test dosyalari uzlastirildi. OGG oynatimi durdurulur; diger dalin doku/font/ses onbellek temizligi de korunur. Test yurutucusunda kaynak-hatasi mesajini yok sayan istisna kullanilmaz; butun ERROR/SCRIPT ERROR kayitlari hata sayilir. Yeni skin/yatay testleri mevcut testlere eklenir.

928bfdd icin GitHub oyun kontrolu 38355630426 ve ekran kontrolu 38355630457 basariliydi. Eszamanli degisikliklerle birlesmis yeni commit ayni kontrollerden yeniden gecmelidir; onceki basari yeni birlesimin onayi degildir. Sonuc kaydi PR #3 aciklamasindadir.

Yatay kontrol: 667x375, 740x360, 844x390, 1280x720; baslangic eli, 5+5 dolu saha/7 kart, hedef secimi, rakip turu ve sonuc. Ozel durumlar yerlesim verisidir; gercek oyun simulasyonu degildir. Sunucu destekli tam oyun ve dokunma testleri ayrica calisir. Fiziksel cihaz testi yapilmadi. Eski atlas kalitesi ve yasam dongusu kapanis uyarisi ayri acik islerdir.

Main ve otomatik/saatlik hedef alinmadi; saatlik gorev ayarlari degistirilmedi. Font ikili dosyasi eklenmedi veya degistirilmedi.
