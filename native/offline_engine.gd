extends RefCounted
# Kural motoru: oyun/engine.js + oyun/bot.js dosyalarının GDScript karşılığı.
# Çevrimdışı modda sunucu yerine istemcide çalışır. Davranış JS ile birebir
# aynı olmalıdır (tests/offline-parity.js bunu çapraz doğrular).

const RULE_VERSION = "0.2"
const TURN_LIMIT = 40

var cards: Dictionary = {}
var err: String = ""
var rng := RandomNumberGenerator.new()

func _init(card_list: Array) -> void:
	rng.randomize()
	for c in card_list:
		cards[int(c.id)] = c

# ---------- yardımcılar ----------

func card(id) -> Dictionary:
	return cards[int(id)]

func rule(ok: bool, message: String) -> bool:
	if not ok and err.is_empty():
		err = message
	return ok

func is_int(v) -> bool:
	return typeof(v) == TYPE_INT or (typeof(v) == TYPE_FLOAT and v == floorf(v))

func note(s: Dictionary, message: String) -> void:
	s.log.append(message)
	if s.log.size() > 100:
		s.log.pop_front()

func rnd(s: Dictionary) -> float:
	if s.has("entropy"):
		if not rule(int(s.entropyIndex) < s.entropy.size(), "Maç rastgelelik kaydı tükendi."):
			return 0.0
		var n = s.entropy[int(s.entropyIndex)]
		s.entropyIndex = int(s.entropyIndex) + 1
		return float(n) / 4294967296.0
	return rng.randf()

func shuffle(s: Dictionary, list: Array) -> void:
	var i = list.size() - 1
	while i > 0:
		var j = int(floor(rnd(s) * (i + 1)))
		var tmp = list[i]
		list[i] = list[j]
		list[j] = tmp
		i -= 1

func validate_deck(deck) -> bool:
	if not rule(deck is Array and deck.size() == 20, "Deste tam 20 kart olmalı."):
		return false
	var counts = {}
	for raw in deck:
		if not rule(is_int(raw) and cards.has(int(raw)), "Bilinmeyen kart."):
			return false
		var id = int(raw)
		counts[id] = int(counts.get(id, 0)) + 1
		var limit = 1 if card(id).rarity == "legendary" else 2
		if not rule(counts[id] <= limit, "%s: kopya sınırı aşıldı." % card(id).name):
			return false
	return true

func int_array(list) -> Array:
	var out = []
	for v in list:
		out.append(int(v))
	return out

func create_game(opts: Dictionary) -> Dictionary:
	err = ""
	var decks: Array = opts.decks
	if not rule(decks.size() == 2, "İki deste gerekir."):
		return {}
	for d in decks:
		if not validate_deck(d):
			return {}
	var s = {
		"version": RULE_VERSION, "seed": int(opts.get("seed", 0)), "nextUid": 1,
		"status": "mulligan", "active": 0, "first": 0, "turn": 0, "phase": "main",
		"winner": null, "reason": null, "pending": null, "log": [], "history": [],
		"players": [],
	}
	var initial = {"decks": [int_array(decks[0]), int_array(decks[1])], "seed": int(opts.get("seed", 0))}
	if opts.has("entropy") and opts.entropy != null:
		s["entropy"] = int_array(opts.entropy)
		s["entropyIndex"] = 0
		initial["entropy"] = int_array(opts.entropy)
	for deck in decks:
		s.players.append({"hp": 20, "energy": 0, "maxEnergy": 0, "turns": 0,
			"deck": int_array(deck), "hand": [], "board": [], "traps": [], "grave": [], "half": false,
			"stats": {"cardPlays": {}, "attacks": 0, "energySpent": 0}, "mulliganPinned": []})
	var opening = opts.get("opening", null)
	var pinned = opts.get("pinned", null)
	if opening != null:
		initial["opening"] = [int_array(opening[0]), int_array(opening[1])]
	if pinned != null:
		initial["pinned"] = [int_array(pinned[0]), int_array(pinned[1])]
	if opts.has("first") and opts.first != null:
		initial["first"] = int(opts.first)
	s["initial"] = initial
	if opts.has("first") and opts.first != null:
		s.first = int(opts.first)
		# JS: `first ?? floor(random*2)` — verilen first rastgelelik tüketmez.
	else:
		s.first = int(floor(rnd(s) * 2))
	for p in 2:
		var player = s.players[p]
		shuffle(s, player.deck)
		if opening != null:
			for id in opening[p]:
				var index = player.deck.find(int(id))
				if index >= 0:
					player.hand.append(player.deck[index])
					player.deck.remove_at(index)
		if pinned != null:
			player.mulliganPinned = int_array(pinned[p])
		while player.hand.size() < 4:
			draw(s, p)
	note(s, "İlk oyuncu: %s. Başlangıç ellerini seçin." % ("Destancı" if s.first == 0 else "Gölge"))
	return s

