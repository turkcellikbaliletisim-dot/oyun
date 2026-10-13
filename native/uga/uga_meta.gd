extends RefCounted
# Kalıcı ilerleme: para birimleri, kahraman seviyeleri, deste, totemler,
# yeniden doğuş, sandıklar, günlük görevler ve çevrimdışı kazanç.
# Cihazda JSON olarak saklanır; çevrimiçi senkron ileride eklenir.

const D = preload("res://native/uga/uga_data.gd")

const TOTEMS = {
	"savas": {"name": "Savaş Totemi", "text": "+%25 hasar / seviye", "art": "totem_1"},
	"hiz": {"name": "Rüzgâr Totemi", "text": "+%6 saldırı hızı / seviye", "art": "totem_3"},
	"altin": {"name": "Bereket Totemi", "text": "+%15 koşu altını / seviye", "art": "totem_2"},
	"kale": {"name": "Kale Totemi", "text": "+3 kale canı / seviye", "art": "totem_4"},
}
const MAX_HERO_LEVEL = 15
const MAX_TOTEM_LEVEL = 20
const MISSIONS = [
	{"id": "kill", "text": "%d düşman yen", "goal": 300, "reward": 15},
	{"id": "merge", "text": "%d kez birleştir", "goal": 30, "reward": 15},
	{"id": "summon", "text": "%d kahraman çağır", "goal": 60, "reward": 10},
	{"id": "wave", "text": "Bir koşuda %d. dalgaya ulaş", "goal": 15, "reward": 20},
	{"id": "boss", "text": "%d boss yen", "goal": 2, "reward": 20},
	{"id": "runs", "text": "%d koşu oyna", "goal": 3, "reward": 10},
]

var path: String = "user://destan-uga.json"
var p: Dictionary = {}
var err: String = ""
var rng := RandomNumberGenerator.new()

func _init(save_path: String = "") -> void:
	rng.randomize()
	if save_path != "":
		path = save_path
	load_profile()

static func default_path() -> String:
	var dir = OS.get_environment("DESTAN_SESSION_DIR")
	return dir.path_join("destan-uga.json") if not dir.is_empty() else "user://destan-uga.json"

func fresh() -> Dictionary:
	var heroes = {}
	for h in D.START_HEROES:
		heroes[h] = 1
	return {"version": 1, "gold": 200, "diamond": 50, "soul": 0, "rebirths": 0, "shards": {}, "heroes": heroes,
		"deck": D.DEFAULT_DECK.duplicate(), "world": 0, "best": {}, "totems": {"savas": 0, "hiz": 0, "altin": 0, "kale": 0},
		"chests": {"common": 1, "rare": 0, "epic": 0}, "missions": {"day": "", "list": []}, "daily": "", "last_seen": 0,
		"pending_offline": 0, "runs": 0, "tutorial": false, "seed": rng.randi_range(1, 2000000000)}

func load_profile() -> void:
	p = fresh()
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary and parsed.get("version") != null:
			var base = fresh()
			for k in base:
				if parsed.has(k):
					base[k] = parsed[k]
			p = intify(base)
	if p.deck.size() != 5:
		p.deck = D.DEFAULT_DECK.duplicate()

static func intify(v):
	if v is Dictionary:
		var out = {}
		for k in v:
			out[k] = intify(v[k])
		return out
	if v is Array:
		return v.map(func(x): return intify(x))
	if v is float and v == floor(v) and absf(v) < 9.0e15:
		return int(v)
	return v

func save() -> void:
	p.last_seen = int(Time.get_unix_time_from_system())
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(p))
		f.close()

func fail(msg: String) -> bool:
	err = msg
	return false

func today() -> String:
	return Time.get_date_string_from_system()

# ---------- güç ----------

func hero_level(h: String) -> int:
	return int(p.heroes.get(h, 0))

func mods() -> Dictionary:
	var hero = {}
	for h in p.heroes:
		hero[h] = 1.0 + 0.12 * (int(p.heroes[h]) - 1)
	hero["ejder_yavrusu"] = 1.0 + 0.05 * int(p.rebirths)
	var t = p.totems
	return {"dmg": (1.0 + 0.25 * int(t.savas)) * (1.0 + 0.05 * int(p.soul)), "speed": 1.0 + 0.06 * int(t.hiz),
		"gold": 1.0 + 0.15 * int(t.altin), "hero": hero}

func castle_bonus() -> int:
	return 3 * int(p.totems.kale)

