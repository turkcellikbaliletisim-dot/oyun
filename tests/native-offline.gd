extends SceneTree
# Sunucu olmadan (ulaşılamaz adres) uygulama çevrimdışı moda geçmeli ve oynanabilmeli.
const Offline = preload("res://native/offline.gd")
var failed = false

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func play_to_end(app, limit: int = 400) -> void:
	var guard = 0
	while app.room.state.status != "finished" and guard < limit:
		guard += 1
		var acts: Array = app.room.actions
		var pick = acts[acts.size() - 1]
		for a in acts:
			if a.type == "mulligan" or a.type == "scry" or a.type == "discard":
				pick = a
				break
			if a.type == "play":
				pick = a
				break
		if pick.type == "end":
			for a in acts:
				if a.type == "attack":
					pick = a
					break
		await app.mutate("matches/" + app.room.id + "/actions", {"version": app.room.version, "action": pick}, true)

func run() -> void:
	var dir = OS.get_environment("DESTAN_SESSION_DIR")
	DirAccess.make_dir_recursive_absolute(dir)
	var app = load("res://native/main.tscn").instantiate()
	root.add_child(app)
	app.address.text = "https://127.0.0.1:1"
	await app.connect_account()
	check(app.offline_mode, "Sunucu yokken çevrimdışı moda geçilmedi")
	check(not app.account.is_empty() and int(app.account.profile.gold) == 30, "Çevrimdışı hesap/giriş ödülü yok")
	check(app.account.has("league") and str(app.account.league) == "Kalfa", "Lig bilgisi eksik")
	# Yolculuk 1. bölüm
	await app.mutate("solo", {"chapterId": 1})
	check(not app.room.is_empty() and app.room.state != null, "Bölüm 1 başlatılamadı")
	await app.mutate("matches/" + app.room.id + "/actions", {"version": app.room.version, "action": {"type": "mulligan", "indices": []}}, true)
	await play_to_end(app)
	check(app.room.state.status == "finished", "Bölüm 1 bitmedi")
	await app.refresh()
	print("Bölüm 1 sonucu: kazanan=", app.room.state.winner, " ödüller=", app.account.profile.chapterRewards)
	# Maçı kapat
	var left = await app.api("matches/" + app.room.id + "/leave", HTTPClient.METHOD_POST)
	check(left.get("matchId") == null, "Maçtan çıkılamadı")
	app.accept_account(left)
	# Bot maçı starter deste ile
	await app.mutate("solo", {"chapterId": 0, "deck": app.data.decks.starter.cards})
	check(app.room.get("kind") == "bot", "Bot maçı başlamadı")
	var leave = await app.api("matches/" + app.room.id + "/leave", HTTPClient.METHOD_POST)
	app.accept_account(leave)
	# Sandık: ücretsiz paket yoksa 300 altın gerekir; altın ver ve aç
	app.offline_service.store.user.profile.gold = 900
	app.offline_service.store.user.profile.freePacks = 0
	await app.refresh()
	await app.mutate("collection/pack", {}, true)
	check(app.last_pack.size() == 5, "Paket 5 kart vermedi")
	check(int(app.account.profile.gold) == 600, "Paket altını düşmedi")
	# Çevrimiçi özellik hata vermeli, çökmemeli
	var room_try = await app.api("rooms", HTTPClient.METHOD_POST, {"deck": app.data.decks.starter.cards})
	check(room_try.has("error"), "Çevrimdışı arkadaş odası reddedilmedi")
	# Birleştirme modu ekranı
	app.open_tab("merge")
	check(app.view == "merge", "Birleştir ekranı açılmadı")
	app.merge_do("merge/buy")
	var mv = app.merge_call("merge")
	check(int(mv.state.gold) == 20, "Birleştir alımı altın düşürmedi")
	app.merge_do("merge/totem", {"id": 0})
	check(int(app.merge_call("merge").state.totem) == 0, "Totem seçilmedi")
	app.render()
	app.merge_do("merge/restart")
	app.open_tab("play")
	# Kalıcılık: yeni servis aynı dosyadan aynı hesabı okumalı
	var again = Offline.new(app.data, app.offline_save_path())
	check(again.store.user != null and again.store.user.id == app.account.id, "Çevrimdışı kayıt kalıcı değil")
	check(int(again.store.user.profile.gold) == 600, "Kayıtlı altın farklı")
	app.queue_free()
	await process_frame
	print("Native offline failures: ", 1 if failed else 0)
	quit(1 if failed else 0)
