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
var coins: Array = []
var attack_anim: Dictionary = {}
var ult_glow: Dictionary = {}   # slot -> kalan süre
var lunge: Dictionary = {}      # slot -> {to: Vector2, t: kalan süre}
var hero_face: Dictionary = {}  # slot -> true ise sola bakar
const MELEE = ["kilic", "kalkan"]
var dying: Array = []
var born: Dictionary = {}
var pop: Dictionary = {}
var clock: float = 0.0
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
var host = null

func buzz(ms: int) -> void:
	if haptics and OS.get_name() in ["Android", "iOS"]:
		Input.vibrate_handheld(ms)

var own_sfx: Dictionary = {}

func _exit_tree() -> void:
	for pl in players:
		pl.stop()
		pl.stream = null
	own_sfx.clear()
var shot_sound_t: float = 0.0

var audio_enabled: bool = true

func sound(name: String, vol: float = 0.0) -> void:
	if not audio_enabled or (host != null and host.muted):
		return
	if not own_sfx.has(name):
		var path = "res://native/uga/sfx/%s.ogg" % name
		own_sfx[name] = load(path) if ResourceLoader.exists(path) else null
	var st = own_sfx[name]
	if st == null:
		if not sfx.is_valid():
			return
		st = sfx.call(name)
	if st == null:
		return
	if players.is_empty():
		for i in range(8):
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
	if sim == null:
		return
	var w = size.x
	var h = size.y
	r_hud = Rect2(0, 0, w, 54)
	var bar_h = 112.0
	r_bar = Rect2(0, h - bar_h, w, bar_h)
	var cell = minf((w - 24) / 5.0, 66.0)
	var cell_h = cell * 1.08
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
				var hero_id = str(e.get("h", ""))
				var spot = hero_spot(e.slot)
				hero_face[e.slot] = to.x < spot.x - 2.0
				if MELEE.has(hero_id):
					# yakın dövüşçü hedefe atılır, mermi yok
					lunge[e.slot] = {"to": to + Vector2(0, 14), "t": 0.34}
					if hits.size() < 24:
						hits.append({"pos": to + Vector2(0, 14), "age": -0.12, "kind": "fxs_slash" if tex("fxs_slash") != null else "fx_slash" if tex("fx_slash") != null else "hit_spark"})
				else:
					shots.append({"from": spot + Vector2(0, -hero_size(e.slot) * 0.55), "to": to, "age": 0.0, "proj": e.proj})
				var spec = D.HEROES.get(e.get("h", ""), {})
				var kind = "hit_ice" if spec.has("slow") else "hit_poison" if spec.has("poison") else "hit_spark" if spec.has("splash") or spec.has("burn") else ""
				if spec.has("splash") and tex("fxs_explosion") != null:
					kind = "fxs_explosion"
				elif spec.has("chain") and tex("fxs_lightning") != null:
					kind = "fxs_lightning"
				if kind != "" and hits.size() < 24:
					hits.append({"pos": to + Vector2(0, 14), "age": -0.15, "kind": kind})
				kick[e.slot] = 0.12
				if not attack_anim.has(e.slot):
					attack_anim[e.slot] = 0.36
				if shot_sound_t <= 0.0:
					sound({"arrow": "arrow", "spear": "arrow", "orb": "magic", "rock": "rock", "fireball": "fire"}.get(e.proj, "arrow"), -14.0)
					shot_sound_t = 0.09
			"hit":
				enemy_flash[e.enemy] = 0.1
				if e.slot >= 0:
					var pos = path_at(float(e.d))
					if e.crit or floats.size() < 18:
						floats.append({"pos": pos + Vector2(randf_range(-10, 10), -26), "text": str(e.dmg) + ("!" if e.crit else ""), "color": Color("ffd25a") if e.crit else Color(1, 1, 1, 0.85), "age": 0.0, "size": 16 if e.crit else 11})
						if floats.size() > 40:
							floats.pop_front()
			"die":
				if hit_sound_t <= 0.0:
					sound("coin", -10.0)
					hit_sound_t = 0.1
				var dpos = path_at(float(e.d))
				born.erase(e.enemy)
				if dying.size() < 30:
					dying.append({"pos": dpos, "art": str(e.get("art", "")), "boss": e.boss, "age": 0.0})
				hits.append({"pos": dpos, "age": 0.0, "kind": "hit_spark"})
				if coins.size() < 20:
					coins.append({"from": dpos + Vector2(0, -16), "age": 0.0})
				if e.boss:
					shake = 0.6
					show_banner("BOSS YENİLDİ!", "banner_victory")
			"merge":
				pop[e.slot] = 0.3
				floats.append({"pos": slot_center(e.slot) + Vector2(0, -10), "text": "★".repeat(int(e.stars)), "color": STAR_COLORS[int(e.stars) - 1].lightened(0.3), "age": 0.0})
				if tutorial and tut_step <= 2:
					tut_step = 3
					tut_t = 3.0
				flashes.append({"slot": e.slot, "age": 0.0})
				sound("merge", -2.0)
				buzz(25)
			"summon":
				if tex("summon_fx") != null and e.slot < slot_rects.size():
					fx.append({"rect": slot_rects[e.slot].grow(10), "tex": "summon_fx", "age": 0.0, "dur": 0.45})
					var sp = hero_spot(e.slot)
					fx.append({"rect": Rect2(sp - Vector2(34, 60), Vector2(68, 68)), "tex": "summon_fx", "age": 0.0, "dur": 0.5})
				else:
					flashes.append({"slot": e.slot, "age": 0.25})
				sound("summon", -6.0)
			"leak":
				shake = 0.35
				sound("attack", -4.0)
				buzz(60)
			"clear":
				if path_pts.size() > 0:
					floats.append({"pos": path_pts[path_pts.size() - 1] + Vector2(0, -60), "text": "Dalga temizlendi +%d" % int(e.gold), "color": Color("ffd25a"), "age": 0.0})
			"wave":
				if not sim.is_boss_wave(int(e.n)):
					show_banner("DALGA %d" % int(e.n), "")
					sound("horn", -8.0)
			"boss":
				show_banner(str(e.name).to_upper(), "banner_boss_warning")
				sound("roar")
				buzz(120)
				shake = 0.4
			"power":
				sound("powerup", -4.0)
				if power_rects.has(e.hero):
					fx.append({"rect": power_rects[e.hero].grow(12), "tex": "levelup_fx" if tex("levelup_fx") != null else "merge_burst", "age": 0.0, "dur": 0.6})
			"ult":
				var up = path_at(float(e.d))
				var big = "fxs_explosion" if tex("fxs_explosion") != null else "merge_burst"
				if big.begins_with("fxs_"):
					hits.append({"pos": up + Vector2(0, 30), "age": 0.0, "kind": big, "scale": 2.4})
				else:
					fx.append({"rect": Rect2(up - Vector2(70, 90), Vector2(140, 140)), "tex": big, "age": 0.0, "dur": 0.5})
				ult_glow[e.slot] = 0.7
				attack_anim[e.slot] = 0.36
				var sp2 = hero_spot(e.slot)
				floats.append({"pos": sp2 + Vector2(0, -78), "text": "ULTİ!", "color": Color("ffd25a"), "age": 0.0, "size": 18})
				shake = maxf(shake, 0.22)
				sound("powerup", -6.0)
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
	clock += delta
	for dd in dying:
		dd.age += delta
	dying = dying.filter(func(dd): return dd.age < 0.4)
	for k in attack_anim.keys():
		attack_anim[k] = float(attack_anim[k]) - delta * speed
		if attack_anim[k] <= 0.0:
			attack_anim.erase(k)
	for k in ult_glow.keys():
		ult_glow[k] = float(ult_glow[k]) - delta
		if ult_glow[k] <= 0.0:
			ult_glow.erase(k)
	for k in lunge.keys():
		lunge[k].t = float(lunge[k].t) - delta * speed
		if lunge[k].t <= 0.0:
			lunge.erase(k)
	for k in pop.keys():
		pop[k] = float(pop[k]) - delta
		if pop[k] <= 0.0:
			pop.erase(k)
	for cn in coins:
		cn.age += delta
	coins = coins.filter(func(cn): return cn.age < 0.55)
	for f in fx:
		f.age += delta
	fx = fx.filter(func(f): return f.age < f.dur)
	banner_t = maxf(0.0, banner_t - delta)
	message_t = maxf(0.0, message_t - delta)
	hit_sound_t = maxf(0.0, hit_sound_t - delta)
	shot_sound_t = maxf(0.0, shot_sound_t - delta)
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

