extends RefCounted
# UGACHA tarzı koşu simülasyonu. Sabit adımlı (TICK) ve deterministiktir:
# aynı tohum + aynı komutlar = aynı sonuç. Çizim katmanı yalnızca durumu ve
# "events" listesini okur.

const D = preload("res://native/uga/uga_data.gd")

var seed_value: int = 1
var world: int = 0
var wave: int = 0
var t: float = 0.0
var gold: int = D.START_GOLD
var summon_cost: int = D.START_SUMMON_COST
var castle_hp: int = D.CASTLE_HP
var castle_max: int = D.CASTLE_HP
var slots: Array = []
var enemies: Array = []
var spawn_queue: Array = []
var spawn_timer: float = 0.0
var between: float = 2.0
var boss_timer: float = 0.0
var next_enemy_id: int = 1
var events: Array = []
var over: bool = false
var won_world: bool = false
var potions: Dictionary = {"rage": 2, "gold": 2, "freeze": 1, "heal": 1}
var rage_t: float = 0.0
var freeze_t: float = 0.0
var stats: Dictionary = {"kills": 0, "gold": 0, "merges": 0, "summons": 0, "bosses": 0, "damage": 0.0, "best_star": 1}
# Kalıcı (meta) çarpanlar.
var mods: Dictionary = {"dmg": 1.0, "speed": 1.0, "gold": 1.0, "hero": {}}
var err: String = ""
var deck: Array = ["kilic", "okcu", "buyucu", "kalkan", "kam"]
var run_levels: Dictionary = {}

func _init(seed_in: int = 1, world_in: int = 0, mods_in: Dictionary = {}, castle_bonus: int = 0, potion_bonus: int = 0, deck_in: Array = []) -> void:
	if deck_in.size() == 5:
		deck = deck_in.duplicate()
	seed_value = maxi(1, seed_in % 2147483646)
	world = clampi(world_in, 0, D.WORLDS.size() - 1)
	for k in mods_in:
		mods[k] = mods_in[k]
	castle_max = D.CASTLE_HP + castle_bonus
	castle_hp = castle_max
	for k in potions:
		potions[k] = int(potions[k]) + potion_bonus
	slots.resize(D.SLOTS)
	slots.fill(null)

# ---------- rastgelelik ----------

func rand_int() -> int:
	seed_value = (seed_value * 48271) % 2147483647
	return seed_value

func randf_() -> float:
	return float(rand_int() % 1000000) / 1000000.0

func pick(arr: Array):
	return arr[rand_int() % arr.size()]

# ---------- oyuncu komutları ----------

func fail(msg: String) -> bool:
	err = msg
	return false

func free_slot() -> int:
	for i in range(slots.size()):
		if slots[i] == null:
			return i
	return -1

func summon() -> bool:
	err = ""
	if over:
		return fail("Koşu bitti.")
	if gold < summon_cost:
		return fail("Altın yetmiyor.")
	var slot = free_slot()
	if slot < 0:
		return fail("Yuvalar dolu. Birleştir!")
	gold -= summon_cost
	summon_cost += 1
	slots[slot] = {"h": pick(deck), "s": 1, "cd": 0.3}
	stats.summons += 1
	events.append({"t": "summon", "slot": slot})
	return true

func can_merge(a: int, b: int) -> bool:
	if a == b or a < 0 or b < 0 or a >= slots.size() or b >= slots.size():
		return false
	var x = slots[a]
	var y = slots[b]
	return x != null and y != null and x.h == y.h and int(x.s) == int(y.s) and int(x.s) < D.MAX_STARS

func merge(from: int, to: int) -> bool:
	err = ""
	if over:
		return fail("Koşu bitti.")
	if not can_merge(from, to):
		return fail("Yalnızca aynı kahraman ve aynı yıldız birleşir.")
	var stars = int(slots[to].s) + 1
	var hero = pick(deck)
	if stars >= 4 and randf_() < D.LEGEND_CHANCE:
		hero = "ejder_yavrusu"
	slots[to] = {"h": hero, "s": stars, "cd": 0.4}
	slots[from] = null
	stats.merges += 1
	stats.best_star = maxi(int(stats.best_star), stars)
	events.append({"t": "merge", "slot": to, "from": from, "stars": stars})
	return true

