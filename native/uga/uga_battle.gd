extends Control
# Savaş ekranı: tamamen elle çizilir (düğme kayması olmaz), boyuta göre
# yerleşimi her karede yeniden hesaplar. Simülasyonu sabit adımla ilerletir.

signal finished(result: Dictionary)
signal quit_requested

const D = preload("res://native/uga/uga_data.gd")
const Sim = preload("res://native/uga/uga_sim.gd")

const STAR_COLORS = [Color("b07a4a"), Color("c9d2da"), Color("e6c15a"), Color("3fd0c9"), Color("b06be0"), Color("ff5a4a")]
# battle_bg.png (720x1280) üzerindeki boyalı yolun orta çizgisi
const PATH_IMG = [Vector2(410, -30), Vector2(400, 60), Vector2(425, 130), Vector2(430, 175), Vector2(385, 230), Vector2(345, 290), Vector2(355, 345), Vector2(420, 395), Vector2(440, 450), Vector2(400, 505), Vector2(355, 555), Vector2(370, 610), Vector2(360, 650)]
const PATH = [Vector2(0.12, -0.02), Vector2(0.12, 0.26), Vector2(0.88, 0.26), Vector2(0.88, 0.56), Vector2(0.12, 0.56), Vector2(0.12, 0.84), Vector2(0.5, 0.84), Vector2(0.5, 1.0)]

var sim
var art: Callable
var font: Font
var title_font: Font
var acc: float = 0.0
var speed: int = 1
var auto_on: bool = false
var auto_acc: float = 0.0
var end_delay: float = -1.0
var ended: bool = false
var paused: bool = false
var cur_off: Vector2 = Vector2.ZERO
var tutorial: bool = false
var tut_step: int = 0
var tut_t: float = 0.0
var tut_pair: Array = []
var kick: Dictionary = {}
var enemy_flash: Dictionary = {}
var fx: Array = []
var sfx: Callable
var players: Array = []
var hit_sound_t: float = 0.0

# görsel durum
var shots: Array = []      # {from: Vector2, enemy: id, to: Vector2, age, proj}
var floats: Array = []     # {pos, text, color, age}
var flashes: Array = []    # {slot, age}
var hits: Array = []       # {pos, age, kind}
var shake: float = 0.0
var banner: String = ""
var banner_art: String = ""
var banner_t: float = 0.0
var enemy_pos: Dictionary = {}
var last_enemy_pos: Dictionary = {}

# girdi
var drag_from: int = -1
var drag_pos: Vector2 = Vector2.ZERO
var press_pos: Vector2 = Vector2.ZERO
var info_slot: int = -1
var message: String = ""
var message_t: float = 0.0

# yerleşim (her _draw başında hesaplanır)
var r_hud: Rect2
var r_field: Rect2
var r_board: Rect2
var r_bar: Rect2
var r_power: Rect2
var power_rects: Dictionary = {}
var r_sell: Rect2
var slot_rects: Array = []
var r_summon: Rect2
var r_auto: Rect2
var r_speed: Rect2
var r_exit: Rect2
var potion_rects: Dictionary = {}
var path_pts: PackedVector2Array
var path_len: Array = []

var haptics: bool = true

func buzz(ms: int) -> void:
	if haptics and OS.get_name() in ["Android", "iOS"]:
		Input.vibrate_handheld(ms)

func sound(name: String, vol: float = 0.0) -> void:
	if not sfx.is_valid():
		return
	var st = sfx.call(name)
	if st == null:
		return
	if players.is_empty():
		for i in range(4):
			var pl = AudioStreamPlayer.new()
			add_child(pl)
			players.append(pl)
	for pl in players:
		if not pl.playing:
			pl.stream = st
			pl.volume_db = vol
			pl.play()
			return

func setup(sim_in, art_in: Callable, font_in: Font, title_in: Font) -> void:
	sim = sim_in
	art = art_in
	font = font_in
	title_font = title_in if title_in != null else font_in
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)

var tex_cache: Dictionary = {}
const WORLD_TINT = [Color(1, 1, 1), Color(0.72, 0.85, 0.75), Color(0.8, 0.86, 1.0), Color(1.0, 0.82, 0.62), Color(0.95, 0.66, 0.78)]

func bg_tex() -> Texture2D:
	var own = tex("battle_bg_%d" % (sim.world + 1)) if sim.world > 0 else null
	return own if own != null else tex("battle_bg")

func bg_tint() -> Color:
	if sim.world > 0 and tex("battle_bg_%d" % (sim.world + 1)) != null:
		return Color.WHITE
	return WORLD_TINT[sim.world]

func tex(name: String) -> Texture2D:
	if name == "" or not art.is_valid():
		return null
	if not tex_cache.has(name):
		tex_cache[name] = art.call(name + ".png")
	return tex_cache[name]

# ---------- yerleşim ----------