var frame_cache: Dictionary = {}
const SHEET_LEFT = []

func frame_tex(name: String, frame: int, count: int = 4) -> Texture2D:
	# Yatay şerit (sprite sheet) içinden tek kare.
	var key = "%s#%d" % [name, frame]
	if frame_cache.has(key):
		return frame_cache[key]
	var sheet = tex(name)
	if sheet == null:
		return null
	var at = AtlasTexture.new()
	at.atlas = sheet
	var w = sheet.get_width() / float(count)
	at.region = Rect2(w * (frame % count), 0, w, sheet.get_height())
	frame_cache[key] = at
	return at

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
	# düşmanlar ve arenadaki kahramanlar: y sırasına göre (arkadan öne)
	var items: Array = []
	for en in list:
		items.append({"y": enemy_screen_pos(en).y, "en": en})
	for i in range(sim.slots.size()):
		if sim.slots[i] != null:
			items.append({"y": hero_spot(i).y, "slot": i})
	items.sort_custom(func(x, y): return float(x.y) < float(y.y))
	for it in items:
		if it.has("en"):
			draw_enemy(it.en)
		else:
			draw_hero(int(it.slot))
	for dd in dying:
		var dt = tex(dd.art)
		if dt == null:
			continue
		var f = dd.age / 0.4
		var dsz = (124.0 if dd.boss else 44.0) * (1.0 - 0.5 * f)
		var dp = dd.pos + Vector2(0, -dsz * 0.6 - 30.0 * f)
		draw_set_transform(dp + cur_off, f * 1.2, Vector2.ONE)
		draw_fit(dt, Rect2(-Vector2(dsz, dsz) / 2.0, Vector2(dsz, dsz)), Color(1.6, 1.3, 1.3, 1.0 - f))
		draw_set_transform(cur_off)
	# mermiler
	for s in shots:
		var f = clampf(s.age / 0.2, 0, 1)
		var p = s.from.lerp(s.to, f)
		var pt = tex("proj_" + str(s.proj))
		var tcol = {"arrow": Color("f0e6c8"), "orb": Color("54e0ff"), "fireball": Color("ff7a2a"), "rock": Color("c0a880"), "spear": Color("e0d0a0")}.get(s.proj, Color.WHITE)
		draw_line(p, s.from.lerp(s.to, maxf(0.0, f - 0.25)), Color(tcol, 0.45), 3.0, true)
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
		if h.age < 0.0:
			continue
		var ht = tex(h.kind)
		var a = 1.0 - h.age / 0.35
		if ht != null and str(h.kind).begins_with("fxs_"):
			# 4 karelik efekt şeridi
			var fr = clampi(int(h.age / 0.35 * 4.0), 0, 3)
			var hs = 60.0 * float(h.get("scale", 1.0))
			draw_fit(frame_tex(h.kind, fr), Rect2(h.pos - Vector2(hs / 2.0, hs * 0.77), Vector2(hs, hs)), Color(1, 1, 1, minf(1.0, a * 2.0)))
		elif ht != null:
			draw_fit(ht, Rect2(h.pos - Vector2(22, 34), Vector2(44, 44)), Color(1, 1, 1, a))
		else:
			draw_circle(h.pos - Vector2(0, 12), 14 * (1.0 - a) + 6, Color(1, 0.9, 0.5, a * 0.7))
	for f in floats:
		var a = 1.0 - f.age / 0.8
		text(f.pos, f.text, int(f.get("size", 13)), Color(f.color, a * f.color.a), HORIZONTAL_ALIGNMENT_CENTER, 0)

