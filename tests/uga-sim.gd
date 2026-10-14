extends SceneTree
# UGACHA modu simülasyon kuralları.
const Sim = preload("res://native/uga/uga_sim.gd")
const D = preload("res://native/uga/uga_data.gd")
var failed = false
func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
func _initialize() -> void:
	var s = Sim.new(5, 0)
	check(s.gold == D.START_GOLD and s.castle_hp == D.CASTLE_HP, "başlangıç değerleri")
	check(s.summon() and s.gold == D.START_GOLD - 10 and s.summon_cost == 11, "çağır altın düşer, maliyet artar")
	var first = s.slots.find(s.slots.filter(func(c): return c != null)[0])
	check(s.deck.has(s.slots[first].h) and int(s.slots[first].s) == 1, "çağrılan kart desteden ve 1 yıldız")
	# birleştirme kuralı
	s.slots[3] = {"h": "okcu", "s": 2, "cd": 0}
	s.slots[4] = {"h": "okcu", "s": 2, "cd": 0}
	s.slots[5] = {"h": "kilic", "s": 2, "cd": 0}
	check(not s.merge(3, 5), "farklı kahraman birleşmez")
	check(s.merge(3, 4) and s.slots[3] == null and int(s.slots[4].s) == 3, "aynı kahraman+yıldız birleşir, yıldız artar")
	s.slots[6] = {"h": "okcu", "s": 6, "cd": 0}
	s.slots[7] = {"h": "okcu", "s": 6, "cd": 0}
	check(not s.can_merge(6, 7), "6 yıldız birleşmez")
	check(s.move(5, 8) and s.slots[8].h == "kilic" and s.slots[5] == null, "boş yuvaya taşıma")
	# koşu içi güçlendirme
	var pw = Sim.new(4, 0)
	pw.gold = 1000
	pw.slots[0] = {"h": pw.deck[0], "s": 1, "cd": 0}
	var before = pw.hero_damage(0)
	check(pw.power_up(pw.deck[0]) and pw.gold == 960 and pw.power_cost(pw.deck[0]) == 80, "güçlendirme altın düşer, maliyet ikiye katlanır")
	check(pw.hero_damage(0) > before * 1.2, "güçlendirme hasarı artırır")
	check(not pw.power_up("ejder_yavrusu"), "takımda olmayan güçlendirilemez")
	var sl = Sim.new(4, 0)
	sl.slots[0] = {"h": "okcu", "s": 3, "cd": 0}
	var g1 = sl.gold
	check(sl.sell(0) and sl.gold == g1 + 20 and sl.slots[0] == null, "kart satışı")
	# dolu tahta
	var f = Sim.new(9, 0)
	f.gold = 10000
	for i in range(D.SLOTS):
		f.summon()
	check(not f.summon() and f.err != "", "dolu tahtada çağrı reddedilir")
	# iksirler
	var p = Sim.new(9, 0)
	var g0 = p.gold
	check(p.use_potion("gold") and p.gold == g0 + 60, "altın iksiri")
	check(p.use_potion("freeze") and p.freeze_t > 0, "buz iksiri")
	check(not p.use_potion("freeze"), "iksir sayısı sınırlı")
	# deterministik
	var a = Sim.new(77, 1)
	var b = Sim.new(77, 1)
	for i in range(200):
		a.advance(0.5); a.auto_play_once(); a.take_events()
		b.advance(0.5); b.auto_play_once(); b.take_events()
	check(a.wave == b.wave and a.gold == b.gold and a.castle_hp == b.castle_hp and str(a.slots) == str(b.slots), "aynı tohum aynı sonuç")
	# boş tahtada düşmanlar kaleyi yıkar
	var lose = Sim.new(1, 0)
	lose.advance(400)
	check(lose.over and not lose.won_world and lose.castle_hp == 0, "savunmasız kale düşer")
	# otomatik oyuncu 1. dünyada ilerler, boss görür
	var auto = Sim.new(3, 0)
	var boss_seen = false
	var kills = 0
	while not auto.over and auto.t < 900:
		auto.advance(0.5)
		auto.auto_play_once()
		auto.auto_play_once()
		for ev in auto.take_events():
			if ev.t == "boss":
				boss_seen = true
	check(auto.wave >= 15 and boss_seen and auto.stats.kills > 100, "otomatik oyuncu 15+ dalga ve boss: dalga %d" % auto.wave)
	# zor dünya güçsüz takımla erken biter
	var hard = Sim.new(3, 4)
	while not hard.over and hard.t < 900:
		hard.advance(0.5); hard.auto_play_once(); hard.auto_play_once(); hard.take_events()
	check(hard.over and hard.wave < 10, "5. dünya güçsüz takımla zor: dalga %d" % hard.wave)
	print("UGA SIM " + ("FAIL" if failed else "OK"))
	quit(1 if failed else 0)
