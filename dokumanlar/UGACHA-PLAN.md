# Destan Diyarları · UGACHA tarzı geliştirme planı (2026-10-13)

Örnek oyun: UGACHA! (111%) — "rastgele kart karıştırma strateji aksiyon". Çekirdek: kart çağır, aynı yıldızlı iki kartı karıştır → rastgele bir üst yıldız kart, otomatik savaş, yeniden doğuş, totemler (gücü katlar), iksirler, arkadaşlarla yarış, çevrimdışı oynanış.

## 1. Çekirdek döngü (bir koşu = 3-8 dakika)
1. Savaş alanı: ekranın üst yarısında yukarıdan aşağı kıvrılan yol; düşmanlar yolu izleyip alttaki kale kapısına yürür.
2. Alt yarıda 3x5 = 15 kart yuvası. "ÇAĞIR" düğmesi altın harcar, boş yuvaya rastgele 1 yıldızlı kahraman kartı koyar. Her çağrı maliyeti +1 artar.
3. Aynı kahraman + aynı yıldızlı iki kartı sürükleyip birleştir → yıldız+1 olan RASTGELE bir kahraman (UGACHA/Random Dice kuralı). En çok 6 yıldız. İki 6 yıldızlı birleşmez.
4. Kartlar otomatik saldırır: menzil içindeki en öndeki düşmana mermi atar. Hasar = taban × yıldız çarpanı × kalıcı kahraman seviyesi × totem.
5. Dalgalar: her dalga 20-40 düşman; öldürülen her düşman altın verir. Her 10. dalga boss (süre sınırı 45 sn). Kapıya ulaşan düşman kaleye hasar verir; kale canı biterse koşu biter.
6. İksirler (koşu başına sınırlı): Öfke (saldırı hızı x2, 10 sn), Altın (anında altın), Buz (tüm düşmanları 5 sn dondur), Şifa (kaleye can).
7. Koşu sonunda: ulaşılan dalgaya göre altın + elmas + kart parçası + sandık.

## 2. Kahramanlar (12)
| Kimlik | Ad | Rol | Yetenek |
|---|---|---|---|
| kilic | Alp Kılıççı | yakın, yüksek hasar | %15 kritik |
| okcu | Okçu | hızlı tek hedef | hızlı atış |
| buyucu | Büyücü | alan | 2. hedefe sıçrar |
| kalkan | Kalkancı | sersemletme | %10 şansla 1 sn sersemletir |
| kam | Kam | buz | yavaşlatır %30 |
| mizrakci | Mızrakçı | delici | 2 düşmanı deler |
| kurt_binicisi | Kurt Binicisi | çok hızlı | saldırı hızı yüksek |
| simyaci | Simyacı | zehir | saniye başı hasar |
| mancinik | Mancınık | ağır alan | yavaş, büyük alan hasarı |
| tulpar_okcu | Tulpar Okçu | uzun menzil | boss'a +%50 |
| umay | Umay | destek | komşu kartlara +%20 hasar, öldürmede +altın |
| ejder_yavrusu | Ejder Yavrusu | efsanevi | yanma + alan; yalnızca 3★ üstü birleştirmeden çıkar |

## 3. Meta ilerleme (kalıcı, çevrimdışı kayıt)
- Para: Altın (kahraman yükseltme), Elmas (totem, sandık), Kart parçası (kahraman seviye), Ruh taşı (yeniden doğuş).
- Kahraman seviyesi 1-15: parça + altınla yükselir, her seviye +%10 hasar.
- Totemler (4): Savaş (hasar), Hız (saldırı hızı), Altın (koşu altını), Kale (kale canı). Elmasla seviye; her seviye gücü katlar (x2 hedefi uzun vadede).
- Yeniden doğuş: en iyi dalga ≥ 30 iken sıfırla → ruh taşı; her taş kalıcı +%5 tüm hasar.
- Günlük görevler (3), günlük giriş hediyesi, çevrimdışı kazanç (en iyi dalgaya göre saatlik altın, en çok 8 saat), sandıklar (sıradan/nadir/destansı).
- Bölümler: dünya 1-5 (her dünya farklı düşman seti ve boss), her dünya 30 dalga.

## 4. Çevrimiçi (sunucu hazır olunca)
- Arkadaşla yarış: aynı tohumla iki oyuncu aynı dalgaları oynar, kim daha uzağa giderse kazanır (asenkron, kod paylaşımı).
- Haftalık lider tablosu (en iyi dalga). Sunucu: Fly.io, mevcut Node API'ye `uga/*` uçları.
- Çevrimdışı her şey oynanır; çevrimiçi yalnızca yarış ve sıralama.