func enemy_screen_pos(en: Dictionary) -> Vector2:
	# kalabalık tek çizgide üst üste binmesin: yolun iki yanına küçük şerit kayması
	var d = float(en.d)
	var p = path_at(d)
	if en.boss:
		return p
	var ahead = path_at(minf(1.0, d + 0.01))
	var dir = ahead - p
	if dir.length() < 0.01:
		return p
	var nrm = Vector2(-dir.y, dir.x).normalized()
	return p + nrm * float((int(en.id) * 37) % 5 - 2) * 7.0

func draw_enemy(en: Dictionary) -> void:
	var pos = enemy_screen_pos(en)
	var sz = 124.0 if en.boss else 44.0
	if en.boss:
		# boss altında kırmızı tehdit halkası
		var pr = 0.5 + 0.5 * sin(clock * 5.0)
		draw_set_transform(pos + Vector2(0, -4) + cur_off, 0.0, Vector2(1.0, 0.35))
		draw_circle(Vector2.ZERO, sz * 0.5, Color(0.8, 0.1, 0.05, 0.25 + 0.15 * pr))
		draw_arc(Vector2.ZERO, sz * 0.52, 0, TAU, 32, Color(1.0, 0.35, 0.2, 0.7), 3.0, true)
		draw_set_transform(cur_off)
	var moving = float(en.stun_t) <= 0.0 and sim.freeze_t <= 0.0
	var bob = absf(sin(Time.get_ticks_msec() / 110.0 + int(en.id) * 1.7)) * (3.0 if moving else 0.0)
	var ahead = path_at(minf(1.0, float(en.d) + 0.01))
	var face_left = ahead.x < path_at(float(en.d)).x - 0.5
	if not born.has(en.id):
		born[en.id] = clock
	var grow_in = clampf((clock - float(born[en.id])) / 0.25, 0.2, 1.0)
	var has_walk = tex("walk_" + str(en.art).trim_prefix("enemy_")) != null
	var squash = 1.0 + (0.07 * sin(clock * 13.0 + int(en.id)) if moving and not has_walk else 0.0)
	var w_sz = sz * grow_in / squash
	var h_sz = sz * grow_in * squash
	var r = Rect2(pos - Vector2(w_sz / 2, h_sz * 0.8 + bob), Vector2(w_sz, h_sz))
	var mod = Color.WHITE
	if float(en.slow_f) > 0.0 or sim.freeze_t > 0.0:
		mod = Color(0.6, 0.85, 1.0)
	if float(en.poison_t) > 0.0:
		mod = mod * Color(0.75, 1.0, 0.7)
	if enemy_flash.has(en.id):
		mod = Color(1.6, 1.2, 1.2)
	var t = null
	var walk_name = "walk_" + str(en.art).trim_prefix("enemy_")
	if tex(walk_name) != null:
		var wf = int(clock * (9.0 if moving else 0.0) + int(en.id)) % 4
		t = frame_tex(walk_name, wf)
	if t == null:
		t = tex(en.art)
	if t == null:
		t = tex("boss_1" if en.boss else "enemy_golem_kucuk")
	draw_circle(pos + Vector2(0, -2), sz * 0.28, Color(0, 0, 0, 0.28))
	if t != null:
		# resimler ve yürüme şeritleri sağa bakar; SHEET_LEFT listesindekiler sola
		var flip = face_left != (has_walk and SHEET_LEFT.has(walk_name))
		if flip:
			draw_set_transform(Vector2(r.get_center().x * 2.0, 0) + cur_off, 0.0, Vector2(-1, 1))
		# koyu dış hat: kalabalık arka planda düşman seçilsin
		for o in [Vector2(-1.5, 0), Vector2(1.5, 0), Vector2(0, -1.5), Vector2(0, 1.5)]:
			draw_fit(t, Rect2(r.position + o, r.size), Color(0, 0, 0, 0.55))
		draw_fit(t, r, mod)
		if flip:
			draw_set_transform(cur_off)
	else:
		draw_circle(pos - Vector2(0, sz * 0.35), sz * 0.4, Color("8a2f2f") * mod)
	# can çubuğu (yalnızca hasar almışsa ya da boss ise; kalabalıkta karmaşa olmasın)
	if not en.boss and float(en.hp) >= float(en.max) - 0.01:
		return
	var hb = Rect2(pos.x - sz * 0.45, r.position.y - 6, sz * 0.9, 5 if not en.boss else 8)
	draw_rect(hb, Color(0, 0, 0, 0.7))
	draw_rect(Rect2(hb.position, Vector2(hb.size.x * clampf(float(en.hp) / float(en.max), 0, 1), hb.size.y)), Color("e04848") if not en.boss else Color("ff8a2a"))
	if float(en.stun_t) > 0.0:
		text(pos + Vector2(-6, -sz), "✦", 14, Color("fff27a"))