# ---------- temel işlemler ----------

func attack_value(s: Dictionary, p: int, unit: Dictionary) -> int:
	var bonus = s.players[p].board.size() - 1 if int(unit.id) == 21 else 0
	return maxi(0, int(unit.attack) + int(unit.tempAttack) + bonus)

func can_attack(s: Dictionary, p: int, unit: Dictionary) -> bool:
	return s.status == "playing" and s.active == p and s.pending == null and not unit.exhausted \
		and int(unit.skipUntil) < int(s.players[p].turns) and attack_value(s, p, unit) > 0

func resolve_target(s: Dictionary, target) -> Dictionary:
	if not target is String:
		return {}
	if target == "hero:0" or target == "hero:1":
		var hp = int(target.substr(5))
		return {"kind": "hero", "p": hp, "value": s.players[hp]}
	if target.begins_with("unit:") and target.substr(5).is_valid_int():
		var uid = int(target.substr(5))
		for p in 2:
			for u in s.players[p].board:
				if int(u.uid) == uid:
					return {"kind": "unit", "p": p, "value": u}
	return {}

func unit_target(u: Dictionary) -> String:
	return "unit:%d" % int(u.uid)

func conclude(s: Dictionary) -> void:
	var dead = [s.players[0].hp <= 0, s.players[1].hp <= 0]
	if dead[0] or dead[1]:
		s.status = "finished"
		s.winner = null if (dead[0] and dead[1]) else (1 if dead[0] else 0)
		s.reason = "can"
		s.pending = null

func cleanup(s: Dictionary) -> void:
	for p in 2:
		var player = s.players[p]
		for u in player.board:
			if u.hp <= 0:
				player.grave.append({"id": int(u.id), "uid": int(u.uid)})
				note(s, "%s yok edildi." % card(u.id).name)
		player.board = player.board.filter(func(u): return u.hp > 0)
	conclude(s)

func damage(s: Dictionary, target, amount: int, source: String = "ability", flying: bool = false, poison: bool = false) -> int:
	var t = resolve_target(s, target)
	if t.is_empty():
		return 0
	if t.kind == "unit":
		if t.value.shield or (source == "combat" and t.value.keywords.has("Uçan") and not flying):
			return 0
	var actual = maxi(0, amount)
	if s.players[t.p].half:
		actual = actual / 2
	t.value.hp -= actual
	if t.kind == "unit" and poison and actual > 0:
		t.value.hp = 0
	return actual

func heal(s: Dictionary, target, amount: int) -> void:
	var t = resolve_target(s, target)
	if not t.is_empty():
		var cap = 20 if t.kind == "hero" else int(t.value.maxHp)
		t.value.hp = mini(cap, int(t.value.hp) + amount)

func who(p: int) -> String:
	return "Destancı" if p == 0 else "Gölge"

func draw(s: Dictionary, p: int) -> void:
	var player = s.players[p]
	if player.deck.is_empty():
		damage(s, "hero:%d" % p, 1)
		note(s, "%s boş desteden 1 hasar aldı." % who(p))
		conclude(s)
		return
	var id = player.deck.pop_front()
	if player.hand.size() < 7:
		player.hand.append(id)
	else:
		note(s, "Dolu el: %s yakıldı." % card(id).name)

func summon(s: Dictionary, p: int, id: int) -> Dictionary:
	var c = card(id)
	var unit = {"uid": int(s.nextUid), "id": id, "attack": int(c.attack), "hp": int(c.hp), "maxHp": int(c.hp),
		"tempAttack": 0, "shield": false, "keywords": c.keywords.duplicate(), "exhausted": not c.keywords.has("Hızlı"), "skipUntil": 0}
	s.nextUid = int(s.nextUid) + 1
	s.players[p].board.append(unit)
	return unit