func layout() -> void:
	var w = size.x
	var h = size.y
	r_hud = Rect2(0, 0, w, 54)
	var bar_h = 112.0
	r_bar = Rect2(0, h - bar_h, w, bar_h)
	var cell = minf((w - 24) / 5.0, 72.0)
	var cell_h = cell * 1.2
	var board_h = cell_h * 3 + 16
	r_power = Rect2(0, r_bar.position.y - 48, w, 46)
	r_board = Rect2((w - cell * 5) / 2.0 - 6, r_power.position.y - board_h - 2, cell * 5 + 12, board_h)
	power_rects = {}
	var pw = (w - 16) / 5.0
	for i in range(sim.deck.size()):
		power_rects[sim.deck[i]] = Rect2(8 + i * pw + 2, r_power.position.y + 3, pw - 4, 40)
	r_field = Rect2(0, r_hud.end.y, w, r_board.position.y - r_hud.end.y - 4)
	slot_rects = []
	for i in range(D.SLOTS):
		var c = i % D.COLS
		var r = i / D.COLS
		slot_rects.append(Rect2(r_board.position.x + 6 + c * cell + 2, r_board.position.y + 8 + r * cell_h + 2, cell - 4, cell_h - 4))
	r_summon = Rect2(w / 2.0 - 78, r_bar.position.y + 10, 156, 58)
	r_sell = Rect2(w / 2.0 - 100, r_bar.position.y + 6, 200, 66)
	r_auto = Rect2(w - 70, r_bar.position.y + 10, 60, 27)
	r_speed = Rect2(w - 70, r_bar.position.y + 41, 60, 27)
	r_exit = Rect2(w - 44, 8, 38, 38)
	potion_rects = {}
	var kinds = ["rage", "gold", "freeze", "heal"]
	for i in range(4):
		var px = 8 + (i % 2) * 44
		var py = r_bar.position.y + 8 + (i / 2) * 44
		potion_rects[kinds[i]] = Rect2(px, py, 40, 40)
	# yol
	path_pts = PackedVector2Array()
	var bg = bg_tex()
	if bg != null:
		var area = Rect2(Vector2(0, r_hud.end.y), Vector2(w, r_bar.position.y - r_hud.end.y))
		var ts = bg.get_size()
		var sc = maxf(area.size.x / ts.x, area.size.y / ts.y)
		var crop = (ts - area.size / sc) / 2.0
		for p in PATH_IMG:
			var q = p * (ts.x / 720.0)
			path_pts.append(area.position + (q - crop) * sc)
	else:
		for p in PATH:
			path_pts.append(Vector2(r_field.position.x + 24 + p.x * (r_field.size.x - 48), r_field.position.y + 8 + p.y * (r_field.size.y - 16)))
	path_len = [0.0]
	for i in range(1, path_pts.size()):
		path_len.append(path_len[i - 1] + path_pts[i].distance_to(path_pts[i - 1]))

func path_at(d: float) -> Vector2:
	if path_pts.size() < 2:
		return Vector2.ZERO
	var target = clampf(d, 0.0, 1.0) * path_len[path_len.size() - 1]
	for i in range(1, path_pts.size()):
		if target <= path_len[i]:
			var seg = path_len[i] - path_len[i - 1]
			var f = 0.0 if seg <= 0.0 else (target - path_len[i - 1]) / seg
			return path_pts[i - 1].lerp(path_pts[i], f)
	return path_pts[path_pts.size() - 1]

# ---------- döngü ----------

func _process(delta: float) -> void:
	if sim == null:
		return
	if size.x <= 0:
		return
	if path_pts.is_empty():
		layout()
	if not paused and not sim.over:
		acc += minf(delta, 0.1) * speed
		var steps = 0
		while acc >= D.TICK and steps < 12:
			acc -= D.TICK
			sim.step()
			steps += 1
			consume_events()
		if auto_on:
			auto_acc += delta * speed
			if auto_acc >= 0.35:
				auto_acc = 0.0
				sim.auto_play_once()
				consume_events()
	elif sim.over and not ended:
		if end_delay < 0.0:
			end_delay = 1.6
		end_delay -= delta
		if end_delay <= 0.0:
			ended = true
			finished.emit(sim.result())
	advance_fx(delta)
	queue_redraw()

func slot_center(i: int) -> Vector2:
	return slot_rects[i].get_center() if i >= 0 and i < slot_rects.size() else Vector2(size.x / 2, r_board.position.y)