func hero_spot(i: int) -> Vector2:
	# Arenadaki diziliş: kart tahtasının 5x3 düzeni kalenin önünde savunma hattına dönüşür.
	# Üst satır (0) en önde, alt satır kapının hemen önünde.
	var c = i % D.COLS
	var r = i / D.COLS
	var top = r_field.position.y + r_field.size.y * 0.5
	var row_h = r_field.size.y * 0.15
	var xf = [0.09, 0.27, 0.5, 0.73, 0.91][c]
	var y = top + r * row_h + row_h
	if c == 2:
		# orta sütun yolu kapatmasın: kapının iki yanına
		xf = 0.38 if r % 2 == 0 else 0.62
		y += row_h * 0.45
	return Vector2(r_field.position.x + r_field.size.x * xf, y)

func hero_size(i: int) -> float:
	var c = sim.slots[i] if i >= 0 and i < sim.slots.size() else null
	var stars = 1 if c == null else int(c.s)
	return 56.0 + stars * 5.0

func hero_frame_tex(h: String, frame: int) -> Texture2D:
	var t = frame_tex("attack_" + h, frame)
	if t != null:
		return t
	var art_name = str(D.HEROES[h].art)
	t = tex(art_name)
	if t == null:
		t = tex(art_name + "_1")
	return t

