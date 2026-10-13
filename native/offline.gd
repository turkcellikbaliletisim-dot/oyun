extends RefCounted
# Çevrimdışı "yerel sunucu": server/service.js + oyun/economy.js + oyun/chapters.js
# davranışını istemcide, aynı API biçimiyle sunar. Hesap, yolculuk, bot maçı,
# sandık/koleksiyon çalışır; arkadaş odası ve lig çevrimiçi gerektirir.

const Engine_ = preload("res://native/offline_engine.gd")

const CRAFT = {"common": 40, "rare": 100, "legendary": 400}
const DUST = {"common": 10, "rare": 25, "legendary": 100}
const CHAPTER_REWARDS = {2: [6], 3: [19], 4: [32], 5: [5, 14], 6: [36], 7: [16], 8: [33], 9: [18], 10: [26]}
const OPENINGS = [[1, 2, 3, 30], [3, 1, 2, 30], [30, 1, 2, 3], [32, 1, 2, 3], [2, 5, 7, 30], [36, 1, 2, 3], [16, 1, 2, 3], [33, 1, 2, 3], [18, 2, 5, 7], [3, 33, 37, 4]]
const FILE_NAME = "offline.json"

var data: Dictionary = {}
var engine
var store: Dictionary = {}
var save_path: String = "user://offline.json"
var rng := RandomNumberGenerator.new()

func _init(game_data: Dictionary, path: String = "") -> void:
	rng.randomize()
	data = intify(game_data)
	engine = Engine_.new(data.cards)
	if not path.is_empty():
		save_path = path
	load_store()

# ---------- genel yardımcılar ----------

static func intify(value):
	match typeof(value):
		TYPE_FLOAT:
			return int(value) if value == floorf(value) and absf(value) < 9.0e15 else value
		TYPE_ARRAY:
			var out = []
			for v in value:
				out.append(intify(v))
			return out
		TYPE_DICTIONARY:
			var out = {}
			for k in value:
				out[k] = intify(value[k])
			return out
	return value

func fail(message: String, status: int = 422) -> Dictionary:
	return {"error": message, "http_status": status}

func now_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)

func today() -> String:
	# Türkiye saati (UTC+3, yaz saati yok).
	return Time.get_date_string_from_unix_time(int(Time.get_unix_time_from_system()) + 10800)

func random_hex(bytes: int) -> String:
	return Crypto.new().generate_random_bytes(bytes).hex_encode()

func new_id() -> String:
	var h = random_hex(16)
	return "%s-%s-%s-%s-%s" % [h.substr(0, 8), h.substr(8, 4), h.substr(12, 4), h.substr(16, 4), h.substr(20, 12)]

func card_of(id) -> Dictionary:
	return engine.card(id)

func capacity(id) -> int:
	return 1 if card_of(id).rarity == "legendary" else 2

func league(mmr: int) -> String:
	if mmr < 1000:
		return "Çırak"
	if mmr < 1200:
		return "Kalfa"
	if mmr < 1400:
		return "Usta"
	if mmr < 1600:
		return "Destancı"
	return "Efsane"

# ---------- kayıt ----------

func load_store() -> void:
	store = {"user": null, "matches": {}}
	if FileAccess.file_exists(save_path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(save_path))
		if parsed is Dictionary and parsed.get("user") is Dictionary and parsed.get("matches") is Dictionary:
			store = intify(parsed)

func save_store() -> void:
	# Güncel maç dışındaki bitmiş maçların oyun durumu özetlenir; dosya şişmesin.
	var keep = str(store.user.matchId) if store.user != null and store.user.matchId != null else ""
	var finished = []
	for id in store.matches:
		var m = store.matches[id]
		if id != keep and m.game != null and m.game.has("players"):
			m.game = {"status": "finished", "turn": int(m.game.turn), "winner": m.game.winner}
			m.requests = {}
		if m.game != null and m.game.status == "finished":
			finished.append(m)
	finished.sort_custom(func(a, b): return int(a.created) > int(b.created))
	for i in range(20, finished.size()):
		if str(finished[i].id) != keep:
			store.matches.erase(finished[i].id)
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(store))
		file.close()

