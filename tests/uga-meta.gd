extends SceneTree
const Meta = preload("res://native/uga/uga_meta.gd")
const D = preload("res://native/uga/uga_data.gd")
var failed = false
func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
func _initialize() -> void:
	var dir = OS.get_environment("DESTAN_SESSION_DIR")
	if dir.is_empty():
		dir = "/tmp"
	DirAccess.make_dir_recursive_absolute(dir)
	var path = dir + "/uga-meta-test.json"
	DirAccess.remove_absolute(path)
	var m = Meta.new(path)
	check(m.p.deck.size() == 5 and m.hero_level("kilic") == 1 and m.hero_level("ejder_yavrusu") == 0, "başlangıç profili")
	# yükseltme
	check(not m.upgrade_hero("kilic"), "parça olmadan yükseltme yok")
	m.p.shards["kilic"] = 10
	var g = int(m.p.gold)
	var c = m.upgrade_cost("kilic")
	check(m.upgrade_hero("kilic") and m.hero_level("kilic") == 2 and int(m.p.gold) == g - c.gold, "yükseltme")
	check(m.mods().hero.kilic > 1.0, "seviye hasar çarpanı")
	# totem
	var dmg0 = m.mods().dmg
	check(m.upgrade_totem("savas") and m.mods().dmg > dmg0, "savaş totemi")
	# deste
	check(m.set_deck_slot(0, "mizrakci") and m.p.deck[0] == "mizrakci", "desteye kahraman")
	check(not m.set_deck_slot(1, "umay"), "kilitli kahraman desteye giremez")
	# koşu sonu
	var r = m.finish_run({"world": 0, "wave": 30, "won": true, "kills": 400, "bosses": 3, "merges": 40, "summons": 70, "best_star": 5, "time": 400})
	check(r.gold > 0 and r.diamond >= 25 and r.unlocked and int(m.p.world) == 1 and m.best_wave(0) == 30, "kazanılan koşu ödülü ve yeni dünya")
	check(r.chest == "rare" and int(m.p.chests.rare) == 1, "sandık ödülü")
	var o = m.open_chest("rare")
	check(o.gold > 0, "sandık açılır")
	check(m.open_chest("rare").is_empty(), "olmayan sandık açılmaz")
	# görevler
	m.ensure_missions()
	check(m.p.missions.list.size() == 3, "3 günlük görev")
	for i in range(3):
		m.p.missions.list[i].progress = 99999
	var d0 = int(m.p.diamond)
	check(m.claim_mission(0) and int(m.p.diamond) > d0 and not m.claim_mission(0), "görev ödülü bir kez")
	# günlük hediye
	check(m.daily_ready() and not m.claim_daily().is_empty() and not m.daily_ready(), "günlük hediye")
	# yeniden doğuş
	check(m.can_rebirth(), "1. dünya bitince yeniden doğuş")
	var gain = m.rebirth_gain()
	check(m.rebirth() and int(m.p.soul) == gain and int(m.p.world) == 0 and m.hero_level("kilic") == 1 and m.mods().dmg > 1.25, "yeniden doğuş")
	# çevrimdışı kazanç
	m.p.last_seen = 1000
	check(m.compute_offline(1000 + 3600 * 20) == 8 * m.offline_rate(), "çevrimdışı en çok 8 saat")
	# günün meydan okuması
	check(m.challenge_seed() == m.challenge_seed() and m.challenge_seed() > 0, "meydan okuma tohumu günlük sabit")
	var dd = int(m.p.diamond)
	check(m.finish_challenge(12) == 36 and int(m.p.diamond) == dd + 36 and m.challenge_done(), "meydan okuma ödülü")
	check(m.finish_challenge(20) == 0, "meydan okuma günde bir")
	# kalıcılık
	m.save()
	var again = Meta.new(path)
	check(int(again.p.soul) == gain and again.p.deck[0] == "mizrakci", "kayıt kalıcı")
	DirAccess.remove_absolute(path)
	print("UGA META " + ("FAIL" if failed else "OK"))
	quit(1 if failed else 0)