func consume_events() -> void:
	for e in sim.events:
		match e.t:
			"shot":
				var to = path_at(float(e.d)) + Vector2(0, -14)
				shots.append({"from": slot_center(e.slot), "to": to, "age": 0.0, "proj": e.proj})
				kick[e.slot] = 0.12
			"hit":
				enemy_flash[e.enemy] = 0.1
				if e.slot >= 0:
					var pos = path_at(float(e.d))
					if e.crit:
						floats.append({"pos": pos + Vector2(randf_range(-8, 8), -18), "text": str(e.dmg) + ("!" if e.crit else ""), "color": Color("ffd25a") if e.crit else Color("ffffff"), "age": 0.0})
						if floats.size() > 40:
							floats.pop_front()
			"die":
				if hit_sound_t <= 0.0:
					sound("hit", -8.0)
					hit_sound_t = 0.12
				var dpos = path_at(float(e.d))
				hits.append({"pos": dpos, "age": 0.0, "kind": "hit_spark"})
				floats.append({"pos": dpos + Vector2(0, -6), "text": "+%d" % int(e.gold), "color": Color("f5c542"), "age": 0.0})
				if e.boss:
					shake = 0.6
					show_banner("BOSS YENİLDİ!", "banner_victory")
			"merge":
				floats.append({"pos": slot_center(e.slot) + Vector2(0, -10), "text": "★".repeat(int(e.stars)), "color": STAR_COLORS[int(e.stars) - 1].lightened(0.3), "age": 0.0})
				if tutorial and tut_step <= 2:
					tut_step = 3
					tut_t = 3.0
				flashes.append({"slot": e.slot, "age": 0.0})
				sound("spell")
				buzz(25)
			"summon":
				if tex("summon_fx") != null:
					fx.append({"rect": slot_rects[e.slot].grow(10), "tex": "summon_fx", "age": 0.0, "dur": 0.45})
				else:
					flashes.append({"slot": e.slot, "age": 0.25})
				sound("card_flip")
			"leak":
				shake = 0.35
				sound("attack", -4.0)
				buzz(60)
			"wave":
				if not sim.is_boss_wave(int(e.n)):
					show_banner("DALGA %d" % int(e.n), "")
			"boss":
				show_banner(str(e.name).to_upper(), "banner_boss_warning")
				sound("turn_start")
				buzz(120)
				shake = 0.4
			"power":
				if power_rects.has(e.hero):
					fx.append({"rect": power_rects[e.hero].grow(12), "tex": "levelup_fx" if tex("levelup_fx") != null else "merge_burst", "age": 0.0, "dur": 0.6})
			"potion":
				show_banner(D.POTIONS[e.kind].name.to_upper(), "")
			"end":
				show_banner("ZAFER!" if e.won else "KALE DÜŞTÜ", "banner_victory" if e.won else "banner_defeat")
				sound("victory" if e.won else "defeat")
	sim.events = []

func find_enemy(id) -> Dictionary:
	for en in sim.enemies:
		if int(en.id) == int(id):
			return en
	return {}

func show_banner(text: String, art_name: String) -> void:
	banner = text
	banner_art = art_name
	banner_t = 1.6

func advance_fx(delta: float) -> void:
	for s in shots:
		s.age += delta * speed
	shots = shots.filter(func(s): return s.age < 0.2)
	for f in floats:
		f.age += delta
		f.pos.y -= 26 * delta
	floats = floats.filter(func(f): return f.age < 0.8)
	for f in flashes:
		f.age += delta
	flashes = flashes.filter(func(f): return f.age < 0.6)
	for h in hits:
		h.age += delta
	hits = hits.filter(func(h): return h.age < 0.35)
	shake = maxf(0.0, shake - delta)
	for f in fx:
		f.age += delta
	fx = fx.filter(func(f): return f.age < f.dur)
	banner_t = maxf(0.0, banner_t - delta)
	message_t = maxf(0.0, message_t - delta)
	hit_sound_t = maxf(0.0, hit_sound_t - delta)
	tut_t = maxf(0.0, tut_t - delta)
	for k in kick.keys():
		kick[k] = float(kick[k]) - delta
		if kick[k] <= 0.0:
			kick.erase(k)
	for k in enemy_flash.keys():
		enemy_flash[k] = float(enemy_flash[k]) - delta
		if enemy_flash[k] <= 0.0:
			enemy_flash.erase(k)
	if tutorial and tut_step == 0 and sim.stats.summons >= 2:
		tut_step = 1
	if tutorial and tut_step == 1:
		for a in range(sim.slots.size()):
			for b in range(a + 1, sim.slots.size()):
				if sim.can_merge(a, b):
					tut_step = 2
					tut_pair = [a, b]

# ---------- çizim ----------

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		layout()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if sim != null and not sim.over:
			paused = true

func text(pos: Vector2, s: String, sz: int, col: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1, f: Font = null) -> void:
	var use = f if f != null else font
	draw_string_outline(use, pos, s, align, width, sz, 4, Color(0, 0, 0, 0.85))
	draw_string(use, pos, s, align, width, sz, col)

func _draw() -> void:
	if sim == null:
		return
	if slot_rects.is_empty():
		layout()
	var off = Vector2(randf_range(-3, 3), randf_range(-3, 3)) * (shake / 0.6) if shake > 0 else Vector2.ZERO
	cur_off = off
	draw_set_transform(off)
	draw_rect(Rect2(Vector2.ZERO, size), Color("0b141c"))
	var bg = bg_tex()
	if bg != null:
		draw_cover(bg, Rect2(Vector2(0, r_hud.end.y), Vector2(size.x, r_bar.position.y - r_hud.end.y)), bg_tint())
	draw_field()
	draw_board()
	draw_set_transform(Vector2.ZERO)
	draw_hud()
	draw_bar()
	draw_overlays()

