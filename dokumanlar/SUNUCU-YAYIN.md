# Sunucuyu yayına alma (Fly.io)

Oyun internetsiz tamamen oynanır. Sunucu yalnızca dünya sıralaması, kodla arkadaş yarışı ve klasik kart düellosunun çevrimiçi maçları içindir.

1. Fly.io hesabı aç, `flyctl` kur ve `fly auth login` yap.
2. Depo kökünde: `fly launch --no-deploy --copy-config` (fly.toml hazır; uygulama adı boşsa değiştir).
3. Kalıcı disk: `fly volumes create destan_data --size 1 --region otp`.
4. `fly deploy`. Adres: `https://<uygulama-adı>.fly.dev`.
5. `fly.toml` içinde `APP_ORIGIN` satırını bu adresle aç ve tekrar `fly deploy`.
6. Oyunda ayarlar (dişli) → adres alanına `https://<uygulama-adı>.fly.dev` yaz → Bağlan. Mobil sürümde varsayılan adresi `native/client.json` içinden değiştirip APK'yı yeniden üret.

Uçlar: `/api/health`, `/api/session`, `/api/uga/score`, `/api/uga/board/N`, `/api/uga/race`, `/api/uga/race/KOD`, `/api/uga/race/KOD/result` ve mevcut kart düellosu uçları. Kayıt: `/data/state.json`.