func power() -> int:
	# Arayüzde gösterilen tek sayı.
	var m = mods()
	var sum = 0.0
	for h in p.deck:
		sum += float(D.HEROES[h].dmg) / float(D.HEROES[h].interval) * float(m.hero.get(h, 1.0))
	return int(round(sum * float(m.dmg) * float(m.speed) * 10.0))

# ---------- kahramanlar ve deste ----------

func upgrade_cost(h: String) -> Dictionary:
	var lv = hero_level(h)
	return {"gold": int(round(60 * pow(lv, 1.6))), "shards": 2 * lv + 2}

func upgrade_hero(h: String) -> bool:
	err = ""
	var lv = hero_level(h)
	if lv <= 0:
		return fail("Bu kahraman henüz açılmadı.")
	if lv >= MAX_HERO_LEVEL:
		return fail("En yüksek seviyede.")
	var c = upgrade_cost(h)
	if int(p.gold) < c.gold:
		return fail("Altın yetmiyor.")
	if int(p.shards.get(h, 0)) < c.shards:
		return fail("Kart parçası yetmiyor.")
	p.gold = int(p.gold) - c.gold
	p.shards[h] = int(p.shards[h]) - c.shards
	p.heroes[h] = lv + 1
	save()
	return true

func set_deck_slot(index: int, h: String) -> bool:
	err = ""
	if index < 0 or index >= 5 or hero_level(h) <= 0 or h == "ejder_yavrusu":
		return fail("Bu kahraman desteye eklenemez.")
	var at = p.deck.find(h)
	if at >= 0:
		p.deck[at] = p.deck[index]
	p.deck[index] = h
	save()
	return true

# ---------- totemler ----------

func totem_cost(id: String) -> int:
	return 20 + 15 * int(p.totems[id])

func upgrade_totem(id: String) -> bool:
	err = ""
	if not TOTEMS.has(id):
		return fail("Totem yok.")
	if int(p.totems[id]) >= MAX_TOTEM_LEVEL:
		return fail("Totem en yüksek seviyede.")
	var c = totem_cost(id)
	if int(p.diamond) < c:
		return fail("Elmas yetmiyor.")
	p.diamond = int(p.diamond) - c
	p.totems[id] = int(p.totems[id]) + 1
	save()
	return true

# ---------- koşu ----------

func best_wave(world: int) -> int:
	return int(p.best.get(str(world), 0))

func run_seed() -> int:
	p.seed = (int(p.seed) * 48271) % 2147483647
	return int(p.seed)

func finish_run(r: Dictionary) -> Dictionary:
	var world = int(r.world)
	var wave = int(r.wave)
	var cleared = wave - (0 if r.won else 1)
	var gold = int(round(12 * maxi(cleared, 0) * (world + 1) * (1.0 + 0.15 * int(p.totems.altin))))
	var diamond = cleared / 5 + int(r.bosses) * 4 + (25 if r.won else 0)
	var shards = {}
	var pool = p.heroes.keys().filter(func(h): return h != "ejder_yavrusu")
	for i in range(maxi(1, cleared / 3)):
		var h = pool[rng.randi() % pool.size()]
		shards[h] = int(shards.get(h, 0)) + 1 + world
	var chest = ""
	if r.won:
		chest = "epic" if world >= 2 else "rare"
	elif int(r.bosses) > 0:
		chest = "common"
	p.gold = int(p.gold) + gold
	p.diamond = int(p.diamond) + diamond
	for h in shards:
		p.shards[h] = int(p.shards.get(h, 0)) + int(shards[h])
	if chest != "":
		p.chests[chest] = int(p.chests[chest]) + 1
	var record = wave > best_wave(world)
	if record:
		p.best[str(world)] = wave
	var unlocked = false
	if r.won and world + 1 < D.WORLDS.size() and int(p.world) <= world:
		p.world = world + 1
		unlocked = true
	p.runs = int(p.runs) + 1
	ensure_missions()
	mission_add("kill", int(r.kills))
	mission_add("merge", int(r.merges))
	mission_add("summon", int(r.summons))
	mission_add("boss", int(r.bosses))
	mission_add("runs", 1)
	mission_max("wave", wave)
	save()
	return {"gold": gold, "diamond": diamond, "shards": shards, "chest": chest, "record": record, "unlocked": unlocked}

# ---------- sandıklar ----------

