# 04 — İlk hafta, erişim ve ölçüm

## Bugün çalışan akış

Hesapsız tarayıcı oyunu → başlangıç eli seçimi → serbest maç veya 10 bölümlük hikâye → yerel kayıt/tekrar oynama. Tüm kartlar ve üç hazır deste açıktır. Oyuncu kendi 20 kartlık destesini kurabilir. Yerel koleksiyon, ücretsiz paket, altın/toz, üretim/parçalama, günlük giriş/görev ve bölüm ödülleri çalışır. Reklam, gerçek ödeme, bildirim, çevrimiçi eşleşme ve takas yoktur.

## Koleksiyonlu yayın için ilk hafta taslağı

Günler yönlendirmedir, zorunlu bekleme değildir. Oyuncu bölümleri daha hızlı tamamlayabilir. Tek erişim kuralı: online lig bölüm 10 sonrası; takas ilk sürümde yok. İlk sürümde yalnız Anadolu var, diyar seçimi gösterilmez.

| Gün | Akış | Ödül / erişim |
|---|---|---|
| 1 | Kayıtsız eğitim, bölüm 1–3 | Eğitimden önce başlangıç destesi; 1 ücretsiz paket |
| 2 | Günlük görevler, bölüm 4 | Görev altını; günlük giriş 30 altın |
| 3 | Deste kurma rehberi, bölüm 5 | Ücretsiz kart arka yüzü |
| 4 | Bot maçı, bölüm 6 | Görev ve ilk tamamlama ödülleri |
| 5 | Bölüm 7, arkadaş ekleme tanıtımı yalnız online sürümde | Şahmaran; takas yok |
| 6 | Bölüm 8–9 | Kontrol/zamanlama öğretimi; henüz lig yok |
| 7 | Bölüm 10, arşiv seçimi | Mühür, Demirci, 7 eksik kart; online sürümde lig açılır |

## Kullanıcı akışı kararları

- İlk eğitimde satın alma ve mağaza yok. İlk 72 saat ticari teklif gösterilmez.
- Misafir ilerlemesi hesap bağlamada kaybolmamalı. Sunucu sürümünde hesap birleştirme ayrı işlem olarak test edilmeli.
- Yenilince nedeni, yeniden deneme ve kural yardımı gösterilmeli. Kazanmayı zorunlu kılmak yerine öğrenme ölçülmeli.
- Zorunlu bildirim izni yok; izin teklifine kadar oyun normal çalışır. Hedef sınır günde 1 bildirim; sessiz saatler oyuncu saat dilimine göre.
- Günlük görevler günde 1 kez yenilenir; kaçırılan gün serisi sıfırlanmaz. Günde bir ücretsiz görev değiştirme gelecekte değerlendirilecek; bugün görevler üç sabit koşuldur. Günlük giriş, üç görev ve yedi girişlik ödül yerel ekonomide uygulanır.
- Yaş/ebeveyn/satın alma akışları yayın öncesi hedef ülke ve mağazaya göre tasarlanır; yalnız yaş sorusu yeterli doğrulama değildir.

## Ölçüm sözlüğü — analitik servisi uygulanmadı

| Olay | Asgari alanlar | Amaç |
|---|---|---|
| session_start | anonim kurulum kimliği, sürüm, gün, saat dilimi | Oturum ve geri dönüş |
| tutorial_step | bölüm, adım, tamamlandı/terk | Takılma noktası |
| match_start | maç kimliği, mod, deste sürümü | Başlatılan maç sayısı |
| card_play | kart kimliği, tur, mod | Kart kullanım sıklığı |
| invalid_action | hata kodu, ekran | Kural/arayüz sürtünmesi |
| match_end | sonuç, sebep, süre, tur, ilk oyuncu | Tamamlanma ve denge |
| chapter_complete | bölüm, deneme sayısı | Öğrenme ve ilerleme |
| deck_save | kart kimlikleri, sürüm | Deste çeşitliliği |
| purchase_result | ürün, doğrulanmış işlem kimliği, sonuç | İade/ödeme takibi, sonraki sürüm |

E-posta, isim, ham IP, serbest metin veya ödeme bilgileri oyun olayına eklenmez. Üretimde ölçüm kapsamı veri envanteri ve geçerli hukuki dayanakla eşleştirilir. Prototip dışarıya analitik göndermez.

## Tanımlar ve karar kapıları

- D1/D7/D30: kurulum tarihine göre oluşturulan kohortta, oyuncunun yerel takviminde ilgili gün en az bir gerçek oturum açanların oranı. Zaman dilimi değişikliğinin sayım kuralı tek servis tarafından uygulanmalı.
- Eğitim tamamlama: bölümler 1–3'ü bitiren / eğitimi başlatan. İlk gerçek maç kazanma oranı senaryolu bölüm 1'den ayrı tutulur.
- Hedefler hipotez: D1 ≥ %35, D7 ≥ %12, eğitim ≥ %70. Bunlar mevcut sonuçlar değildir.
- Küçük örneklemde yüzdeyi tek başına yorumlama; oyuncu sayısı, güven aralığı ve görüşme bulguları birlikte raporlanır.
- İlk ödeme hedefi, oynanış ve ücretsiz ilerleme doğrulanmadan başarı kapısı yapılmaz.
