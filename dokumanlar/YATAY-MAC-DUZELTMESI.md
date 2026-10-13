# Yatay mac duzeltmesi - 2026-10-13

Baslangic: mobil arayuz abbfe8c, onceki chrome duzeltmesi d5a41c6 (PR #3).
Onceki renderer ekraninda tur dugmesi dost saha bolgesinin uzerine geliyor ve saha kartlari ekran yuksekliginin sabit %12.5'iyle gereksiz kuculuyordu. Sadece bos saha veya yolculuk ekrani bu sorunu dogrulamaya yetmiyordu.

Bu duzeltme native/landscape_match.gd sunum katmaninda saha, el, kahraman ve komut alanlarini ayirir. PNG'ler yeniden uretilmez; oyun kurallari degistirilmez. Dar alanda el yatay, uzun secenekler kendi komut alaninda dikey kayar. Sonuc penceresi kisa yatay ekrana sigar. Dikey ekran eski renderer ile devam eder.

Yeni test: 667x375, 740x360, 844x390, 1280x720. Baslangic eli, 5'e 5 dolu saha, 7 kartlik el, 8 enerji, hedef secimi, rakip turu ve sonuc penceresi. Dolu saha goruntuleri yalniz test fiksturudur; gercek oynanis testi diye sunulmaz. Mevcut dokunma, etkilesim ve server entegrasyon testleri kaldirilmamistir.

Durum: degisiklik inceleme dalina hazirlandi. Actions sonuclari ve dogrudan ekran incelemesi tamamlanmadan basarili veya birlestirildi olarak kabul edilmez. Fiziksel iOS/Android testi yapilmadi. main ve otomatik/saatlik dallari bu degisikligin hedefi degildir.