func has_account() -> bool:
	return store.user != null

# ---------- ekonomi (oyun/economy.js) ----------

func new_profile() -> Dictionary:
	var inventory = {}
	for id in data.decks.starter.cards:
		inventory[str(id)] = int(inventory.get(str(id), 0)) + 1
	return {"version": 1, "inventory": inventory, "gold": 0, "dust": 0, "pity": 0, "freePacks": 0, "loginDays": [], "days": {}, "weeks": {}, "chapterRewards": [], "matchRewards": [], "archiveLeft": 0}

func day_stats(p: Dictionary, day: String) -> Dictionary:
	if not p.days.has(day):
		p.days[day] = {"warriors": 0, "spells": 0, "matches": 0, "wins": 0, "claimed": []}
	return p.days[day]

func week_key(day: String) -> String:
	var unix = Time.get_unix_time_from_datetime_string(day + "T12:00:00")
	var weekday = int(Time.get_date_dict_from_unix_time(unix).weekday)  # 0 = Pazar
	return Time.get_date_string_from_unix_time(unix - ((weekday + 6) % 7) * 86400)

func grant(p: Dictionary, id: int) -> Dictionary:
	var key = str(id)
	if int(p.inventory.get(key, 0)) < capacity(id):
		p.inventory[key] = int(p.inventory.get(key, 0)) + 1
		return {"id": id, "dust": 0}
	var dust = int(DUST[card_of(id).rarity])
	p.dust = int(p.dust) + dust
	return {"id": id, "dust": dust}

func login_reward(profile: Dictionary, day: String) -> Dictionary:
	var p = profile.duplicate(true)
	if not p.loginDays.has(day):
		p.loginDays.append(day)
		p.gold = int(p.gold) + 30
		if p.loginDays.size() % 7 == 0:
			p.freePacks = int(p.freePacks) + 1
	day_stats(p, day)
	return p

func deck_owned(profile: Dictionary, deck: Array) -> bool:
	var counts = {}
	for id in deck:
		counts[int(id)] = int(counts.get(int(id), 0)) + 1
	for id in counts:
		if int(profile.inventory.get(str(id), 0)) < counts[id]:
			return false
	return true

func chapter_reward(profile: Dictionary, id: int) -> Dictionary:
	var p = profile.duplicate(true)
	if p.chapterRewards.has(id):
		return p
	p.chapterRewards.append(id)
	if id == 1:
		p.gold = int(p.gold) + 100
		p.freePacks = int(p.freePacks) + 1
	else:
		for c in CHAPTER_REWARDS.get(id, []):
			grant(p, int(c))
	if id == 10:
		var missing = 0
		for c in data.cards:
			if int(p.inventory.get(str(int(c.id)), 0)) <= 0:
				missing += 1
		p.archiveLeft = mini(7, missing)
	return p

func match_reward(profile: Dictionary, match_id: String, state: Dictionary, day: String, chapter_id: int) -> Dictionary:
	var p = profile.duplicate(true)
	if state.status != "finished" or p.matchRewards.has(match_id):
		return p
	p.matchRewards.append(match_id)
	if chapter_id == 1:
		return p
	var acted = 0
	for entry in state.history:
		if int(entry.p) == 0 and (entry.action.type == "play" or entry.action.type == "attack"):
			acted += 1
	if int(state.turn) < 4 or acted < 2:
		return p
	var daily = day_stats(p, day)
	var wk = week_key(day)
	if not p.weeks.has(wk):
		p.weeks[wk] = {"matches": 0, "claimed": false}
	var week = p.weeks[wk]
	daily.matches = int(daily.matches) + 1
	week.matches = int(week.matches) + 1
	var stats = state.players[0].stats
	for key in stats.cardPlays:
		var count = int(stats.cardPlays[key])
		var type = card_of(int(key)).type
		if type == "warrior":
			daily.warriors = int(daily.warriors) + count
		if type == "spell":
			daily.spells = int(daily.spells) + count
	if state.winner != null and int(state.winner) == 0 and int(daily.wins) < 3:
		daily.wins = int(daily.wins) + 1
		p.gold = int(p.gold) + 20
	for pair in [["warriors", 8], ["spells", 3], ["matches", 2]]:
		if int(daily[pair[0]]) >= pair[1] and not daily.claimed.has(pair[0]):
			daily.claimed.append(pair[0])
			p.gold = int(p.gold) + 50
	if int(week.matches) >= 10 and not week.claimed:
		week.claimed = true
		p.gold = int(p.gold) + 300
		p.freePacks = int(p.freePacks) + 1
	return p