func draw_cover(t: Texture2D, r: Rect2, mod: Color = Color.WHITE) -> void:
	if t == null:
		return
	var ts = t.get_size()
	var scale = maxf(r.size.x / ts.x, r.size.y / ts.y)
	var src_size = r.size / scale
	var src = Rect2((ts - src_size) / 2.0, src_size)
	draw_texture_rect_region(t, r, src, mod)

func draw_fit(t: Texture2D, r: Rect2, mod: Color = Color.WHITE) -> void:
	if t == null:
		return
	var ts = t.get_size()
	var scale = minf(r.size.x / ts.x, r.size.y / ts.y)
	var s = ts * scale
	draw_texture_rect(t, Rect2(r.position + (r.size - s) / 2.0, s), false, mod)

func draw_field() -> void:
	if tex("battle_bg") == null:
		draw_rect(r_field, Color("1d3326"))
		for i in range(18):
			var x = fmod(i * 97.0, r_field.size.x)
			var y = r_field.position.y + fmod(i * 53.0, r_field.size.y)
			draw_circle(Vector2(x, y), 10 + (i % 4) * 4, Color(0.12, 0.25, 0.16, 0.6))
	# yol
	var pa = 0.0 if tex("battle_bg") != null else 0.9
	if pa > 0.0:
		draw_polyline(path_pts, Color(0.18, 0.12, 0.07, pa), 30.0, true)
		draw_polyline(path_pts, Color(0.62, 0.48, 0.28, pa), 22.0, true)
		draw_polyline(path_pts, Color(0.8, 0.66, 0.42, pa * 0.6), 8.0, true)
	# kapı
	var gate_r = Rect2(path_pts[path_pts.size() - 1] - Vector2(40, 52), Vector2(80, 64))
	var gate = tex("gate_castle")
	if gate != null:
		draw_fit(gate, gate_r)
	else:
		draw_rect(gate_r, Color("4a3a28"))
		draw_rect(gate_r.grow(-10), Color("1a120a"))
	# düşmanlar (arkadan öne)
	var list = sim.enemies.duplicate()
	list.sort_custom(func(a, b): return float(a.d) < float(b.d))
	for en in list:
		var pos = path_at(float(en.d))
		var sz = 70.0 if en.boss else 36.0
		var r = Rect2(pos - Vector2(sz / 2, sz * 0.8), Vector2(sz, sz))
		var mod = Color.WHITE
		if float(en.slow_f) > 0.0 or sim.freeze_t > 0.0:
			mod = Color(0.6, 0.85, 1.0)
		if float(en.poison_t) > 0.0:
			mod = mod * Color(0.75, 1.0, 0.7)
		if enemy_flash.has(en.id):
			mod = Color(1.6, 1.2, 1.2)
		var t = tex(en.art)
		if t == null:
			t = tex("boss_1" if en.boss else "enemy_golem_kucuk")
		if t != null:
			draw_fit(t, r, mod)
		else:
			draw_circle(pos - Vector2(0, sz * 0.35), sz * 0.4, Color("8a2f2f") * mod)
		# can çubuğu
		var hb = Rect2(pos.x - sz * 0.45, r.position.y - 6, sz * 0.9, 5 if not en.boss else 8)
		draw_rect(hb, Color(0, 0, 0, 0.7))
		draw_rect(Rect2(hb.position, Vector2(hb.size.x * clampf(float(en.hp) / float(en.max), 0, 1), hb.size.y)), Color("e04848") if not en.boss else Color("ff8a2a"))
		if float(en.stun_t) > 0.0:
			text(pos + Vector2(-6, -sz), "✦", 14, Color("fff27a"))
	# mermiler
	for s in shots:
		var f = clampf(s.age / 0.2, 0, 1)
		var p = s.from.lerp(s.to, f)
		var pt = tex("proj_" + str(s.proj))
		if pt != null:
			var dir: Vector2 = s.to - s.from
			if s.proj in ["arrow", "spear"]:
				draw_set_transform(p + cur_off, dir.angle() + PI / 4.0)
				draw_fit(pt, Rect2(Vector2(-14, -14), Vector2(28, 28)))
				draw_set_transform(cur_off)
			else:
				draw_fit(pt, Rect2(p - Vector2(13, 13), Vector2(26, 26)))
		else:
			var col = {"arrow": Color("f0e6c8"), "orb": Color("54e0ff"), "fireball": Color("ff7a2a"), "rock": Color("a08a6a"), "spear": Color("e0d0a0")}.get(s.proj, Color.WHITE)
			draw_circle(p, 4.5, col)
			draw_line(p, s.from.lerp(s.to, maxf(0, f - 0.15)), Color(col, 0.5), 2.0)
	for h in hits:
		var ht = tex(h.kind)
		var a = 1.0 - h.age / 0.35
		if ht != null:
			draw_fit(ht, Rect2(h.pos - Vector2(22, 34), Vector2(44, 44)), Color(1, 1, 1, a))
		else:
			draw_circle(h.pos - Vector2(0, 12), 14 * (1.0 - a) + 6, Color(1, 0.9, 0.5, a * 0.7))
	for f in floats:
		var a = 1.0 - f.age / 0.8
		text(f.pos, f.text, 13, Color(f.color, a), HORIZONTAL_ALIGNMENT_CENTER, 0)