func finish_start(s: Dictionary) -> void:
	s.pending = null
	var p = int(s.active)
	var player = s.players[p]
	if int(player.turns) == 1 and p == int(s.first):
		return
	draw(s, p)
	if s.status == "playing" and int(player.turns) == 1 and p != int(s.first):
		draw(s, p)

func begin_turn(s: Dictionary, p: int) -> void:
	s.active = p
	s.turn = int(s.turn) + 1
	s.phase = "main"
	var player = s.players[p]
	player.turns = int(player.turns) + 1
	player.maxEnergy = mini(8, int(player.maxEnergy) + 1)
	player.energy = player.maxEnergy
	for u in player.board:
		u.exhausted = false
	note(s, "%s · tur %d · %d enerji." % [who(p), int(player.turns), int(player.energy)])
	var sages = []
	for u in player.board:
		if int(u.id) == 23:
			sages.append(int(u.uid))
	if sages.size() > 0 and player.deck.size() > 0:
		s.pending = {"kind": "scry", "units": sages}
	else:
		finish_start(s)

func end_turn(s: Dictionary) -> void:
	for player in s.players:
		player.half = false
		for u in player.board:
			u.tempAttack = 0
			u.shield = false
	if int(s.turn) >= TURN_LIMIT:
		s.status = "finished"
		s.reason = "tur sınırı"
		var a = int(s.players[0].hp)
		var b = int(s.players[1].hp)
		s.winner = null if a == b else (0 if a > b else 1)
	else:
		begin_turn(s, 1 - int(s.active))

func play_targets(s: Dictionary, p: int, id: int) -> Array:
	var friendly = s.players[p].board.map(unit_target)
	var foes = s.players[1 - p].board.map(unit_target)
	if [11, 20, 28, 31].has(id):
		return friendly
	if id == 22:
		return foes
	if [29, 30].has(id):
		var all = ["hero:%d" % p, "hero:%d" % (1 - p)]
		all.append_array(friendly)
		all.append_array(foes)
		return all
	if id == 26 and s.players[p].board.size() < 4:
		return s.players[p].grave.map(func(g): return "grave:%d" % int(g.uid))
	return []

func targets_required(id: int) -> bool:
	return [11, 20, 22, 26, 28, 29, 30, 31].has(id)

func attack_targets(s: Dictionary, p: int, unit: Dictionary) -> Array:
	if not can_attack(s, p, unit):
		return []
	var foes: Array = s.players[1 - p].board
	var guardians = foes.filter(func(u): return u.keywords.has("Koruyucu"))
	var pool = guardians if guardians.size() > 0 else foes
	var flies = unit.keywords.has("Uçan")
	var reachable = pool.filter(func(u): return flies or not u.keywords.has("Uçan"))
	var out = []
	if guardians.is_empty():
		out.append("hero:%d" % (1 - p))
	for u in reachable:
		out.append(unit_target(u))
	return out

func freeze(s: Dictionary, p: int, units: Array) -> void:
	for u in units:
		u.skipUntil = maxi(int(u.skipUntil), int(s.players[p].turns) + 1)