func draw_hero(i: int) -> void:
	var c = sim.slots[i]
	if c == null:
		return
	var h = str(c.h)
	var stars = int(c.s)
	var col = STAR_COLORS[stars - 1]
	var base = hero_spot(i)
	var pos = base
	if lunge.has(i):
		# yakın dövüş: hedefe atıl ve geri dön
		var f = 1.0 - float(lunge[i].t) / 0.34
		var reach = sin(clampf(f, 0.0, 1.0) * PI)
		pos = base.lerp(lunge[i].to, reach * 0.75)
	var sz = hero_size(i)
	if pop.has(i):
		sz *= 1.0 + 0.35 * float(pop[i]) / 0.3
	if i == drag_from:
		sz *= 0.9
	# zemin halkası: yıldız rengi, 4★ ve üstü parlar
	var ring_a = 0.55 + (0.25 * sin(clock * 4.0 + i) if stars >= 4 else 0.0)
	draw_set_transform(pos + Vector2(0, -3) + cur_off, 0.0, Vector2(1.0, 0.38))
	draw_circle(Vector2.ZERO, sz * 0.42, Color(0, 0, 0, 0.35))
	draw_arc(Vector2.ZERO, sz * 0.44, 0, TAU, 28, Color(col, ring_a), 3.0, true)
	if D.HEROES[h].has("aura"):
		draw_arc(Vector2.ZERO, sz * 0.62 + 3.0 * sin(clock * 3.0), 0, TAU, 28, Color(1.0, 0.9, 0.5, 0.35), 2.0, true)
	draw_set_transform(cur_off)
	if ult_glow.has(i):
		var ug = float(ult_glow[i]) / 0.7
		var gl = tex("glow_legendary")
		if gl != null:
			draw_fit(gl, Rect2(pos - Vector2(sz * 0.9, sz * 1.3), Vector2(sz * 1.8, sz * 1.8)), Color(1, 1, 1, ug))
		else:
			draw_circle(pos - Vector2(0, sz * 0.45), sz * 0.7, Color(1, 0.85, 0.3, 0.35 * ug))
	# kare: saldırıda şeridin 4 karesi, beklerken 0. kare ve hafif nefes
	var frame = 0
	if attack_anim.has(i):
		frame = clampi(int((1.0 - float(attack_anim[i]) / 0.36) * 4.0), 0, 3)
	var t = hero_frame_tex(h, frame)
	if t == null:
		return
	var breathe = 0.0 if attack_anim.has(i) else sin(clock * 2.4 + i * 0.9) * 0.03
	var w = sz * (1.0 - breathe * 0.5)
	var hh = sz * (1.0 + breathe)
	var r = Rect2(pos - Vector2(w / 2.0, hh * 0.92), Vector2(w, hh))
	var flip = hero_face.get(i, false)
	if flip:
		draw_set_transform(Vector2(r.get_center().x * 2.0, 0) + cur_off, 0.0, Vector2(-1, 1))
	for o in [Vector2(-1.5, 0), Vector2(1.5, 0), Vector2(0, -1.5), Vector2(0, 1.5)]:
		draw_fit(t, Rect2(r.position + o * 1.4, r.size), Color(0.02, 0.03, 0.05, 0.85))
	draw_fit(t, r, Color(1.25, 1.2, 1.1) if attack_anim.has(i) and float(attack_anim[i]) > 0.2 else Color.WHITE)
	if flip:
		draw_set_transform(cur_off)
	# yıldızlar
	text(Vector2(pos.x - 30, pos.y + 11), "★".repeat(stars), 9, col.lightened(0.35), HORIZONTAL_ALIGNMENT_CENTER, 60)