func draw_card(r: Rect2, c: Dictionary, alpha: float = 1.0) -> void:
	var stars = int(c.s)
	var col = STAR_COLORS[stars - 1]
	if stars >= 4:
		var glow = tex(["glow_rare", "glow_epic", "glow_legendary"][stars - 4])
		if glow != null:
			var pulse = 0.75 + 0.25 * sin(Time.get_ticks_msec() / 260.0)
			draw_texture_rect(glow, r.grow(r.size.x * 0.18), false, Color(1, 1, 1, alpha * pulse))
	draw_rect(r, Color(0.05, 0.08, 0.12, 0.95 * alpha))
	var h = D.HEROES[c.h]
	var art_name = str(h.art)
	var t = tex(art_name)
	if t == null and art_name.begins_with("unit_"):
		t = tex(art_name + "_%d" % clampi((stars + 1) / 2, 1, 4))
	if t == null and art_name.begins_with("unit_"):
		t = tex(art_name + "_1")
	if t == null:
		t = tex("unit_" + ["kilic", "okcu", "buyucu", "kalkan"][abs(str(c.h).hash()) % 4] + "_%d" % clampi((stars + 1) / 2, 1, 4))
	if t != null:
		draw_cover(t, Rect2(r.position + Vector2(r.size.x * 0.1, r.size.y * 0.08), Vector2(r.size.x * 0.8, r.size.y * 0.74)), Color(1, 1, 1, alpha))
	var frame = tex("card_star_%d" % stars)
	if frame != null:
		draw_texture_rect(frame, r, false, Color(1, 1, 1, alpha))
	else:
		draw_rect(r, Color(col, alpha), false, 3.0)
	# yıldızlar
	var star_text = "★".repeat(stars)
	text(Vector2(r.position.x, r.end.y - 4), star_text, 10 if stars > 3 else 12, Color(col.lightened(0.3), alpha), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)

func draw_board() -> void:
	draw_rect(r_board, Color(0.04, 0.07, 0.1, 0.78))
	draw_rect(r_board, Color("6e6042"), false, 2.0)
	var cell_t = tex("merge_cell")
	for i in range(slot_rects.size()):
		var r: Rect2 = slot_rects[i]
		if cell_t != null:
			draw_texture_rect(cell_t, r, false, Color(1, 1, 1, 0.55))
		else:
			draw_rect(r, Color(0.1, 0.16, 0.22, 0.9))
		var c = sim.slots[i]
		if c == null or i == drag_from:
			continue
		var highlight = drag_from >= 0 and sim.can_merge(drag_from, i)
		if kick.has(i):
			r = Rect2(r.position - Vector2(0, 4.0 * float(kick[i]) / 0.12), r.size)
		draw_card(r, c)
		if highlight:
			draw_rect(r.grow(2), Color("ffe27a"), false, 3.0)
		if i == info_slot:
			draw_rect(r.grow(2), Color("54e0ff"), false, 2.0)
		# bekleme göstergesi
		var interval = float(D.HEROES[c.h].interval)
		var ready = 1.0 - clampf(float(c.cd) / interval, 0.0, 1.0)
		draw_rect(Rect2(r.position.x + 4, r.position.y + 3, (r.size.x - 8) * ready, 2), Color(1, 1, 1, 0.35))
	for f in flashes:
		if f.slot < 0 or f.slot >= slot_rects.size():
			continue
		var a = 1.0 - f.age / 0.6
		var burst = tex("merge_burst")
		var rr: Rect2 = slot_rects[f.slot].grow(14 * (1.0 - a) + 4)
		if burst != null:
			draw_texture_rect(burst, rr, false, Color(1, 1, 1, a))
		else:
			draw_rect(rr, Color(1, 0.9, 0.5, a * 0.6), false, 4.0)
	if drag_from >= 0 and sim.slots[drag_from] != null:
		var dr = Rect2(drag_pos - slot_rects[0].size * 0.55, slot_rects[0].size * 1.1)
		draw_card(dr, sim.slots[drag_from], 0.9)

func icon_text(icon: String, pos: Vector2, s: String, col: Color = Color.WHITE) -> float:
	var t = tex(icon)
	var x = pos.x
	if t != null:
		draw_fit(t, Rect2(x, pos.y - 17, 22, 22))
		x += 24
	text(Vector2(x, pos.y), s, 15, col)
	return x + font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 12