func move(from: int, to: int) -> bool:
	# Boş yuvaya taşı ya da yer değiştir; birleşebiliyorsa birleştir.
	if can_merge(from, to):
		return merge(from, to)
	if from == to or from < 0 or to < 0 or from >= slots.size() or to >= slots.size() or slots[from] == null:
		return fail("Geçersiz hamle.")
	var tmp = slots[to]
	slots[to] = slots[from]
	slots[from] = tmp
	return true

func power_cost(h: String) -> int:
	return 40 * int(pow(2, int(run_levels.get(h, 0))))

func power_up(h: String) -> bool:
	err = ""
	if over or not deck.has(h):
		return fail("Bu kahraman takımda değil.")
	if int(run_levels.get(h, 0)) >= 5:
		return fail("En yüksek güçte.")
	var cost = power_cost(h)
	if gold < cost:
		return fail("Altın yetmiyor.")
	gold -= cost
	run_levels[h] = int(run_levels.get(h, 0)) + 1
	events.append({"t": "power", "hero": h, "level": run_levels[h]})
	return true

func sell(slot: int) -> bool:
	if over or slot < 0 or slot >= slots.size() or slots[slot] == null:
		return fail("Satılacak kart yok.")
	var refund = int(5 * pow(2, int(slots[slot].s) - 1))
	gold += refund
	slots[slot] = null
	events.append({"t": "sell", "slot": slot, "gold": refund})
	return true

func use_potion(kind: String) -> bool:
	err = ""
	if over or int(potions.get(kind, 0)) <= 0:
		return fail("İksir kalmadı.")
	potions[kind] = int(potions[kind]) - 1
	match kind:
		"rage":
			rage_t = 10.0
		"gold":
			gold += 60
		"freeze":
			freeze_t = 5.0
		"heal":
			castle_hp = mini(castle_max, castle_hp + 8)
	events.append({"t": "potion", "kind": kind})
	return true

# ---------- dalgalar ----------

func is_boss_wave(n: int) -> bool:
	return n % 10 == 0

func wave_hp(n: int) -> float:
	return 44.0 * pow(1.135, n - 1) * float(D.WORLDS[world].hp)

func start_wave() -> void:
	wave += 1
	var w = D.WORLDS[world]
	spawn_queue = []
	if is_boss_wave(wave):
		var b = D.BOSSES[(world * 2 + wave / 10 - 1) % D.BOSSES.size()]
		spawn_queue.append({"kind": "boss", "boss_name": b.name, "art": b.art, "hp": wave_hp(wave) * 55.0, "speed": 0.028, "boss": true, "gold": 30 + wave * 2, "leak": 10, "armor": 0.15, "regen": 0.0})
		for i in range(6):
			var k = w.enemies[i % w.enemies.size()]
			spawn_queue.append(enemy_spec(k, wave))
		boss_timer = 50.0
		events.append({"t": "boss", "name": b.name, "art": b.art})
	else:
		var count = 8 + mini(wave, 22)
		for i in range(count):
			spawn_queue.append(enemy_spec(pick(w.enemies), wave))
	spawn_timer = 0.0
	events.append({"t": "wave", "n": wave})

func enemy_spec(kind: String, n: int) -> Dictionary:
	var e = D.ENEMIES[kind]
	return {"kind": kind, "art": e.art, "hp": wave_hp(n) * float(e.hp), "speed": float(e.speed) * (1.0 + 0.004 * n), "boss": false, "gold": 2 + n / 6, "leak": 1, "armor": float(e.get("armor", 0.0)), "regen": float(e.get("regen", 0.0))}

func spawn(spec: Dictionary) -> void:
	var e = spec.duplicate()
	e["id"] = next_enemy_id
	next_enemy_id += 1
	e["max"] = e.hp
	e["d"] = 0.0
	e["slow_t"] = 0.0
	e["slow_f"] = 0.0
	e["stun_t"] = 0.0
	e["poison"] = 0.0
	e["poison_t"] = 0.0
	enemies.append(e)

# ---------- adım ----------

