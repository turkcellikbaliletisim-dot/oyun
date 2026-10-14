extends SceneTree
# Kullanım: godot --headless --script tests/offline-parity.gd -- <parity.json>
const Engine_ = preload("res://native/offline_engine.gd")
const Offline = preload("res://native/offline.gd")

func finger(s: Dictionary) -> String:
	var players = []
	for p in s.players:
		players.append({"hp": p.hp, "energy": p.energy, "maxEnergy": p.maxEnergy, "turns": p.turns, "half": p.half, "deck": p.deck, "hand": p.hand,
			"board": p.board, "traps": p.traps, "grave": p.grave, "stats": p.stats, "pinned": p.mulliganPinned})
	return JSON.stringify({"active": s.active, "turn": s.turn, "status": s.status, "winner": s.winner, "reason": s.reason, "pending": s.pending,
		"nextUid": s.nextUid, "first": s.first, "phase": s.phase, "log": s.log.size(), "players": players}, "", true)

func _init() -> void:
	var path = OS.get_cmdline_user_args()[0]
	var games = Offline.intify(JSON.parse_string(FileAccess.get_file_as_string(path)))
	var data = Offline.intify(JSON.parse_string(FileAccess.get_file_as_string("res://native/data.json")))
	var engine = Engine_.new(data.cards)
	var failures = 0
	var steps_total = 0
	for g in games:
		var s = engine.create_game(g.options)
		if s.is_empty():
			print("FAIL ", g.label, " create: ", engine.err)
			failures += 1
			continue
		var want_start = JSON.stringify(Offline.intify(g.start), "", true)
		if finger(s) != want_start:
			print("FAIL ", g.label, " başlangıç farkı")
			failures += 1
			continue
		for i in g.steps.size():
			var step = g.steps[i]
			var p = int(s.active)
			var bot = engine.choose_bot_action(s, p)
			if JSON.stringify(bot, "", true) != JSON.stringify(step.action, "", true):
				print("FAIL ", g.label, " adım ", i, " bot: ", JSON.stringify(bot), " beklenen: ", JSON.stringify(step.action))
				failures += 1
				break
			var next = engine.apply_action(s, int(step.p), step.action)
			if next.is_empty():
				print("FAIL ", g.label, " adım ", i, " uygulama hatası: ", engine.err)
				failures += 1
				break
			s = next
			steps_total += 1
			if finger(s) != JSON.stringify(Offline.intify(step.fp), "", true):
				print("FAIL ", g.label, " adım ", i, " durum farkı\n GD: ", finger(s).substr(0, 600), "\n JS: ", JSON.stringify(step.fp, "", true).substr(0, 600))
				failures += 1
				break
	print("Parity: %d oyun, %d adım, %d hata" % [games.size(), steps_total, failures])
	quit(1 if failures > 0 else 0)