func draw_card(r: Rect2, c: Dictionary, alpha: float = 1.0, life: float = 0.0, attack: float = 0.0, atk_frame: int = -1) -> void:
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
	if atk_frame >= 0 and tex("attack_" + str(c.h)) != null:
		t = frame_tex("attack_" + str(c.h), atk_frame)
		attack = 0.0
	if t != null:
		var art_r = Rect2(r.position + Vector2(r.size.x * 0.1, r.size.y * 0.08), Vector2(r.size.x * 0.8, r.size.y * 0.74))
		var breathe = 1.0 + 0.025 * sin(clock * 2.2 + life)
		var lunge = 1.0 + 0.12 * attack
		var s_art = art_r.size * Vector2(breathe * lunge, (2.0 - breathe) * lunge)
		var a_rect = Rect2(art_r.get_center() - s_art / 2.0 + Vector2(0, -3.0 * attack), s_art).intersection(r.grow(-2))
		draw_cover(t, a_rect, Color(1, 1, 1, alpha) * (Color(1.35, 1.25, 1.1) if attack > 0.3 else Color.WHITE))
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
		var atk = 0.0
		if kick.has(i):
			atk = float(kick[i]) / 0.12
			r = Rect2(r.position - Vector2(0, 5.0 * atk), r.size)
		if pop.has(i):
			var pf = float(pop[i]) / 0.3
			r = r.grow(r.size.x * 0.22 * pf)
		var af = -1
		if attack_anim.has(i):
			af = clampi(int((1.0 - float(attack_anim[i]) / 0.36) * 4.0), 0, 3)
		draw_card(r, c, 1.0, float(i) * 0.7, atk, af)
		if kick.has(i):
			draw_rect(r, Color(1, 0.95, 0.7, 0.5 * float(kick[i]) / 0.12), false, 2.0)
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
	for en in sim.enemies:
		if en.boss:
			# büyük boss çubuğu: portre + ad + can + süre
			var panel = Rect2(6, r_hud.end.y + 4, size.x - 12, 40)
			draw_rect(panel, Color(0.05, 0.02, 0.02, 0.85))
			draw_rect(panel, Color("ff7a2a"), false, 2.0)
			var bt_ = tex(str(en.art))
			if bt_ != null:
				draw_fit(bt_, Rect2(panel.position + Vector2(4, 2), Vector2(36, 36)))
			var bb = Rect2(panel.position.x + 46, panel.position.y + 20, panel.size.x - 100, 14)
			draw_rect(bb, Color(0, 0, 0, 0.8))
			draw_rect(Rect2(bb.position, Vector2(bb.size.x * clampf(float(en.hp) / float(en.max), 0, 1), bb.size.y)), Color("ff4a2a"))
			draw_rect(bb, Color("ddbf7e"), false, 1.0)
			text(Vector2(bb.position.x, panel.position.y + 16), str(en.get("boss_name", "BOSS")).to_upper(), 13, Color("ffd2a0"), HORIZONTAL_ALIGNMENT_LEFT, -1, title_font)
			if sim.boss_timer > 0.0:
				var urg = sim.boss_timer < 10.0 and int(Time.get_ticks_msec() / 250) % 2 == 0
				text(Vector2(panel.end.x - 52, panel.position.y + 30), "⏱%d" % int(ceil(sim.boss_timer)), 18, Color("ff4a3a") if urg else Color("ffd25a"), HORIZONTAL_ALIGNMENT_CENTER, 48)
			break
	# kale can çubuğu
	var hb = Rect2(size.x * 0.64, 32, size.x * 0.36 - 56, 10)
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
		text(Vector2(r.position.x + 35, r.position.y + 16), ("▲Sv%d" % lv) if lv < 5 else "MAX", 11, Color("ffe9b0") if lv > 0 else Color("c8d2d8"))
		if lv < 5:
			var ct = tex("icon_gold_coin")
			if ct != null:
				draw_fit(ct, Rect2(r.position.x + 35, r.position.y + 22, 12, 12))
			text(Vector2(r.position.x + 48, r.position.y + 33), str(cost), 11, Color("ffd25a") if can else Color("8a949b"))

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
	text(Vector2(r_summon.position.x, r_summon.position.y + 27), "ÇAĞIR", 20, Color("ffe9b0") if can else Color("9a9a9a"), HORIZONTAL_ALIGNMENT_CENTER, r_summon.size.x, title_font)
	var cost_x = r_summon.position.x + r_summon.size.x / 2 - 22
	var coin = tex("icon_gold_coin")
	if coin != null:
		draw_fit(coin, Rect2(cost_x, r_summon.position.y + 32, 18, 18))
	text(Vector2(cost_x + 20, r_summon.position.y + 47), str(sim.summon_cost), 14, Color("ffd25a") if can else Color("9a9a9a"))
	if int(sim.stats.merges) < 3:
		text(Vector2(0, r_bar.position.y + 92), "Sürükle: aynı kart + aynı yıldız = birleş", 11, Color("9fb0bb"), HORIZONTAL_ALIGNMENT_CENTER, size.x)
	else:
		text(Vector2(0, r_bar.position.y + 92), "Kartı aşağı sürükle = sat", 11, Color("6f7f8a"), HORIZONTAL_ALIGNMENT_CENTER, size.x)
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
	var coin_t = tex("icon_gold_coin")
	var target = Vector2(78, 36)
	for cn in coins:
		var f = clampf(cn.age / 0.55, 0, 1)
		var p = cn.from.lerp(target, f * f) + Vector2(0, -60.0 * sin(f * PI))
		if coin_t != null:
			draw_fit(coin_t, Rect2(p - Vector2(9, 9), Vector2(18, 18)))
		else:
			draw_circle(p, 7, Color("f5c542"))
	if not sim.over and sim.castle_hp > 0 and sim.castle_hp <= maxi(3, sim.castle_max / 4):
		var pulse = 0.25 + 0.2 * sin(Time.get_ticks_msec() / 160.0)
		var edge = Color(0.9, 0.1, 0.05, pulse)
		draw_rect(Rect2(0, 0, size.x, 10), edge)
		draw_rect(Rect2(0, size.y - 10, size.x, 10), edge)
		draw_rect(Rect2(0, 0, 10, size.y), edge)
		draw_rect(Rect2(size.x - 10, 0, 10, size.y), edge)
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
		if host != null:
			button_rect(Rect2(size.x / 2 - 90, size.y * 0.46 + 120, 180, 48), "Ses: kapalı" if host.muted else "Ses: açık", not host.muted, 16)
			button_rect(Rect2(size.x / 2 - 90, size.y * 0.46 + 180, 180, 48), "Titreşim: açık" if haptics else "Titreşim: kapalı", haptics, 16)