func hero_damage(slot: int) -> float:
	var c = slots[slot]
	var h = D.HEROES[c.h]
	var dmg = float(h.dmg) * D.STAR_DMG[int(c.s) - 1] * float(mods.dmg) * float(mods.hero.get(c.h, 1.0)) * (1.0 + 0.25 * int(run_levels.get(c.h, 0)))
	# Umay komşu desteği
	var col = slot % D.COLS
	for n in [slot - 1, slot + 1, slot - D.COLS, slot + D.COLS]:
		if n < 0 or n >= slots.size() or slots[n] == null:
			continue
		if (n == slot - 1 and col == 0) or (n == slot + 1 and col == D.COLS - 1):
			continue
		if slots[n].h == "umay":
			dmg *= 1.0 + float(D.HEROES.umay.aura)
	return dmg

func targets_front() -> Array:
	# En öndeki (kapıya en yakın) düşmanlar önce.
	var arr = enemies.filter(func(e): return float(e.hp) > 0.0 and float(e.d) > 0.05)
	arr.sort_custom(func(a, b): return float(a.d) > float(b.d) or (float(a.d) == float(b.d) and int(a.id) < int(b.id)))
	return arr

func hit(e: Dictionary, dmg: float, slot: int, crit: bool = false) -> void:
	if float(e.hp) <= 0.0:
		return
	if slot >= 0:
		dmg *= 1.0 - float(e.get("armor", 0.0))
	var real = minf(dmg, float(e.hp))
	e.hp = float(e.hp) - dmg
	stats.damage = float(stats.damage) + real
	events.append({"t": "hit", "enemy": e.id, "dmg": int(round(dmg)), "crit": crit, "slot": slot, "d": float(e.d)})
	if float(e.hp) <= 0.0:
		var g = int(round(int(e.gold) * float(mods.gold)))
		if slot >= 0 and slots[slot] != null and slots[slot].h == "umay":
			g += int(D.HEROES.umay.kill_gold)
		gold += g
		stats.gold += g
		stats.kills += 1
		if e.boss:
			stats.bosses += 1
		events.append({"t": "die", "enemy": e.id, "gold": g, "boss": e.boss, "d": float(e.d)})

var _front: Array = []

func fire(slot: int) -> void:
	var c = slots[slot]
	var h = D.HEROES[c.h]
	while not _front.is_empty() and float(_front[0].hp) <= 0.0:
		_front.pop_front()
	var front = _front.filter(func(e): return float(e.hp) > 0.0) if _front.size() < 8 else _front.slice(0, 8).filter(func(e): return float(e.hp) > 0.0)
	if front.is_empty():
		return
	var dmg = hero_damage(slot)
	var target = front[0]
	var crit = false
	if h.has("crit") and randf_() < float(h.crit):
		dmg *= 2.0
		crit = true
	var d0 = dmg
	if h.has("boss_bonus") and target.boss:
		d0 *= 1.0 + float(h.boss_bonus)
	events.append({"t": "shot", "slot": slot, "enemy": target.id, "proj": h.proj, "d": float(target.d), "h": c.h})
	hit(target, d0, slot, crit)
	if h.has("slow"):
		target.slow_t = 2.0
		target.slow_f = maxf(float(target.slow_f), float(h.slow))
	if h.has("stun") and randf_() < float(h.stun) and not target.boss:
		target.stun_t = 1.0
	if h.has("poison"):
		target.poison = float(h.poison) * D.STAR_DMG[int(c.s) - 1] * float(mods.dmg)
		target.poison_t = 3.0
	if h.has("burn"):
		target.poison = maxf(float(target.poison), float(h.burn) * D.STAR_DMG[int(c.s) - 1] * float(mods.dmg))
		target.poison_t = 3.0
	var extra = 0
	if h.has("chain"):
		extra = int(h.chain)
	if h.has("pierce"):
		extra = int(h.pierce) - 1
	if h.has("splash"):
		extra = int(h.splash) - 1
	for i in range(1, mini(extra + 1, front.size())):
		var factor = 0.6 if h.has("chain") else 1.0
		hit(front[i], dmg * factor, slot)