func open_pack(profile: Dictionary) -> Dictionary:
	var p = profile.duplicate(true)
	if int(p.freePacks) > 0:
		p.freePacks = int(p.freePacks) - 1
	else:
		if int(p.gold) < 300:
			return {"error": "Bir paket 300 altın."}
		p.gold = int(p.gold) - 300
	var last = "legendary"
	if int(p.pity) != 9:
		var n = rng.randf()
		last = "common" if n < 0.65 else ("rare" if n < 0.85 else "legendary")
	p.pity = 0 if last == "legendary" else int(p.pity) + 1
	var rewards = []
	for rarity in ["common", "common", "common", "rare", last]:
		var available = []
		for c in data.cards:
			if c.rarity == rarity and int(p.inventory.get(str(int(c.id)), 0)) < capacity(int(c.id)):
				available.append(int(c.id))
		if available.size() > 0:
			rewards.append(grant(p, available[int(floor(rng.randf() * available.size()))]))
		else:
			p.dust = int(p.dust) + int(DUST[rarity])
			rewards.append({"id": null, "rarity": rarity, "dust": int(DUST[rarity])})
	return {"profile": p, "rewards": rewards}

# ---------- hesap ve maç ----------

func account_view(user: Dictionary) -> Dictionary:
	var history = []
	var list = []
	for id in store.matches:
		var m = store.matches[id]
		if m.game != null and m.game.status == "finished":
			list.append(m)
	list.sort_custom(func(a, b): return int(a.created) > int(b.created))
	for m in list.slice(0, 20):
		var result = "draw"
		if m.game.winner != null:
			result = "win" if int(m.game.winner) == 0 else "loss"
		history.append({"id": m.id, "kind": m.kind, "chapterId": int(m.get("chapterId", 0)), "turns": int(m.game.turn), "result": result})
	return {"id": user.id, "profile": user.profile.duplicate(true), "mmr": int(user.mmr), "placements": int(user.placements),
		"league": league(int(user.mmr)), "matchId": user.matchId, "queued": false, "history": history, "csrf": user.csrf, "offline": true}

func bootstrap() -> Dictionary:
	if store.user == null:
		store.user = {"id": new_id(), "profile": new_profile(), "mmr": 1000, "placements": 0, "matchId": null, "ops": {}, "csrf": random_hex(32)}
	store.user.profile = login_reward(store.user.profile, today())
	save_store()
	return account_view(store.user)

func check_free(user: Dictionary) -> String:
	if user.matchId != null and store.matches.has(user.matchId):
		var m = store.matches[user.matchId]
		if m.game != null and m.game.status != "finished" and m.status != "cancelled":
			return "Önce mevcut maçı bitir."
		if m.game == null and m.status != "cancelled":
			return "Önce mevcut maçı bitir."
	return ""

func chapter_complete(chapter_id: int, stats: Dictionary) -> bool:
	var plays = stats.cardPlays
	var played = func(id): return int(plays.get(str(id), 0)) > 0
	var type_played = func(type):
		for key in plays:
			if card_of(int(key)).type == type:
				return true
		return false
	match chapter_id:
		1:
			return type_played.call("warrior") and int(stats.attacks) >= 1
		2:
			return [3, 6, 15].any(func(id): return played.call(id))
		3:
			return type_played.call("spell")
		4:
			return played.call(32)
		5:
			return [2, 9, 14].any(func(id): return played.call(id))
		6:
			return played.call(36)
		7:
			return played.call(16)
		8:
			return played.call(33)
		9:
			return played.call(18)
		10:
			return ["warrior", "spell", "trap"].all(func(t): return type_played.call(t))
	return false