func effects(s: Dictionary, p: int, id: int, target) -> void:
	var player = s.players[p]
	var foe = s.players[1 - p]
	var t = resolve_target(s, target)
	match id:
		4:
			heal(s, "hero:%d" % p, 1)
		5:
			damage(s, "hero:%d" % (1 - p), 1)
		8:
			draw(s, p)
		10:
			player.energy = mini(8, int(player.energy) + 1)
		11:
			if not t.is_empty():
				t.value.attack = int(t.value.attack) + 1
				t.value.hp = int(t.value.hp) + 1
				t.value.maxHp = int(t.value.maxHp) + 1
		12:
			var sorted = foe.board.duplicate()
			sorted.sort_custom(func(a, b):
				var va = attack_value(s, 1 - p, a)
				var vb = attack_value(s, 1 - p, b)
				if va != vb:
					return va > vb
				return int(a.uid) < int(b.uid))
			if sorted.size() > 0:
				freeze(s, 1 - p, [sorted[0]])
		18:
			if player.board.size() > 0:
				damage(s, unit_target(player.board.back()), 1)
		19:
			damage(s, "hero:%d" % (1 - p), 2)
		20:
			if not t.is_empty():
				t.value.hp = int(t.value.hp) + 2
				t.value.maxHp = int(t.value.maxHp) + 2
		22:
			if not t.is_empty():
				damage(s, target, 3)
		24:
			for u in player.board:
				u.hp = u.maxHp
		26:
			var index = -1
			for i in player.grave.size():
				if "grave:%d" % int(player.grave[i].uid) == target:
					index = i
					break
			if index >= 0 and player.board.size() < 5:
				var entry = player.grave[index]
				player.grave.remove_at(index)
				summon(s, p, int(entry.id))
		27:
			for u in foe.board.duplicate():
				damage(s, unit_target(u), 2)
		28:
			if not t.is_empty():
				t.value.tempAttack = int(t.value.tempAttack) + 2
		29:
			heal(s, target, 3)
		30:
			damage(s, target, 3)
		31:
			if not t.is_empty():
				t.value.shield = true
		32:
			draw(s, p)
			if s.status == "playing":
				draw(s, p)
			if s.status == "playing" and player.hand.size() > 0:
				s.pending = {"kind": "discard"}
		33:
			freeze(s, 1 - p, foe.board)
		34:
			for side in s.players:
				for u in side.board.duplicate():
					damage(s, unit_target(u), 2)
		35:
			for u in player.board:
				u.attack = int(u.attack) + 2
				u.hp = int(u.hp) + 2
				u.maxHp = int(u.maxHp) + 2
	cleanup(s)

func trigger_traps(s: Dictionary, owner: int, event: String, unit) -> bool:
	var player = s.players[owner]
	for trap in player.traps.duplicate():
		var alive = false
		if unit != null:
			for u in s.players[1 - owner].board:
				if int(u.uid) == int(unit.uid):
					alive = true
		if event == "spell" and int(trap.id) == 37:
			player.traps = player.traps.filter(func(t): return int(t.uid) != int(trap.uid))
			note(s, "Yankı açıldı; büyü iptal edildi.")
			return true
		if not alive:
			continue
		var tid = int(trap.id)
		var triggers = (event == "summon" and tid == 40) or (event == "attack" and (tid == 39 or tid == 38 or (tid == 36 and int(card(unit.id).cost) <= 3)))
		if not triggers:
			continue
		player.traps = player.traps.filter(func(t): return int(t.uid) != int(trap.uid))
		note(s, "%s açıldı." % card(tid).name)
		if tid == 40:
			damage(s, unit_target(unit), 4)
		if tid == 36:
			unit.hp = 0
		if tid == 38:
			player.half = true
		if tid == 39:
			var attacker = s.players[1 - owner]
			if attacker.hand.size() < 7:
				attacker.board = attacker.board.filter(func(u): return int(u.uid) != int(unit.uid))
				attacker.hand.append(int(unit.id))
			else:
				unit.hp = 0
		cleanup(s)
		if s.status != "playing":
			break
	return false

func play(s: Dictionary, p: int, action: Dictionary) -> void:
	if not rule(s.phase == "main", "Saldırı fazında kart oynanamaz."):
		return
	var player = s.players[p]
	var index = action.get("index", -1)
	if not rule(is_int(index) and int(index) >= 0 and int(index) < player.hand.size(), "Geçersiz el kartı."):
		return
	index = int(index)
	var id = int(player.hand[index])
	var c = card(id)
	if not rule(int(player.energy) >= int(c.cost), "Yeterli enerji yok."):
		return
	if c.type == "warrior" and not rule(player.board.size() < 5, "Saha dolu."):
		return
	if c.type == "trap" and not rule(player.traps.size() < 2, "Tuzak alanı dolu."):
		return
	var targets = play_targets(s, p, id)
	var target = action.get("target", null)
	if targets_required(id):
		if targets.is_empty() and c.type == "warrior":
			if not rule(target == null, "Geçerli hedef yok."):
				return
		elif not rule(target != null and targets.has(target), "Geçerli hedef seç."):
			return
	elif not rule(target == null, "Bu kart hedef istemez."):
		return
	player.energy = int(player.energy) - int(c.cost)
	player.hand.remove_at(index)
	var key = str(id)
	player.stats.cardPlays[key] = int(player.stats.cardPlays.get(key, 0)) + 1
	player.stats.energySpent = int(player.stats.energySpent) + int(c.cost)
	if c.type == "trap":
		note(s, "%s gizli bir tuzak kurdu." % who(p))
		player.traps.append({"uid": int(s.nextUid), "id": id})
		s.nextUid = int(s.nextUid) + 1
	else:
		note(s, "%s: %s." % [who(p), c.name])
		if c.type == "spell":
			if not trigger_traps(s, 1 - p, "spell", null):
				effects(s, p, id, target)
		else:
			var unit = summon(s, p, id)
			trigger_traps(s, 1 - p, "summon", unit)
			if s.status == "playing" and player.board.any(func(u): return int(u.uid) == int(unit.uid)):
				effects(s, p, id, target)