func step() -> void:
	if over:
		return
	t += D.TICK
	rage_t = maxf(0.0, rage_t - D.TICK)
	freeze_t = maxf(0.0, freeze_t - D.TICK)
	# dalga akışı
	if spawn_queue.is_empty() and enemies.is_empty():
		between -= D.TICK
		if between <= 0.0:
			if wave > 0:
				var bonus = int(round((10 + 2 * wave) * float(mods.gold)))
				gold += bonus
				events.append({"t": "clear", "n": wave, "gold": bonus})
				if wave >= D.WAVES_PER_WORLD:
					won_world = true
					over = true
					events.append({"t": "end", "won": true})
					return
			start_wave()
			between = 2.5
	if not spawn_queue.is_empty():
		spawn_timer -= D.TICK
		if spawn_timer <= 0.0:
			spawn(spawn_queue.pop_front())
			spawn_timer = 0.55
	if boss_timer > 0.0:
		boss_timer -= D.TICK
		if boss_timer <= 0.0:
			for e in enemies:
				if e.boss and float(e.hp) > 0.0:
					castle_hp = 0
					events.append({"t": "boss_timeout"})
	# hareket ve durum etkileri
	for e in enemies:
		if float(e.poison_t) > 0.0:
			e.poison_t = float(e.poison_t) - D.TICK
			hit(e, float(e.poison) * D.TICK, -1)
		if float(e.hp) <= 0.0:
			continue
		if float(e.get("regen", 0.0)) > 0.0:
			e.hp = minf(float(e.max), float(e.hp) + float(e.max) * float(e.regen) * D.TICK)
		e.slow_t = maxf(0.0, float(e.slow_t) - D.TICK)
		if float(e.slow_t) <= 0.0:
			e.slow_f = 0.0
		if float(e.stun_t) > 0.0:
			e.stun_t = float(e.stun_t) - D.TICK
			continue
		if freeze_t > 0.0:
			continue
		e.d = float(e.d) + float(e.speed) * (1.0 - float(e.slow_f)) * D.TICK
		if float(e.d) >= 1.0:
			castle_hp -= int(e.leak)
			e.hp = 0.0
			events.append({"t": "leak", "enemy": e.id, "dmg": int(e.leak)})
	enemies = enemies.filter(func(e): return float(e.hp) > 0.0)
	# kahramanlar saldırır
	var speed = float(mods.speed) * (2.0 if rage_t > 0.0 else 1.0)
	_front = targets_front()
	for i in range(slots.size()):
		var c = slots[i]
		if c == null:
			continue
		c.cd = float(c.cd) - D.TICK * speed * D.STAR_SPEED[int(c.s) - 1]
		if float(c.cd) <= 0.0 and not enemies.is_empty():
			fire(i)
			c.cd = float(D.HEROES[c.h].interval)
	enemies = enemies.filter(func(e): return float(e.hp) > 0.0)
	if castle_hp <= 0:
		castle_hp = 0
		over = true
		events.append({"t": "end", "won": false})

func advance(seconds: float) -> void:
	var n = int(round(seconds / D.TICK))
	for i in range(n):
		step()
		if over:
			return

func take_events() -> Array:
	var out = events
	events = []
	return out

# ---------- otomatik oyuncu (test/dengeleme ve "otomatik" düğmesi) ----------

func auto_play_once() -> void:
	# Önce birleştir, sonra çağır.
	for a in range(slots.size()):
		for b in range(a + 1, slots.size()):
			if can_merge(a, b):
				merge(a, b)
				return
	if gold >= summon_cost and free_slot() >= 0:
		summon()
		return
	# tahta doluysa en çok kartı olan kahramanı güçlendir
	var counts = {}
	for c in slots:
		if c != null and deck.has(c.h):
			counts[c.h] = int(counts.get(c.h, 0)) + 1
	var best = ""
	for h in counts:
		if best == "" or int(counts[h]) > int(counts[best]):
			best = h
	if best != "" and gold >= power_cost(best) and int(run_levels.get(best, 0)) < 5:
		power_up(best)

func result() -> Dictionary:
	return {"world": world, "wave": wave, "won": won_world, "kills": stats.kills, "bosses": stats.bosses, "merges": stats.merges, "summons": stats.summons, "best_star": stats.best_star, "time": t}