func bot_turns(m: Dictionary) -> Dictionary:
	var steps = 0
	while m.game.status != "finished" and int(m.game.active) == 1:
		steps += 1
		if steps > 100:
			return fail("Bot turu tamamlanamadı.", 500)
		var chapter = null
		if int(m.get("chapterId", 0)) >= 1:
			chapter = data.chapters[int(m.chapterId) - 1]
		var action = {}
		if chapter != null and chapter.get("passive", false) and m.game.status == "playing" and m.game.pending == null:
			action = {"type": "end"}
		else:
			action = engine.choose_bot_action(m.game, 1)
		if action.is_empty():
			action = {"type": "end"}
		var next = engine.apply_action(m.game, 1, action)
		if next.is_empty():
			# Güvenli çıkış: bot geçersiz hamle üretirse turunu bitirir.
			next = engine.apply_action(m.game, 1, {"type": "end"})
			if next.is_empty():
				return fail("Bot hamlesi uygulanamadı.", 500)
		m.game = next
		m.version = int(m.version) + 1
	settle(m)
	return {}

func settle(m: Dictionary) -> void:
	if m.game.status != "finished" or m.settled:
		return
	m.settled = true
	m.status = "finished"
	m.deadline = null
	m.finished = now_ms()
	var user = store.user
	var g = m.game
	var history = []
	for e in g.history:
		history.append({"p": 0 if int(e.p) == 0 else 1, "action": e.action})
	var state = {"status": "finished", "winner": g.winner, "turn": int(g.turn), "history": history, "players": [g.players[0]]}
	var day = today()
	var chapter_id = int(m.get("chapterId", 0))
	user.profile = login_reward(user.profile, day)
	user.profile = match_reward(user.profile, str(m.id), state, day, chapter_id)
	if m.kind == "story" and chapter_id >= 1 and g.winner != null and int(g.winner) == 0 and chapter_complete(chapter_id, g.players[0].stats):
		user.profile = chapter_reward(user.profile, chapter_id)

func view(m: Dictionary, p: int) -> Dictionary:
	var result = {"id": m.id, "code": m.code, "kind": m.kind, "chapterId": int(m.get("chapterId", 0)), "status": m.status,
		"version": int(m.version), "deadline": m.deadline, "serverNow": now_ms(), "state": null}
	if m.game == null:
		return result
	var s = m.game
	if not s.has("players"):
		return result
	var order = [p, 1 - p]
	var log = []
	for line in s.log:
		log.append(str(line).replace("Destancı", "Sen" if p == 0 else "Rakip").replace("Gölge", "Sen" if p == 1 else "Rakip"))
	var pending = null
	if s.pending != null:
		pending = s.pending.duplicate(true) if int(s.active) == p else {"kind": "waiting"}
	var players = []
	for index in 2:
		var player = s.players[order[index]]
		var hand = player.hand.duplicate() if index == 0 else []
		if index != 0:
			hand.resize(player.hand.size())
			hand.fill(null)
		var deck = []
		deck.resize(player.deck.size())
		deck.fill(null)
		var traps = player.traps.duplicate(true)
		if index != 0:
			traps = []
			traps.resize(player.traps.size())
			traps.fill({"hidden": true})
		players.append({"hp": int(player.hp), "energy": int(player.energy), "maxEnergy": int(player.maxEnergy), "turns": int(player.turns),
			"half": player.half, "hand": hand, "deck": deck, "board": player.board.duplicate(true), "traps": traps,
			"grave": player.grave.duplicate(true), "stats": player.stats.duplicate(true) if index == 0 else null,
			"mulliganPinned": player.mulliganPinned.duplicate() if index == 0 else []})
	if s.pending != null and s.pending.kind == "scry" and int(s.active) == p and s.players[p].deck.size() > 0:
		players[0].deck[0] = s.players[p].deck[0]
	var winner = null
	if s.winner != null:
		winner = 0 if int(s.winner) == p else 1
	result.state = {"version": s.version, "nextUid": int(s.nextUid), "status": s.status, "active": 0 if int(s.active) == p else 1,
		"first": 0 if int(s.first) == p else 1, "turn": int(s.turn), "phase": s.phase, "winner": winner, "reason": s.reason,
		"log": log, "pending": pending, "players": players}
	result["actions"] = engine.legal_actions(result.state, 0)
	return result