func attack(s: Dictionary, p: int, action: Dictionary) -> void:
	var unit = null
	for u in s.players[p].board:
		if int(u.uid) == int(action.get("uid", -1)):
			unit = u
	var ok = unit != null and attack_targets(s, p, unit).has(action.get("target", null))
	if not rule(ok, "Bu saldırı geçerli değil."):
		return
	s.phase = "attack"
	unit.exhausted = true
	s.players[p].stats.attacks = int(s.players[p].stats.attacks) + 1
	note(s, "%s saldırıyor." % card(unit.id).name)
	trigger_traps(s, 1 - p, "attack", unit)
	if s.status != "playing" or not s.players[p].board.any(func(u): return int(u.uid) == int(unit.uid)):
		return
	var target = resolve_target(s, action.target)
	if target.is_empty():
		return
	var atk = attack_value(s, p, unit)
	var flying = unit.keywords.has("Uçan")
	var poison = unit.keywords.has("Zehirli")
	if target.kind == "unit":
		var counter = attack_value(s, 1 - p, target.value)
		damage(s, action.target, atk, "combat", flying, poison)
		damage(s, unit_target(unit), counter, "combat", target.value.keywords.has("Uçan"), target.value.keywords.has("Zehirli"))
	else:
		damage(s, action.target, atk, "combat")
	cleanup(s)

# Başarılıysa yeni durumu döndürür, hata varsa `err` dolu olur ve {} döner.
func apply_action(state: Dictionary, p: int, action: Dictionary) -> Dictionary:
	err = ""
	if not rule(p == 0 or p == 1, "Geçersiz oyuncu."):
		return {}
	if not rule(action.get("type") is String, "Geçersiz hamle."):
		return {}
	if not rule(state.status != "finished", "Maç bitmiş."):
		return {}
	var s: Dictionary = state.duplicate(true)
	var kind: String = action.type
	if kind == "surrender":
		s.status = "finished"
		s.winner = 1 - p
		s.reason = "teslim"
		s.pending = null
	else:
		if not rule(int(s.active) == p, "Sıra sende değil."):
			return {}
		var player = s.players[p]
		if s.status == "mulligan":
			if not rule(kind == "mulligan" and action.get("indices") is Array, "Başlangıç elini seç."):
				return {}
			var raw: Array = action.indices
			var indices = []
			for i in raw:
				if not indices.has(int(i)):
					indices.append(int(i))
			var valid = indices.size() == raw.size()
			for i in raw:
				if not (is_int(i) and int(i) >= 0 and int(i) < 4):
					valid = false
			if not rule(valid, "Geçersiz mulligan seçimi."):
				return {}
			for i in indices:
				if not rule(not player.mulliganPinned.has(player.hand[i]), "Hikâye görev kartı başlangıç elinde korunur."):
					return {}
			var held = []
			for i in indices:
				held.append(player.hand[i])
			var keep = []
			for i in player.hand.size():
				if not indices.has(i):
					keep.append(player.hand[i])
			player.hand = keep
			for _h in held:
				draw(s, p)
			player.deck.append_array(held)
			shuffle(s, player.deck)
			note(s, "%s %d kart değiştirdi." % [who(p), held.size()])
			if p == 0:
				s.active = 1
			else:
				s.status = "playing"
				begin_turn(s, int(s.first))
		elif s.pending != null:
			if s.pending.kind == "scry":
				if not rule(kind == "scry" and action.get("bottom") is bool, "Üst kartı tut veya alta koy."):
					return {}
				if action.bottom:
					var deck = player.deck
					deck.append(deck.pop_front())
				s.pending.units.pop_front()
				if s.pending.units.is_empty():
					finish_start(s)
			else:
				var index = action.get("index", -1)
				if not rule(kind == "discard" and is_int(index) and int(index) >= 0 and int(index) < player.hand.size(), "Atılacak kartı seç."):
					return {}
				player.hand.remove_at(int(index))
				s.pending = null
				note(s, "%s elinden bir kart attı." % who(p))
		else:
			if kind == "play":
				play(s, p, action)
			elif kind == "attack":
				attack(s, p, action)
			elif kind == "end":
				end_turn(s)
			else:
				rule(false, "Bilinmeyen hamle.")
	if not err.is_empty():
		return {}
	s.history.append({"p": p, "action": action.duplicate(true)})
	return s