func hint(r: Rect2, msg: String) -> void:
	var pulse = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 180.0)
	draw_rect(r.grow(4 + pulse * 4), Color(1, 0.88, 0.4, 0.5 + pulse * 0.4), false, 3.0)
	# kutu hedefin üstüne binmesin: hedef alttaysa tahtanın ortasına, tahtadaysa alanın üstüne
	var box_y = r_field.position.y + 12
	if r.position.y >= r_power.position.y:
		box_y = r_board.position.y + 6
	var box_r = Rect2(16, box_y, size.x - 32, 56)
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
				tut_t = 4.0
		4:
			if tut_t > 0.0:
				hint(r_power, "Alttaki şerit: GÜÇLENDİR\nAltın harcayıp o kahraman türünün tümünü %25 güçlendir")
			else:
				tut_step = 5

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
	# Yalnızca dokunma olayları: masaüstünde fare dokunmaya çevrilir
	# (emulate_touch_from_mouse), telefonda dokunma fareye de çevrilir;
	# ikisini birden işlemek her dokunuşu iki kez sayardı.
	if event is InputEventMouse:
		accept_event()
		return
	if event is InputEventScreenTouch and event.index == 0:
		pos = event.position
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventScreenDrag and event.index == 0:
		pos = event.position
		motion = true
	else:
		return
	accept_event()
	if paused:
		if pressed:
			if Rect2(size.x / 2 - 90, size.y * 0.46, 180, 48).has_point(pos):
				paused = false
			elif host != null and Rect2(size.x / 2 - 90, size.y * 0.46 + 120, 180, 48).has_point(pos):
				host.toggle_sound()
				if not host.muted:
					host.set_music("music_battle")
			elif Rect2(size.x / 2 - 90, size.y * 0.46 + 180, 180, 48).has_point(pos):
				haptics = not haptics
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