func open_chest(kind: String) -> Dictionary:
	err = ""
	if int(p.chests.get(kind, 0)) <= 0:
		fail("Sandık yok.")
		return {}
	p.chests[kind] = int(p.chests[kind]) - 1
	var spec = {"common": [150, 6, 0, 0.0], "rare": [500, 16, 10, 0.35], "epic": [1500, 40, 40, 1.0]}[kind]
	var gold = int(spec[0] * (1.0 + 0.1 * int(p.world)))
	var out = {"gold": gold, "diamond": int(spec[2]), "shards": {}, "hero": ""}
	p.gold = int(p.gold) + gold
	p.diamond = int(p.diamond) + int(spec[2])
	var locked = D.SUMMON_POOL.filter(func(h): return hero_level(h) <= 0)
	if not locked.is_empty() and rng.randf() < float(spec[3]):
		var h = locked[rng.randi() % locked.size()]
		p.heroes[h] = 1
		out.hero = h
	var pool = p.heroes.keys().filter(func(h): return h != "ejder_yavrusu")
	for i in range(3):
		var h = pool[rng.randi() % pool.size()]
		var n = int(spec[1]) / 3
		out.shards[h] = int(out.shards.get(h, 0)) + n
		p.shards[h] = int(p.shards.get(h, 0)) + n
	save()
	return out

func buy_chest(kind: String) -> bool:
	var cost = {"common": 30, "rare": 90, "epic": 250}
	if int(p.diamond) < int(cost[kind]):
		return fail("Elmas yetmiyor.")
	p.diamond = int(p.diamond) - int(cost[kind])
	p.chests[kind] = int(p.chests[kind]) + 1
	save()
	return true

# ---------- yeniden doğuş ----------

func rebirth_gain() -> int:
	var total = 0
	for k in p.best:
		total += int(p.best[k])
	return total / 10

func can_rebirth() -> bool:
	return best_wave(0) >= D.WAVES_PER_WORLD

func rebirth() -> bool:
	err = ""
	if not can_rebirth():
		return fail("Yeniden doğuş için 1. dünyayı bitir.")
	var gain = rebirth_gain()
	p.soul = int(p.soul) + gain
	p.rebirths = int(p.rebirths) + 1
	p.gold = 200
	p.world = 0
	p.best = {}
	for h in p.heroes:
		p.heroes[h] = 1
	save()
	return true

# ---------- günlük ----------

func ensure_missions() -> void:
	if p.missions.day == today() and p.missions.list.size() == 3:
		return
	var ids = MISSIONS.map(func(m): return m.id)
	var picked = []
	var day_seed = today().hash()
	for i in range(3):
		var id = ids[abs(day_seed + i * 7919) % ids.size()]
		while picked.has(id):
			id = ids[(ids.find(id) + 1) % ids.size()]
		picked.append(id)
	p.missions = {"day": today(), "list": picked.map(func(id): return {"id": id, "progress": 0, "claimed": false})}

func mission_spec(id: String) -> Dictionary:
	for m in MISSIONS:
		if m.id == id:
			return m
	return {}

func mission_add(id: String, n: int) -> void:
	for m in p.missions.list:
		if m.id == id:
			m.progress = int(m.progress) + n

func mission_max(id: String, n: int) -> void:
	for m in p.missions.list:
		if m.id == id:
			m.progress = maxi(int(m.progress), n)

func claim_mission(i: int) -> bool:
	err = ""
	ensure_missions()
	if i < 0 or i >= p.missions.list.size():
		return fail("Görev yok.")
	var m = p.missions.list[i]
	var spec = mission_spec(m.id)
	if m.claimed or int(m.progress) < int(spec.goal):
		return fail("Görev henüz tamamlanmadı.")
	m.claimed = true
	p.diamond = int(p.diamond) + int(spec.reward)
	save()
	return true

func daily_ready() -> bool:
	return p.daily != today()

func claim_daily() -> Dictionary:
	if not daily_ready():
		fail("Bugünün hediyesi alındı.")
		return {}
	p.daily = today()
	var out = {"diamond": 20, "gold": 100 + 50 * int(p.world), "chest": "common"}
	p.diamond = int(p.diamond) + out.diamond
	p.gold = int(p.gold) + out.gold
	p.chests.common = int(p.chests.common) + 1
	save()
	return out

# ---------- çevrimdışı kazanç ----------

func offline_rate() -> int:
	# Saatlik altın: toplam en iyi dalga x 6.
	var total = 0
	for k in p.best:
		total += int(p.best[k])
	return 20 + total * 6

func compute_offline(now: int = -1) -> int:
	if now < 0:
		now = int(Time.get_unix_time_from_system())
	if int(p.last_seen) <= 0:
		return 0
	var hours = clampf(float(now - int(p.last_seen)) / 3600.0, 0.0, 8.0)
	return int(hours * offline_rate())

func collect_offline(now: int = -1) -> int:
	var g = compute_offline(now)
	p.gold = int(p.gold) + g
	save()
	return g