func chapter_options(chapter_id: int) -> Dictionary:
	var chapter = data.chapters[chapter_id - 1]
	var opening = OPENINGS[chapter_id - 1]
	var pinned = opening.slice(0, 3) if chapter_id == 10 else [opening[0]]
	var options = {"decks": [chapter.deck, chapter.foe], "opening": [opening, []], "pinned": [pinned, []]}
	if chapter.get("passive", false):
		options["first"] = 0
	return options

func entropy() -> Array:
	var out = []
	for i in 80:
		out.append(int(rng.randi()))
	return out

# ---------- API yönlendirme ----------

const ONLINE_ONLY = ["rooms", "join", "queue", "queue/cancel", "recover", "recovery-key"]

func handle(path: String, method: int, body: Dictionary) -> Dictionary:
	if path == "health":
		return {"ready": true, "version": "0.2", "offline": true}
	if path == "session":
		return bootstrap()
	if store.user == null:
		return fail("Oturum bulunamadı.", 401)
	var user: Dictionary = store.user
	if ONLINE_ONLY.has(path):
		return fail("Bu özellik çevrimiçi bağlantı ister. Şimdilik bot ve yolculuk ile oynayabilirsin.", 503)
	if path == "me":
		return account_view(user)
	if path == "solo":
		return solo(user, body)
	if path.begins_with("collection/"):
		return wallet(user, path.trim_prefix("collection/"), body)
	if path.begins_with("matches/"):
		var parts = path.trim_prefix("matches/").split("/")
		var id = parts[0]
		if not store.matches.has(id):
			return fail("Maç bulunamadı.", 404)
		var m: Dictionary = store.matches[id]
		var sub = parts[1] if parts.size() > 1 else ""
		if sub == "":
			return view_or_missing(m)
		if sub == "actions":
			return action(user, m, body)
		if sub == "leave":
			return leave(user, m)
		if sub == "replay":
			if m.game == null or not m.game.has("players") or m.game.status != "finished":
				return fail("Maç bitmeden gizli kart kaydı indirilemez.", 409)
			return engine.export_replay(m.game)
	return fail("İşlem bulunamadı.", 404)

func view_or_missing(m: Dictionary) -> Dictionary:
	if m.game != null and not m.game.has("players"):
		return fail("Bu maçın ayrıntıları çevrimdışı kayıtta tutulmuyor.", 404)
	return view(m, 0)

func solo(user: Dictionary, body: Dictionary) -> Dictionary:
	var busy_message = check_free(user)
	if not busy_message.is_empty():
		return fail(busy_message, 409)
	var chapter_id = body.get("chapterId", -1)
	if not (engine.is_int(chapter_id) and int(chapter_id) >= 0 and int(chapter_id) <= 10):
		return fail("Bölüm geçersiz.", 400)
	chapter_id = int(chapter_id)
	if chapter_id > 1 and not user.profile.chapterRewards.has(chapter_id - 1):
		return fail("Önce önceki bölümü tamamla.", 403)
	var options = {}
	var kind = "story"
	if chapter_id >= 1:
		options = chapter_options(chapter_id)
	else:
		kind = "bot"
		var deck = body.get("deck", null)
		if not engine.validate_deck(deck):
			return fail(engine.err, 422)
		if not deck_owned(user.profile, deck):
			return fail("Destede koleksiyonunda olmayan kartlar var.", 403)
		options = {"decks": [engine.int_array(deck), data.decks.tempo.cards]}
	options["entropy"] = entropy()
	var game = engine.create_game(options)
	if game.is_empty():
		return fail(engine.err, 422)
	var m = {"id": new_id(), "code": null, "kind": kind, "chapterId": chapter_id, "users": [user.id, null], "decks": options.decks,
		"status": "playing", "game": game, "version": 1, "deadline": null, "requests": {}, "settled": false, "created": now_ms()}
	var bot_error = bot_turns(m)
	if not bot_error.is_empty():
		return bot_error
	store.matches[m.id] = m
	user.matchId = m.id
	save_store()
	return view(m, 0)