func draw_hud() -> void:
	draw_rect(r_hud, Color(0.03, 0.06, 0.09, 0.9))
	draw_line(Vector2(0, r_hud.end.y), Vector2(size.x, r_hud.end.y), Color("6e6042"), 1.5)
	var world = D.WORLDS[sim.world]
	text(Vector2(10, 20), "%s · Dalga %d/%d" % [world.name, max(sim.wave, 1), D.WAVES_PER_WORLD], 13, Color("ddbf7e"), HORIZONTAL_ALIGNMENT_LEFT, -1, title_font)
	var x = icon_text("icon_heart", Vector2(10, 44), "%d" % sim.castle_hp, Color("ff8a8a"))
	x = icon_text("icon_gold_coin", Vector2(x, 44), "%d" % sim.gold, Color("ffd25a"))
	var alive = sim.enemies.size() + sim.spawn_queue.size()
	x = icon_text("icon_wave", Vector2(x, 44), "%d" % alive, Color("cfe8ff"))
	if sim.boss_timer > 0.0:
		text(Vector2(x, 44), "⏱ %d" % int(ceil(sim.boss_timer)), 15, Color("ff9a5a"))
	for en in sim.enemies:
		if en.boss:
			var bb = Rect2(10, r_hud.end.y + 6, size.x - 20, 14)
			draw_rect(bb, Color(0, 0, 0, 0.75))
			draw_rect(Rect2(bb.position, Vector2(bb.size.x * clampf(float(en.hp) / float(en.max), 0, 1), bb.size.y)), Color("ff7a2a"))
			draw_rect(bb, Color("ddbf7e"), false, 1.5)
			text(Vector2(bb.position.x, bb.end.y - 2), str(en.get("boss_name", "BOSS")), 11, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, bb.size.x)
			break
	# kale can çubuğu
	var hb = Rect2(size.x * 0.52, 12, size.x * 0.48 - 56, 8)
	draw_rect(hb, Color(0, 0, 0, 0.6))
	draw_rect(Rect2(hb.position, Vector2(hb.size.x * float(sim.castle_hp) / float(sim.castle_max), hb.size.y)), Color("4caf50"))
	# çıkış
	draw_rect(r_exit, Color(0.1, 0.12, 0.15, 0.9))
	draw_rect(r_exit, Color("6e6042"), false, 1.5)
	text(r_exit.position + Vector2(0, 26), "II" if not paused else "▶", 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, r_exit.size.x)

