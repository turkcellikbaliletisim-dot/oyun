extends RefCounted
# Birleştirme modu (UGACHA tarzı): aynı türden, aynı seviyeden iki birliği
# birleştir, güçlen, otomatik savaşta dalgaları geç. Tamamen çevrimdışı çalışır
# ve deterministiktir (tohum durumda saklanır).

const COLS = 5
const ROWS = 4
const MAX_TIER = 8
const START_LIVES = 3
const START_GOLD = 30
const KINDS = [
	{"id": "kilic", "name": "Kılıççı", "atk": 3, "hp": 14, "splash": 1},
	{"id": "okcu", "name": "Okçu", "atk": 5, "hp": 7, "splash": 1},
	{"id": "buyucu", "name": "Büyücü", "atk": 3, "hp": 6, "splash": 3},
	{"id": "kalkan", "name": "Kalkancı", "atk": 2, "hp": 22, "splash": 1},
]
const TOTEMS = [
	{"id": "savas", "name": "Savaş Totemi", "text": "+%15 saldırı", "unlock": 0},
	{"id": "kalkan", "name": "Kalkan Totemi", "text": "+%20 can", "unlock": 5},
	{"id": "altin", "name": "Altın Totemi", "text": "+%25 dalga altını", "unlock": 10},
	{"id": "can", "name": "Can Totemi", "text": "+1 can", "unlock": 15},
]
const BOSS_NAMES = ["Kara Kurt", "Demir Dev", "Gölge Ejder"]
const TIER_GROWTH = 1.9
const ENEMY_GROWTH = 1.22
const MAX_ROUNDS = 80

var err: String = ""

static func new_run(seed_value: int, stars: int = 0) -> Dictionary:
	var board = []
	for i in range(COLS * ROWS):
		board.append(null)
	return {"seed": seed_value % 2147483647 + 1, "wave": 1, "gold": START_GOLD, "lives": START_LIVES, "buys": 0, "board": board, "stars": stars, "over": false, "log": [], "totem": -1}

# ---------- yardımcılar ----------

static func rand_next(s: Dictionary) -> int:
	s.seed = (int(s.seed) * 48271) % 2147483647
	return int(s.seed)

static func buy_cost(s: Dictionary) -> int:
	return 10 + 2 * int(s.buys)

static func star_mult(s: Dictionary) -> float:
	return 1.0 + 0.1 * int(s.stars)

static func unit_stats(unit: Dictionary, s: Dictionary) -> Dictionary:
	var kind = KINDS[int(unit.k)]
	var m = pow(TIER_GROWTH, int(unit.t) - 1) * star_mult(s)
	var tot = int(s.get("totem", -1))
	var atk_m = m * (1.15 if tot == 0 else 1.0)
	var hp_m = m * (1.2 if tot == 1 else 1.0)
	return {"atk": int(round(kind.atk * atk_m)), "hp": int(round(kind.hp * hp_m)), "splash": int(kind.splash), "name": kind.name}

static func free_cell(s: Dictionary) -> int:
	for i in range(s.board.size()):
		if s.board[i] == null:
			return i
	return -1

static func board_units(s: Dictionary) -> int:
	var n = 0
	for c in s.board:
		if c != null:
			n += 1
	return n

func fail(msg: String) -> Dictionary:
	err = msg
	return {}

# ---------- eylemler ----------

func buy(s: Dictionary) -> Dictionary:
	err = ""
	if s.over:
		return fail("Koşu bitti.")
	var cost = buy_cost(s)
	if int(s.gold) < cost:
		return fail("Altın yetmiyor.")
	var cell = free_cell(s)
	if cell < 0:
		return fail("Tahta dolu, önce birleştir.")
	s.gold = int(s.gold) - cost
	s.buys = int(s.buys) + 1
	var kind = rand_next(s) % KINDS.size()
	s.board[cell] = {"k": kind, "t": 1}
	return s

func move(s: Dictionary, from: int, to: int) -> Dictionary:
	err = ""
	var n = s.board.size()
	if s.over or from < 0 or to < 0 or from >= n or to >= n or from == to:
		return fail("Geçersiz hamle.")
	var a = s.board[from]
	var b = s.board[to]
	if a == null:
		return fail("Boş hücre.")
	if b == null:
		s.board[to] = a
		s.board[from] = null
	elif int(a.k) == int(b.k) and int(a.t) == int(b.t) and int(a.t) < MAX_TIER:
		s.board[to] = {"k": a.k, "t": int(a.t) + 1}
		s.board[from] = null
	else:
		s.board[to] = a
		s.board[from] = b
	return s