func legal_actions(s: Dictionary, p: int = -1) -> Array:
	if p < 0:
		p = int(s.active)
	if s.status == "finished" or int(s.active) != p:
		return []
	if s.status == "mulligan":
		return [{"type": "mulligan", "indices": []}]
	if s.pending != null and s.pending.kind == "scry":
		return [{"type": "scry", "bottom": false}, {"type": "scry", "bottom": true}]
	if s.pending != null and s.pending.kind == "discard":
		var out = []
		for i in s.players[p].hand.size():
			out.append({"type": "discard", "index": i})
		return out
	var actions = []
	var player = s.players[p]
	if s.phase == "main":
		for index in player.hand.size():
			var id = int(player.hand[index])
			var c = card(id)
			if int(c.cost) > int(player.energy) or (c.type == "warrior" and player.board.size() >= 5) or (c.type == "trap" and player.traps.size() >= 2):
				continue
			var targets = play_targets(s, p, id)
			if targets_required(id) and targets.size() > 0:
				for target in targets:
					actions.append({"type": "play", "index": index, "target": target})
			elif not targets_required(id) or c.type == "warrior":
				actions.append({"type": "play", "index": index})
	for u in player.board:
		for target in attack_targets(s, p, u):
			actions.append({"type": "attack", "uid": int(u.uid), "target": target})
	actions.append({"type": "end"})
	return actions

func export_replay(s: Dictionary) -> Dictionary:
	return {"version": RULE_VERSION, "initial": s.initial.duplicate(true), "history": s.history.duplicate(true)}

# ---------- bot ----------

func visible_state(state: Dictionary, p: int) -> Dictionary:
	var s: Dictionary = state.duplicate(true)
	s.seed = 0
	s.history = []
	s.log = []
	s.initial = {}
	s.erase("entropy")
	s.erase("entropyIndex")
	for i in 2:
		var player = s.players[i]
		var filler = []
		filler.resize(player.deck.size())
		filler.fill(1)
		player.deck = filler
		if i != p:
			var hand = []
			hand.resize(player.hand.size())
			hand.fill(1)
			player.hand = hand
			player.unknownTraps = player.traps.size()
			player.traps = []
			player.mulliganPinned = []
	return s

func unit_value(s: Dictionary, p: int, u: Dictionary) -> float:
	var next_turn_frozen = int(u.skipUntil) >= int(s.players[p].turns) + 1
	var plain = u.duplicate()
	plain.tempAttack = 0
	var base_attack = float(attack_value(s, p, plain))
	return base_attack * 1.8 + float(u.hp) * 0.55 + float(card(u.id).cost) * 0.2 \
		+ (1.4 if u.keywords.has("Koruyucu") else 0.0) + (2.0 if u.keywords.has("Uçan") else 0.0) \
		+ (2.2 if u.keywords.has("Zehirli") else 0.0) - (base_attack * 0.9 if next_turn_frozen else 0.0)

func state_value(s: Dictionary, p: int) -> float:
	if s.status == "finished":
		if s.winner == null:
			return 0.0
		return 1000000.0 if int(s.winner) == p else -1000000.0
	var me = s.players[p]
	var foe = s.players[1 - p]
	var own_board = 0.0
	for u in me.board:
		own_board += unit_value(s, p, u)
	var enemy_board = 0.0
	for u in foe.board:
		enemy_board += unit_value(s, 1 - p, u)
	var danger = 0.0
	for u in foe.board:
		if int(u.skipUntil) < int(foe.turns) + 1:
			danger += attack_value(s, 1 - p, u)
	var guardians = 0.0
	for u in me.board:
		if u.keywords.has("Koruyucu"):
			guardians += float(u.hp)
	var exposed = maxf(0.0, danger - guardians)
	return (own_board - enemy_board) * 1.5 + float(me.hp) * 1.1 - float(foe.hp) * 0.85 \
		+ float(me.hand.size()) * 1.6 + float(me.energy) * 0.25 + float(me.traps.size()) * 2.8 \
		- maxf(0.0, exposed - float(me.hp) + 4.0) * 2.5