func button_rect(r: Rect2, label: String, on: bool, sz: int = 14) -> void:
	draw_rect(r, Color("2a1d0e") if not on else Color("5a3f12"))
	draw_rect(r, Color("ddbf7e") if on else Color("6e6042"), false, 2.0)
	text(Vector2(r.position.x, r.position.y + r.size.y / 2 + sz * 0.35), label, sz, Color("ffe9b0") if on else Color("c8b88e"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)

func draw_power() -> void:
	draw_rect(r_power, Color(0.03, 0.05, 0.08, 0.9))
	for h in power_rects:
		var r: Rect2 = power_rects[h]
		var lv = int(sim.run_levels.get(h, 0))
		var cost = sim.power_cost(h)
		var can = sim.gold >= cost and lv < 5 and not sim.over
		draw_rect(r, Color(0.1, 0.14, 0.18) if not can else Color(0.2, 0.17, 0.08))
		draw_rect(r, Color("ddbf7e") if can else Color("3a4a55"), false, 1.5)
		var ht = tex(str(D.HEROES[h].art))
		if ht == null:
			ht = tex(str(D.HEROES[h].art) + "_1")
		if ht != null:
			draw_cover(ht, Rect2(r.position + Vector2(2, 2), Vector2(32, 36)))
		text(Vector2(r.position.x + 36, r.position.y + 16), "Sv%d" % lv if lv < 5 else "MAX", 11, Color("ffe9b0"))
		if lv < 5:
			text(Vector2(r.position.x + 36, r.position.y + 33), str(cost), 11, Color("ffd25a") if can else Color("8a949b"))

func draw_bar() -> void:
	draw_power()
	draw_rect(r_bar, Color(0.03, 0.05, 0.08, 0.95))
	draw_line(Vector2(0, r_bar.position.y), Vector2(size.x, r_bar.position.y), Color("6e6042"), 1.5)
	# çağır düğmesi
	var can = sim.gold >= sim.summon_cost and sim.free_slot() >= 0 and not sim.over
	var bt = tex("btn_summon")
	if bt != null:
		draw_texture_rect(bt, r_summon, false, Color.WHITE if can else Color(0.55, 0.55, 0.55))
	else:
		draw_rect(r_summon, Color("b8862a") if can else Color("4a4030"))
		draw_rect(r_summon, Color("ffe9b0"), false, 2.0)
	text(Vector2(r_summon.position.x, r_summon.position.y + 27), "ÇAĞIR", 20, Color("2a1500") if can else Color("bbbbbb"), HORIZONTAL_ALIGNMENT_CENTER, r_summon.size.x, title_font)
	var cost_x = r_summon.position.x + r_summon.size.x / 2 - 22
	var coin = tex("icon_gold_coin")
	if coin != null:
		draw_fit(coin, Rect2(cost_x, r_summon.position.y + 32, 18, 18))
	text(Vector2(cost_x + 20, r_summon.position.y + 47), str(sim.summon_cost), 14, Color("2a1500") if can else Color("bbbbbb"))
	text(Vector2(0, r_bar.position.y + 92), "Sürükle: aynı kart + aynı yıldız = birleş", 11, Color("9fb0bb"), HORIZONTAL_ALIGNMENT_CENTER, size.x)
	if drag_from >= 0 and sim.slots[drag_from] != null:
		var over_sell = r_sell.has_point(drag_pos)
		draw_rect(r_sell, Color(0.45, 0.1, 0.08, 0.95 if over_sell else 0.85))
		draw_rect(r_sell, Color("ff9a8a"), false, 3.0 if over_sell else 1.5)
		text(Vector2(r_sell.position.x, r_sell.position.y + 30), "SAT", 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, r_sell.size.x, title_font)
		text(Vector2(r_sell.position.x, r_sell.position.y + 52), "+%d altın" % int(5 * pow(2, int(sim.slots[drag_from].s) - 1)), 13, Color("ffd25a"), HORIZONTAL_ALIGNMENT_CENTER, r_sell.size.x)
	# iksirler
	for k in potion_rects:
		var r: Rect2 = potion_rects[k]
		var n = int(sim.potions.get(k, 0))
		draw_rect(r, Color(0.08, 0.1, 0.13))
		draw_rect(r, Color("6e6042"), false, 1.5)
		var pt = tex(D.POTIONS[k].art)
		var mod = Color.WHITE if n > 0 else Color(0.4, 0.4, 0.4)
		if pt != null:
			draw_fit(pt, r.grow(-3), mod)
		else:
			draw_circle(r.get_center(), 12, {"rage": Color("e04848"), "gold": Color("f5c542"), "freeze": Color("6ad0ff"), "heal": Color("5ad06a")}[k] * mod)
		text(Vector2(r.end.x - 12, r.end.y - 2), str(n), 12, Color.WHITE)
	button_rect(r_auto, "OTO", auto_on, 13)
	button_rect(r_speed, "x%d" % speed, speed > 1, 13)

func draw_overlays() -> void:
	for f in fx:
		var t = tex(f.tex)
		if t != null:
			var a = 1.0 - f.age / f.dur
			var rr: Rect2 = f.rect.grow(10.0 * (1.0 - a))
			draw_texture_rect(t, rr, false, Color(1, 1, 1, a))
	if banner_t > 0.0:
		var a = clampf(banner_t / 0.4, 0, 1)
		var br = Rect2(0, r_field.position.y + r_field.size.y * 0.32, size.x, 86)
		var bt = tex(banner_art) if banner_art != "" else null
		if bt != null:
			draw_fit(bt, br, Color(1, 1, 1, a))
		else:
			draw_rect(Rect2(0, br.position.y + 18, size.x, 50), Color(0, 0, 0, 0.55 * a))
		text(Vector2(0, br.position.y + 52), banner, 26, Color(1, 0.92, 0.7, a), HORIZONTAL_ALIGNMENT_CENTER, size.x, title_font)
	if message_t > 0.0:
		var a = clampf(message_t / 0.3, 0, 1)
		var mr = Rect2(20, r_board.position.y - 40, size.x - 40, 32)
		draw_rect(mr, Color(0, 0, 0, 0.75 * a))
		text(Vector2(mr.position.x, mr.position.y + 22), message, 14, Color(1, 0.85, 0.6, a), HORIZONTAL_ALIGNMENT_CENTER, mr.size.x)
	if info_slot >= 0 and info_slot < sim.slots.size() and sim.slots[info_slot] != null:
		var c = sim.slots[info_slot]
		var h = D.HEROES[c.h]
		var ir = Rect2(12, r_board.position.y - 64, size.x - 24, 58)
		draw_rect(ir, Color(0.04, 0.07, 0.1, 0.95))
		draw_rect(ir, STAR_COLORS[int(c.s) - 1], false, 2.0)
		text(ir.position + Vector2(10, 22), "%s  %s" % [h.name, "★".repeat(int(c.s))], 15, Color("ffe9b0"))
		text(ir.position + Vector2(10, 44), "%s · hasar %d" % [h.text, int(round(sim.hero_damage(info_slot)))], 12, Color("cfd8de"))
	if tutorial and not paused:
		draw_tutorial()
	if paused:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6))
		text(Vector2(0, size.y * 0.4), "DURAKLATILDI", 28, Color("ddbf7e"), HORIZONTAL_ALIGNMENT_CENTER, size.x, title_font)
		button_rect(Rect2(size.x / 2 - 90, size.y * 0.46, 180, 48), "Devam et", true, 16)
		button_rect(Rect2(size.x / 2 - 90, size.y * 0.46 + 60, 180, 48), "Koşuyu bitir", false, 16)