## 5. Ekranlar (dikey telefon, 390x844 temel)
Ana sayfa (kale arka planı, OYNA, dünya seçimi, kaynaklar) · Savaş · Koşu sonu · Kahramanlar (koleksiyon/yükseltme) · Totemler · Mağaza/Sandık · Görevler · Ayarlar. Eski kart düellosu "Düello" sekmesinde kalır.

## 6. Teknik
- `native/uga/uga_data.gd` veri, `uga_sim.gd` deterministik sabit adımlı simülasyon (60 adım/sn yerine 20 adım/sn mantık, çizim ara değerli), `uga_meta.gd` profil ve ekonomi, `uga_battle.gd` savaş ekranı, `uga_screens.gd` menüler.
- Testler: simülasyon (birleştirme kuralları, dalga/boss, ölüm, ödüller), meta (yükseltme maliyeti, yeniden doğuş, çevrimdışı kazanç), arayüz duman testi ve ekran görüntüleri.

## 7. Görseller
1. parti (21) ve 2. parti (36) hazır. 3. parti (45) istendi: 8 kahraman portresi, 6 yıldız kart çerçevesi, savaş/ana sayfa arka planı, kale kapısı, 5 mermi, 3 vuruş efekti, 4 iksir, 6 ikon, çağır düğmesi, 3 sandık, 4 düşman, 2 boss. Klasör: `gorsel-yeni3/`.

## 8. Gece yol haritası
1. Plan + görsel isteği · 2. Simülasyon + testler · 3. Savaş ekranı · 4. Meta + menüler · 5. Görselleri bağlama (yarım saatte bir kontrol) · 6. Dengeleme (otomatik oynatıcı ile dalga eğrisi) · 7. APK + video.

## 9. Gece ilerlemesi (2026-10-14, otomatik)
Yapılanlar: deterministik savaş simülasyonu (`native/uga/uga_sim.gd`), kalıcı ilerleme (`uga_meta.gd`), elle çizilen savaş ekranı (`uga_battle.gd`: boyalı yolda yürüyen düşmanlar, mermiler, vuruş efektleri, sürükle-birleştir, SAT bölgesi, koşu içi güçlendirme şeridi, 4 iksir, OTO ve x1/x2/x3 hız, duraklat, boss can çubuğu, ilk koşu öğreticisi, titreşim ve sesler), menüler (`uga_ui.gd`: merkez, kahramanlar/takım, totemler, sandıklar, görevler, yeniden doğuş, sıralama & yarış, koşu sonu). Uygulama dikey açılır (390x844).
Çevrimiçi: sunucuda `/api/uga/score`, `/api/uga/board/N`, `/api/uga/race`, `/api/uga/race/KOD[/result]` (testli). Sunucu yayına alınınca sıralama ve kodla arkadaş yarışı çalışır; çevrimdışıyken yerel rekorlar görünür.
Denge: ilerleme simülasyonu ile ayarlandı (otomatik oyuncuyla 1. dünya ilk koşu, 2. dünya ~6, 3. ~17, 4. ~27 koşu; 5. dünya için yeniden doğuş ve yeni kahraman gerekir).
Testler: `tests/uga-sim.gd`, `tests/uga-meta.gd`, `tests/uga-server.test.js`, düzen testi tüm UGACHA ekranlarını 360/390/844/1280 genişlikte taşma için kontrol eder. Ekran görüntüleri: `tests/uga-shots.gd`.
Sıradaki: sunucuyu yayına almak, oyuncu adı, mağaza/IAP (isteğe bağlı), daha çok dünya arka planı (4. parti istendi), ses efektlerinin çeşitlenmesi.

### Gece sonu eklemeleri
- Günün meydan okuması (herkese aynı tohum, günde bir elmas ödülü), oyuncu adı (sıralama), dünya kartında düşman listesi.
- Zırhlı düşmanlar (Taş Golem %30, Tepegöz %40, bosslar %15) ve iyileşen Karakoncolos; zehir/yanma zırhı deler.
- 4. parti görseller: dünya savaş arka planları (aynı yol), amblemler, başlık şeritleri, efektler.
- Dokunma düzeltmesi: savaş ekranında bir dokunuş artık iki kez sayılmıyor (testli).
- Android 0.4.0 (kod 4), dikey ekran. APK: Mac'te `oyun/DestanDiyarlari-ugacha.apk` ve Masaüstü.

### 0.6.0 (2026-10-14)
- Kare kare animasyon: 12 kahramanın 4 karelik saldırı şeridi (`attack_<kahraman>.png`), düşman yürüme şeritleri (`walk_<tür>.png`, kurt eklendi). ChatGPT 5. parti.
- Menüler sahne düzenine geçti: Totem sunağı (2x2 totem heykeli), Sandık hazinesi (raf + 4 karelik açılma animasyonu + yeni kahraman gösterimi), Görev panosu (parşömen notlar).