func action(user: Dictionary, m: Dictionary, body: Dictionary) -> Dictionary:
	var request = body.get("requestId", "")
	if not (request is String and request.length() > 0 and request.length() <= 80):
		return fail("Geçerli işlem kimliği gerekli.", 400)
	if m.game == null or not m.game.has("players"):
		return fail("Rakip henüz katılmadı.", 409)
	var act = body.get("action", null)
	if not act is Dictionary:
		return fail("Hamle nesnesi gerekli.", 400)
	var version = body.get("version", -1)
	var key = str(user.id) + ":" + request
	var digest = JSON.stringify({"version": version, "action": act})
	if m.requests.has(key):
		if m.requests[key] != digest:
			return fail("İşlem kimliği başka hamlede kullanıldı.", 409)
		return view(m, 0)
	if not (engine.is_int(version) and int(version) == int(m.version)):
		return fail("Maç ilerledi. Güncel durumu yükle.", 409)
	var next = engine.apply_action(m.game, 0, act)
	if next.is_empty():
		return fail(engine.err, 422)
	m.game = next
	m.version = int(m.version) + 1
	m.requests[key] = digest
	var bot_error = bot_turns(m)
	if not bot_error.is_empty():
		return bot_error
	save_store()
	return view(m, 0)

func leave(user: Dictionary, m: Dictionary) -> Dictionary:
	if m.game != null and m.game.has("players") and m.game.status != "finished":
		var next = engine.apply_action(m.game, 0, {"type": "surrender"})
		if not next.is_empty():
			m.game = next
			m.version = int(m.version) + 1
			settle(m)
	if m.game == null:
		m.status = "cancelled"
	user.matchId = null
	save_store()
	return account_view(user)

func wallet(user: Dictionary, operation: String, body: Dictionary) -> Dictionary:
	var request = body.get("requestId", "")
	if not (request is String and request.length() > 0 and request.length() <= 80):
		return fail("Geçerli işlem kimliği gerekli.", 400)
	var id = body.get("cardId", null)
	var digest = JSON.stringify({"operation": operation, "id": id})
	if user.ops.has(request):
		if user.ops[request].digest != digest:
			return fail("İşlem kimliği başka istekte kullanıldı.", 409)
		var again = user.ops[request].result.duplicate(true)
		again["account"] = account_view(user)
		return again
	user.profile = login_reward(user.profile, today())
	var result = {}
	if operation == "pack":
		var pack = open_pack(user.profile)
		if pack.has("error"):
			return fail(pack.error)
		user.profile = pack.profile
		result["rewards"] = pack.rewards
	else:
		if not (engine.is_int(id) and engine.cards.has(int(id))):
			return fail("Bilinmeyen kart.", 400)
		id = int(id)
		var p = user.profile.duplicate(true)
		var key = str(id)
		var owned = int(p.inventory.get(key, 0))
		var rarity = card_of(id).rarity
		if operation == "craft":
			if owned >= capacity(id):
				return fail("Bu kartın kopyaları tamam.")
			if int(p.dust) < int(CRAFT[rarity]):
				return fail("Yeterli toz yok.")
			p.dust = int(p.dust) - int(CRAFT[rarity])
			grant(p, id)
		elif operation == "dismantle":
			if owned <= 0:
				return fail("Bu karta sahip değilsin.")
			p.inventory[key] = owned - 1
			p.dust = int(p.dust) + int(DUST[rarity])
		elif operation == "archive":
			if int(p.archiveLeft) <= 0:
				return fail("Arşiv seçimi kalmadı.")
			if owned > 0:
				return fail("Arşivden yalnız eksik farklı kart seçilir.")
			grant(p, id)
			p.archiveLeft = int(p.archiveLeft) - 1
		else:
			return fail("İşlem bulunamadı.", 400)
		user.profile = p
	user.ops[request] = {"digest": digest, "result": result.duplicate(true)}
	save_store()
	var out = result.duplicate(true)
	out["account"] = account_view(user)
	return out
