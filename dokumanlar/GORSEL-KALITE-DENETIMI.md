# Görsel kalite denetimi — 2026-10-13

Kaynak: `main` (`e336526ad35b0108e7623597c980049012cbe16c`). Beklenen 114 PNG mevcut; 14 OGG geçici ses mevcut. Gerçek cihaz ve görsel kalite kabul testi yapılmadı.

Gözle doğrulanan sorunlar: `icon_net_ok.png` ve `icon_net_bad.png` bağlantı simgesi yerine yeşil/kırmızı mücevher gösteriyor; eski `logo.png` küçük atlas kırpımından büyütülmüş. Bu üçü, bağımsız vektör Wi-Fi sembolleri ve mevcut yüksek çözünürlüklü `logo_wordmark.png` kaynağından küçültme ile düzeltilmeli. Geri kalan sekiz eski atlas prototipi inceleme bekliyor.

`otomatik/saatlik` dalının son Godot kontrolü başarısız: `native/integration.gd` satır 81, OGG akışında bulunmayan `.data` özelliğini okuyor. Diğer dala otomatik müdahale edilmedi.

Sıradaki görsel grubu: `background.png`, `background_land.png`, `card_back.png`. GitHub denetim kaydı yazıldıysa dosya değiştirilmeden saatlik kontroller tekrar yapılmalıdır.