func hint(r: Rect2, msg: String) -> void:
	var pulse = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 180.0)
	draw_rect(r.grow(4 + pulse * 4), Color(1, 0.88, 0.4, 0.5 + pulse * 0.4), false, 3.0)
	var box_r = Rect2(16, r_field.end.y - 70, size.x - 32, 56)
	draw_rect(box_r, Color(0.03, 0.05, 0.08, 0.92))
	draw_rect(box_r, Color("ddbf7e"), false, 2.0)
	text(Vector2(box_r.position.x + 10, box_r.position.y + 24), msg.get_slice("\n", 0), 15, Color("ffe9b0"), HORIZONTAL_ALIGNMENT_CENTER, box_r.size.x - 20)
	if msg.get_slice_count("\n") > 1:
		text(Vector2(box_r.position.x + 10, box_r.position.y + 45), msg.get_slice("\n", 1), 12, Color("cfd8de"), HORIZONTAL_ALIGNMENT_CENTER, box_r.size.x - 20)

func draw_tutorial() -> void:
	match tut_step:
		0:
			hint(r_summon, "ÇAĞIR'a dokun: rastgele bir kahraman gelir\nAltınla kahraman çağır, düşmanlara kendileri saldırır")
		1:
			hint(r_summon, "Biraz daha çağır\nAynı kahramandan iki tane olunca birleştirebilirsin")
		2:
			if tut_pair.size() == 2 and sim.can_merge(tut_pair[0], tut_pair[1]):
				hint(slot_rects[tut_pair[0]].merge(slot_rects[tut_pair[1]]), "Aynı iki kartı üst üste sürükle!\nBirleşince 1 yıldız artar ve rastgele bir kahramana dönüşür")
			else:
				tut_step = 1
		3:
			if tut_t > 0.0:
				hint(r_board, "Harika! Yıldız arttıkça güç katlanır\nİksirler (solda) zor anlarda hayat kurtarır")
			else:
				tut_step = 4

# ---------- girdi ----------

func slot_at(p: Vector2) -> int:
	for i in range(slot_rects.size()):
		if slot_rects[i].grow(2).has_point(p):
			return i
	return -1

func say(s: String) -> void:
	message = s
	message_t = 1.4

func _gui_input(event: InputEvent) -> void:
	var pos = Vector2.ZERO
	var pressed = false
	var released = false
	var motion = false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventScreenTouch:
		pos = event.position
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventMouseMotion or event is InputEventScreenDrag:
		pos = event.position
		motion = true
	else:
		return
	accept_event()
	if paused:
		if pressed:
			if Rect2(size.x / 2 - 90, size.y * 0.46, 180, 48).has_point(pos):
				paused = false
			elif Rect2(size.x / 2 - 90, size.y * 0.46 + 60, 180, 48).has_point(pos):
				paused = false
				sim.over = true
				sim.events.append({"t": "end", "won": false})
				consume_events()
		return
	if motion:
		if drag_from >= 0:
			drag_pos = pos
		return
	if pressed:
		press_pos = pos
		if r_exit.has_point(pos):
			paused = true
			return
		if r_summon.has_point(pos):
			if not sim.summon():
				say(sim.err)
			consume_events()
			return
		if r_auto.has_point(pos):
			auto_on = not auto_on
			return
		if r_speed.has_point(pos):
			speed = 2 if speed == 1 else (3 if speed == 2 else 1)
			return
		for h in power_rects:
			if power_rects[h].has_point(pos):
				if sim.power_up(h):
					say("%s güçlendi! (Sv %d)" % [D.HEROES[h].name, int(sim.run_levels[h])])
				else:
					say(sim.err)
				consume_events()
				return
		for k in potion_rects:
			if potion_rects[k].has_point(pos):
				if not sim.use_potion(k):
					say(sim.err)
				consume_events()
				return
		var s = slot_at(pos)
		if s >= 0 and sim.slots[s] != null:
			drag_from = s
			drag_pos = pos
		else:
			info_slot = -1
		return
	if released and drag_from >= 0:
		var to = slot_at(pos)
		var from = drag_from
		drag_from = -1
		if r_sell.has_point(pos):
			info_slot = -1
			if sim.sell(from):
				sound("pack_open", -6.0)
				say("Satıldı")
			consume_events()
			return
		if to == from or to < 0 or pos.distance_to(press_pos) < 8:
			info_slot = -1 if info_slot == from else from
			return
		info_slot = -1
		if not sim.move(from, to):
			say(sim.err)
		consume_events()