func sell(s: Dictionary, cell: int) -> Dictionary:
	err = ""
	if s.over or cell < 0 or cell >= s.board.size() or s.board[cell] == null:
		return fail("Satılacak birlik yok.")
	var u = s.board[cell]
	s.gold = int(s.gold) + 4 * int(pow(2, int(u.t) - 1))
	s.board[cell] = null
	return s

func choose_totem(s: Dictionary, id: int, best_wave: int) -> Dictionary:
	err = ""
	if s.over or id < 0 or id >= TOTEMS.size():
		return fail("Geçersiz totem.")
	if best_wave < int(TOTEMS[id].unlock):
		return fail("Bu totem henüz kilitli.")
	if not s.log.is_empty() or int(s.wave) > 1:
		return fail("Totem yalnızca koşunun başında seçilir.")
	var old = int(s.get("totem", -1))
	if old == 3:
		s.lives = int(s.lives) - 1
	s.totem = id
	if id == 3:
		s.lives = int(s.lives) + 1
	return s

static func is_boss(wave: int) -> bool:
	return wave % 5 == 0

# ---------- savaş ----------

static func enemy_wave(wave: int) -> Array:
	var n = mini(2 + wave / 2, 14)
	var m = pow(ENEMY_GROWTH, wave - 1)
	var out = []
	for i in range(n):
		var kind = KINDS[(wave + i) % KINDS.size()]
		out.append({"atk": maxi(1, int(round(kind.atk * m * 0.8))), "hp": maxi(1, int(round(kind.hp * m * 1.1))), "splash": int(kind.splash)})
	if is_boss(wave):
		out.append({"atk": maxi(1, int(round(6 * m * 2.5))), "hp": maxi(1, int(round(30 * m * 3.0))), "splash": 3, "boss": BOSS_NAMES[(wave / 5 - 1) % BOSS_NAMES.size()]})
	return out

func battle(s: Dictionary) -> Dictionary:
	err = ""
	if s.over:
		return fail("Koşu bitti.")
	var mine = []
	for c in s.board:
		if c != null:
			mine.append(unit_stats(c, s))
	if mine.is_empty():
		return fail("Tahtada birlik yok.")
	var foes = enemy_wave(int(s.wave))
	var rounds = 0
	var frames = []
	var start_mine = mine.size()
	var start_foes = foes.size()
	var mine_hp0 = 0
	var foes_hp0 = 0
	for u in mine:
		mine_hp0 += int(u.hp)
	for e in foes:
		foes_hp0 += int(e.hp)
	while rounds < MAX_ROUNDS and not mine.is_empty() and not foes.is_empty():
		rounds += 1
		var dmg_to_foes = {}
		var dmg_to_mine = {}
		for u in mine:
			for j in range(mini(int(u.splash), foes.size())):
				dmg_to_foes[j] = int(dmg_to_foes.get(j, 0)) + int(u.atk)
		for e in foes:
			for j in range(mini(int(e.splash), mine.size())):
				dmg_to_mine[j] = int(dmg_to_mine.get(j, 0)) + int(e.atk)
		for j in dmg_to_foes:
			foes[j].hp = int(foes[j].hp) - int(dmg_to_foes[j])
		for j in dmg_to_mine:
			mine[j].hp = int(mine[j].hp) - int(dmg_to_mine[j])
		mine = mine.filter(func(x): return int(x.hp) > 0)
		foes = foes.filter(func(x): return int(x.hp) > 0)
		if frames.size() < 40:
			frames.append({"mine": mine.map(func(x): return int(x.hp)), "foes": foes.map(func(x): return int(x.hp))})
	var won = foes.is_empty() and not mine.is_empty()
	var result = {"won": won, "rounds": rounds, "wave": int(s.wave), "frames": frames, "mine0": start_mine, "mine_hp0": mine_hp0, "foes_hp0": foes_hp0, "foes0": start_foes, "boss": is_boss(int(s.wave))}
	if won:
		var reward = 18 + 3 * int(s.wave)
		if int(s.get("totem", -1)) == 2:
			reward = int(round(reward * 1.25))
		if is_boss(int(s.wave)):
			reward *= 2
		s.gold = int(s.gold) + reward
		s.wave = int(s.wave) + 1
		s.buys = maxi(0, int(s.buys) - 2)
		result.reward = reward
	else:
		s.lives = int(s.lives) - 1
		s.gold = int(s.gold) + 10
		if int(s.lives) <= 0:
			s.over = true
	result.lives = int(s.lives)
	result.over = bool(s.over)
	var entry = result.duplicate()
	entry.erase("frames")
	s.log.append(entry)
	if s.log.size() > 20:
		s.log = s.log.slice(s.log.size() - 20)
	return result

# ---------- yeniden doğuş ----------

static func stars_for_best(best_wave: int) -> int:
	return best_wave / 5
