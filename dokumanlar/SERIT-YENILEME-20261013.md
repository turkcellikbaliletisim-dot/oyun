# Saha şeritleri ve yükleme ipucu paneli — 13 Ekim 2026

Kaynak mobil dal: `claude/mobil-arayuz-skin-v2`, `acf6f30562ebb24268ae703429ca5a1cfc5f3b15`.
Görsel commit'i: `edb3d9c81fb529781407b32c3d6a7bd7e9e467cc`. Birleştirme talebi: [PR #4](https://github.com/turkcellikbaliletisim-dot/oyun/pull/4).

## Teslim edilen kapsam

| Dosya | Boyut | Durum |
|---|---|---|
| `native/skin/lane.png` | 1024×400 RGBA | Eski büyütülmüş atlas yerine bağımsız çizim, yuvarlak ve şeffaf dış kenar, koyu boş merkez. |
| `native/skin/lane_enemy.png` | 1024×400 RGBA | Aynı şekil ailesi, koyu bordo rakip sahası, şeffaf dış kenar. |
| `native/skin/loading_tip_panel.png` | 900×160 RGBA | Yeni yazısız ahşap/altın panel. Dosya hazır; uygulama içi yükleme akışı henüz bağlı değil. |

Üç yeni kahraman, üç rütbe rozeti, gerçek ses/müzik ve mevcut zamanlama/kart metni işleri bu kapsamda tamamlanmadı. PNG dosyaları dışında yalnız iki mevcut şerit çizim çağrısının kesit parametresi değişti; kurallar, ağ, hesap, kart konumları ve diğer görseller korunur.

## Üretim ve geometri

Her görsel ayrı Adobe Firefly üretimidir. Kaynak tuvalleri sırasıyla 2688×1536, 2704×1552 ve 2688×1536'dır. Adobe arka plan kaldırma ve renk düzeltmesi kullanıldı. Uçları orantılı tutan oyun-özel yatay üç-parça paketleme ile hedef ölçüye indirildi. Sade orta alanın en/boy oranı ayrı uyarlanır; hiçbir kaynak parça büyütülmez. Bu, tek bir eski atlasın büyütülmesi değildir.

Kesilmiş kaynaklar `serit-yenileme-kaynak/` içinde; hash, boyut, alfa, örnekleme oranı ve kesit kayıtları `serit-yenileme-kontrol.json` ve `native/skin/manifest_lane_refresh.json` içindedir. Bu JSON'lar ilk teknik paketleme aşamasının kaydıdır; sonraki oyun içi inceleme aşağıda ayrı kayıtlıdır.

Şeritlerin paketleme kesit sınırı 243 px'tir (`runtime_h3_caps`); iki oyun çağrısında 3 px ek iç güven payıyla **246 px** kullanılır. İpucu panelinin önerilen uç payı 117 px'tir. İki eski manifestte ilgili şerit kayıtları ve hash'leri güncellendi; önceki kayıtlar `previous_revision` içinde saklandı. Eski 114 dosyalık paket listesi değişmedi; ipucu paneli ek dosyadır.

## Renk kontrolündeki düzeltme

İlk kesimlerde dış kenar yeşil saçağı bulundu ve temizlendi. İlk renk tarayıcısı daha sonra `lane.png` içindeki 17 opak koyu yeşil pikseli de kalıntı saydı. Yakın görüntü bunların istenen İznik köşe süsü olduğunu gösterdi; bunlar silinmedi. Tarayıcı alfa sınırındaki renk taşmasını (sıfır tolerans) opak iç renk adaylarından ayıracak şekilde düzeltildi. İpucu panelindeki üç opak yeşil aday da köşe taşıdır. Aday koordinatları raporda saklanır. Test hatası gizlenmedi; yanlış pozitif değerlendirmesi görüntüye dayalı olarak düzeltildi.

## GitHub ve görüntü incelemesi

- [Görsel hazırlama](https://github.com/turkcellikbaliletisim-dot/oyun/actions/runs/38368694781): başarılı; boyutlar, dış alfa, opak merkez, açılabilirlik ve 114 dosya kapsamı doğrulandı.
- [Oyun kontrolleri](https://github.com/turkcellikbaliletisim-dot/oyun/actions/runs/38368860804): engine ve Godot başarılı. Önceki testler kaldırılmadı.
- [Godot/OpenGL ekranları](https://github.com/turkcellikbaliletisim-dot/oyun/actions/runs/38368860738): 56 PNG, JSON ve günlük. Test birleşimi `5e96e98ac4c5afa77031ad20df54df9e7162d26f`.
- Yeni üç dosya gerçek alfa üzerinde açılıp incelendi. 844×390 dolu saha ve 390×844 dikey maç çıktıları doğrudan incelendi; köşelerde opak dikdörtgen arka plan yok, iki şerit farklı renkli ve yazısızdır.
- 20 yatay senaryo için yerleşim raporunda 0 hata; mevcut düzen, dokunma, etkileşim ve skin kontrollerinde 0 hata. Özel dolu saha senaryoları yerleşim test verisidir, gerçek maç kaydı değildir.
- Son günlükte `ERROR:` / `SCRIPT ERROR` yok. Yaşam döngüsünde bir `GDScriptFunctionState` kapanış uyarısı ve sanal ekran V-Sync uyarısı sürüyor; bu çalışmada çözülmüş sayılmadı.

Salt okunur `scripts/check_lane_refresh.py` dosya/source hash'lerini, üç kaynaktan aynı çıktı piksellerinin yeniden üretilebilmesini, manifest eşleşmesini, şeffaflığı ve orijinal paket boyutlarını kontrol eder. Tek kullanımlık aktarma workflow'ları iş bitince kaldırıldı; aktarma geçmişi Actions/Git geçmişinde kalır. Son PR kontrolleri, yalnız bu üç görselin teknik/sınırlı ekran kabulünü destekler; bütün oyun sanat onayı veya fiziksel iPhone/Android testi değildir.