func useful_hand_card(s: Dictionary, p: int, id) -> float:
	var c = card(id)
	var player = s.players[p]
	var foe = s.players[1 - p]
	var cid = int(c.id)
	if int(c.cost) > int(player.maxEnergy) + 2:
		return -5.0 - float(c.cost)
	if cid == 29:
		if int(player.hp) < 16:
			return 5.0
		return 1.0 if foe.board.size() > 0 else -1.0
	if c.type == "warrior":
		return float(c.attack) * 1.4 + float(c.hp) * 0.4 + (2.0 if c.keywords.has("Hızlı") else 0.0)
	if cid == 34:
		return float(foe.board.size()) * 3.0 - float(player.board.size()) * 3.0
	if cid == 33:
		return float(foe.board.size()) * 2.0
	return float(c.cost) + 2.0

func choose_bot_action(state: Dictionary, p: int = -1) -> Dictionary:
	if p < 0:
		p = int(state.active)
	if int(state.active) != p or state.status == "finished":
		return {}
	if state.status == "mulligan":
		var idx = []
		var hand = state.players[p].hand
		for i in hand.size():
			if int(card(hand[i]).cost) > 3 and not state.players[p].mulliganPinned.has(hand[i]):
				idx.append(i)
		return {"type": "mulligan", "indices": idx}
	var actions = legal_actions(state, p)
	if actions.is_empty():
		return {}
	if state.pending != null and state.pending.kind == "scry":
		var top = state.players[p].deck[0]
		return {"type": "scry", "bottom": int(card(top).cost) > int(state.players[p].maxEnergy) + 1}
	if state.pending != null and state.pending.kind == "discard":
		var best = actions[0]
		var best_value = useful_hand_card(state, p, state.players[p].hand[best.index])
		for a in actions:
			var v = useful_hand_card(state, p, state.players[p].hand[a.index])
			if v < best_value:
				best = a
				best_value = v
		return best
	var s = visible_state(state, p)
	var baseline = state_value(s, p)
	var ranked = []
	for i in actions.size():
		ranked.append({"action": actions[i], "score": score_action(s, p, actions[i], baseline), "i": i})
	ranked.sort_custom(func(a, b):
		if a.score != b.score:
			return a.score > b.score
		return a.i < b.i)
	if ranked[0].score >= 900000.0:
		return ranked[0].action
	for r in ranked:
		if r.action.type == "play" and r.score > 0.01:
			return r.action
	for r in ranked:
		if r.action.type == "attack" and r.score > 0.01:
			return r.action
	return {"type": "end"}

func score_action(s: Dictionary, p: int, a: Dictionary, baseline: float) -> float:
	if a.type == "end":
		return 0.0
	var c = null
	if a.type == "play":
		c = card(s.players[p].hand[a.index])
	var target = resolve_target(s, a.get("target", null))
	var target_p = target.p if not target.is_empty() else null
	if c != null:
		var cid = int(c.id)
		if (cid == 30 and target_p == p) or (cid == 29 and target_p != p):
			return -INF
		if (cid == 28 or cid == 31) and (target.is_empty() or attack_targets(s, p, target.value).is_empty()):
			return -INF
	var nxt = apply_action(s, p, a)
	if nxt.is_empty():
		return -INF
	var delta = state_value(nxt, p) - baseline
	if c != null and (int(c.id) == 28 or int(c.id) == 31):
		var uid = int(target.value.uid)
		var before = 0.0
		for b in legal_actions(s, p):
			if b.type == "attack" and int(b.uid) == uid:
				var after_b = apply_action(s, p, b)
				if not after_b.is_empty():
					before = maxf(before, state_value(after_b, p) - baseline)
		var after = -INF
		for b in legal_actions(nxt, p):
			if b.type == "attack" and int(b.uid) == uid:
				var res = apply_action(nxt, p, b)
				if not res.is_empty():
					after = maxf(after, state_value(res, p) - baseline)
		delta = maxf(delta, after - before)
	return delta
