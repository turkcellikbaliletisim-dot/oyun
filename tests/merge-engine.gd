extends SceneTree
# Birleştirme modu kural testi (deterministik).
const Merge = preload("res://native/merge_engine.gd")
const Offline = preload("res://native/offline.gd")
var failed = false
func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
func _initialize() -> void:
	var e = Merge.new()
	var s = Merge.new_run(42)
	check(Merge.buy_cost(s) == 10, "ilk alım 10 altın")
	check(not e.buy(s).is_empty() and int(s.gold) == 20, "alım altın düşer")
	check(Merge.board_units(s) == 1, "bir birlik")
	var first = s.board.find(s.board.filter(func(c): return c != null)[0])
	# aynı birlikten ikincisini elle koy ve birleştir
	var u = s.board[first]
	var other = (first + 1) % s.board.size()
	s.board[other] = {"k": u.k, "t": 1}
	check(not e.move(s, other, first).is_empty() and int(s.board[first].t) == 2 and s.board[other] == null, "birleştirme seviye artırır")
	s.board[other] = {"k": (int(u.k) + 1) % 4, "t": 2}
	check(not e.move(s, other, first).is_empty() and int(s.board[first].t) == 2 and int(s.board[other].k) == int(u.k) and int(s.board[first].k) != int(u.k), "farklı tür yer değiştirir")
	s.gold = 0
	check(e.buy(s).is_empty() and e.err != "", "altın yetmeyince alım reddedilir")
	# deterministik tohum
	var a = Merge.new_run(7); var b = Merge.new_run(7)
	for i in range(3):
		e.buy(a); e.buy(b)
	check(JSON.stringify(a) == JSON.stringify(b), "aynı tohum aynı sonuç")
	# güçlü tahta ilk dalgayı geçer, boş tahta savaşamaz
	var w = Merge.new_run(1)
	check(e.battle(w).is_empty(), "boş tahtayla savaş yok")
	for i in range(6):
		w.board[i] = {"k": i % 4, "t": 3}
	var r = e.battle(w)
	check(r.won and int(w.wave) == 2, "güçlü tahta kazanır")
	# zayıf tahta kayıp yaşatır, 3 kayıpta koşu biter
	var l = Merge.new_run(1)
	l.wave = 12
	l.board[0] = {"k": 0, "t": 1}
	for i in range(3):
		e.battle(l)
	check(l.over and int(l.lives) == 0, "üç kayıp koşuyu bitirir")
	check(e.buy(l).is_empty(), "bitmiş koşuda eylem yok")
	check(Merge.stars_for_best(12) == 2, "yeniden doğuş yıldızı")
	# totem ve boss
	var t = Merge.new_run(3)
	check(not e.choose_totem(t, 0, 0).is_empty() and int(t.totem) == 0, "ilk totem açık")
	check(e.choose_totem(t, 1, 0).is_empty(), "kilitli totem reddedilir")
	check(not e.choose_totem(t, 3, 15).is_empty() and int(t.lives) == 4, "can totemi +1 can")
	check(not e.choose_totem(t, 0, 15).is_empty() and int(t.lives) == 3, "totem değişince can geri alınır")
	t.board[0] = {"k": 0, "t": 1}
	var st = Merge.unit_stats(t.board[0], t)
	check(st.atk == int(round(3 * 1.15)), "savaş totemi saldırıyı artırır")
	check(Merge.is_boss(5) and not Merge.is_boss(4), "5. dalga boss")
	var foes = Merge.enemy_wave(5)
	check(foes[foes.size() - 1].has("boss"), "boss düşmanı eklenir")
	var f = Merge.new_run(2)
	for i in range(8):
		f.board[i] = {"k": i % 4, "t": 4}
	var fr = e.battle(f)
	check(fr.frames.size() > 0 and fr.frames.size() <= 40, "savaş kareleri")
	# çevrimdışı sunucu rotaları
	var dir = OS.get_environment("DESTAN_SESSION_DIR")
	if dir.is_empty():
		dir = "/tmp"
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://native/data.json"))
	var srv = Offline.new(data, dir + "/merge-test.json")
	srv.store.user = {"id": "u1", "matchId": null, "profile": srv.new_profile()}
	var v = srv.handle("merge", 0, {})
	check(v.has("state") and int(v.state.gold) == 30, "merge görünümü")
	v = srv.handle("merge/buy", 1, {})
	check(not v.has("error") and int(v.state.gold) == 20, "merge/buy")
	v = srv.handle("merge/battle", 1, {})
	check(v.has("battle"), "merge/battle")
	v = srv.handle("merge/restart", 1, {})
	check(int(v.state.wave) == 1, "merge/restart")
	DirAccess.remove_absolute(dir + "/merge-test.json")
	print("MERGE " + ("FAIL" if failed else "OK"))
	quit(1 if failed else 0)
