extends RefCounted
# UGACHA modu menüleri: ana merkez, kahramanlar, totemler, sandıklar,
# görevler, yeniden doğuş ve koşu sonu. Tüm satırlar 370 px genişliğe sığacak
# şekilde sabit/esnek ölçülerle kurulur (taşma ve kayma olmasın).

const D = preload("res://native/uga/uga_data.gd")
const Meta = preload("res://native/uga/uga_meta.gd")
const Sim = preload("res://native/uga/uga_sim.gd")
const Battle = preload("res://native/uga/uga_battle.gd")
const Sprite = preload("res://native/uga/uga_sprite.gd")

const GOLD_C = Color("ddbf7e")
const INK = Color("f7ecd4")
const MUTED = Color("a7b4bd")
const STAR_COLORS = [Color("b07a4a"), Color("c9d2da"), Color("e6c15a"), Color("3fd0c9"), Color("b06be0"), Color("ff5a4a")]

var app
var meta
var world_sel: int = 0
var deck_slot: int = 0
var last_result: Dictionary = {}
var last_reward: Dictionary = {}
var chest_reward: Dictionary = {}
var battle = null
var offline_gold: int = 0
var board_data: Dictionary = {}
var board_loading: bool = false
var race: Dictionary = {}
var race_active: String = ""
var race_input: String = ""
var challenge_active: bool = false
var challenge_gain: int = 0

func _init(app_in) -> void:
	app = app_in
	meta = Meta.new(Meta.default_path())
	offline_gold = meta.compute_offline()
	if offline_gold > 0:
		meta.collect_offline()
	world_sel = int(meta.p.world)
	meta.ensure_missions()

# ---------- küçük yapı taşları ----------

func art(file: String) -> Texture2D:
	return app.skin_art(file)

func hero_art(h: String, stars: int = 1) -> Texture2D:
	var base = str(D.HEROES[h].art)
	var t = art(base + ".png")
	if t == null and base.begins_with("unit_"):
		t = art(base + "_%d.png" % clampi((stars + 1) / 2, 1, 4))
	if t == null:
		t = art("unit_kilic_1.png")
	return t

func icon(parent: Node, file: String, s: float) -> TextureRect:
	var r = TextureRect.new()
	r.texture = art(file)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(s, s)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r

func row(parent: Node, sep: int = 8) -> HBoxContainer:
	var r = HBoxContainer.new()
	r.add_theme_constant_override("separation", sep)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(r)
	return r

func txt(s: String, parent: Node, size: int = 15, color: Color = INK, wrap: bool = false) -> Label:
	var l = Label.new()
	l.text = s
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 3)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	if wrap:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.custom_minimum_size.x = 10
	l.clip_text = false
	parent.add_child(l)
	return l

func title(s: String, parent: Node, size: int = 22) -> Label:
	var l = txt(s, parent, size, GOLD_C)
	if app.portrait_font != null:
		l.add_theme_font_override("font", app.portrait_font)
	return l

func btn(s: String, parent: Node, cb: Callable, disabled: bool = false, gold: bool = false, h: float = 42) -> Button:
	var b = Button.new()
	b.text = s
	b.disabled = disabled
	b.custom_minimum_size = Vector2(0, h)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_text = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 15 if gold else 14)
	var bg = Color("b8862a") if gold else Color("1d2a33")
	var border = Color("ffe2a0") if gold else Color("6e6042")
	b.add_theme_stylebox_override("normal", app.box(bg, border, 2, 10, 6))
	b.add_theme_stylebox_override("hover", app.box(bg.lightened(0.08), border, 2, 10, 6))
	b.add_theme_stylebox_override("pressed", app.box(bg.darkened(0.15), border, 2, 10, 6))
	b.add_theme_stylebox_override("disabled", app.box(Color("2a2f33"), Color("3a4249"), 1, 10, 6))
	b.add_theme_color_override("font_color", Color("2a1500") if gold else INK)
	b.add_theme_color_override("font_hover_color", Color("2a1500") if gold else Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color("2a1500") if gold else Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color("7a858c"))
	if app.portrait_font != null and gold:
		b.add_theme_font_override("font", app.portrait_font)
		b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(func(): click(); cb.call())
	parent.add_child(b)
	return b

func click() -> void:
	var st = app.sfx_stream("click")
	if st != null and not app.muted and app.audio != null:
		app.audio.stream = st
		app.audio.play()

func card_panel(parent: Node, border: Color = Color("6e6042")) -> VBoxContainer:
	var holder = PanelContainer.new()
	holder.add_theme_stylebox_override("panel", app.box(Color(0.06, 0.1, 0.13, 0.94), border, 1, 12, 10))
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(holder)
	var inner = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	holder.add_child(inner)
	return inner

func stat(parent: Node, file: String, value: String, color: Color = INK) -> void:
	var r = row(parent, 3)
	r.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	icon(r, file, 22)
	txt(value, r, 15, color)

func resources(parent: Node) -> void:
	var r = row(parent, 12)
	stat(r, "icon_gold_coin.png", short(int(meta.p.gold)), Color("ffd25a"))
	stat(r, "icon_diamond.png" if art("icon_diamond.png") != null else "icon_dust.png", short(int(meta.p.diamond)), Color("9fe8ff"))
	stat(r, "icon_soul_stone.png" if art("icon_soul_stone.png") != null else "icon_star_rebirth.png", str(int(meta.p.soul)), Color("e6b0ff"))
	var sp = Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(sp)
	txt("⚔ " + short(meta.power()), r, 15, GOLD_C)

static func short(n: int) -> String:
	if n >= 1000000:
		return "%.1fM" % (n / 1000000.0)
	if n >= 10000:
		return "%.1fB" % (n / 1000.0)
	return str(n)

func ribbon(parent: Node, label: String, h: float = 50) -> Control:
	var t = art("ui_ribbon.png")
	if t == null:
		return title(label, parent, 22)
	var holder = TextureRect.new()
	holder.texture = t
	holder.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	holder.stretch_mode = TextureRect.STRETCH_SCALE
	holder.custom_minimum_size = Vector2(10, h)
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(holder)
	var l = Label.new()
	l.text = label
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.offset_left = h * 0.9
	l.offset_right = -h * 0.9
	l.offset_top = -h * 0.12
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.add_theme_font_size_override("font_size", 19)
	l.add_theme_color_override("font_color", Color("3a2206"))
	if app.portrait_font != null:
		l.add_theme_font_override("font", app.portrait_font)
	holder.add_child(l)
	return holder

func back(parent: Node, label: String) -> void:
	var r = row(parent, 6)
	var b = btn("‹", r, func(): open("lobby"), false, false, 44)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.custom_minimum_size.x = 48
	ribbon(r, label)
	resources(parent)

func hero_tile(parent: Node, h: String, stars: int, size: float, selected: bool = false) -> PanelContainer:
	var holder = PanelContainer.new()
	holder.custom_minimum_size = Vector2(40, size * 1.18)
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col = STAR_COLORS[clampi(stars, 1, 6) - 1]
	holder.add_theme_stylebox_override("panel", app.box(Color(0.05, 0.08, 0.12), Color("54e0ff") if selected else col, 3 if selected else 2, 10, 2))
	parent.add_child(holder)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	holder.add_child(v)
	var pic = TextureRect.new()
	pic.texture = hero_art(h, stars)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pic.custom_minimum_size = Vector2(10, size * 0.8)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(pic)
	var name = txt(str(D.HEROES[h].name), v, 10, INK)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return holder

func press(control: Control, cb: Callable) -> void:
	var b = Button.new()
	b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.focus_mode = Control.FOCUS_NONE
	for key in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(key, StyleBoxEmpty.new())
	b.pressed.connect(func(): click(); cb.call())
	control.add_child(b)

func open(v: String) -> void:
	app.view = v
	app.selected = []
	if is_instance_valid(app.scroll):
		app.scroll.scroll_vertical = 0
	app.render()

func toast(s: String, ok: bool = true) -> void:
	app.toast(s, GOLD_C if ok else Color("ff9a8a"))

# ---------- yönlendirme ----------

func render(v: String) -> void:
	match v:
		"uga_heroes":
			render_heroes()
		"uga_totems":
			render_totems()
		"uga_chests":
			render_chests()
		"uga_missions":
			render_missions()
		"uga_rebirth":
			render_rebirth()
		"uga_result":
			render_result()
		"uga_online":
			render_online()
		"uga_map":
			render_map()
		_:
			render_hub()

# ---------- ana merkez ----------

func render_hub() -> void:
	var c = app.content
	resources(c)
	if offline_gold > 0:
		var n = card_panel(c, GOLD_C)
		var r = row(n)
		icon(r, "icon_gold_coin.png", 30)
		txt("Sen yokken kalen %d altın topladı!" % offline_gold, r, 14, INK, true)
		offline_gold = 0
	# ---- sahne: dünya arka planı, takım arenada, büyük SAVAŞ, yan düğmeler ----
	var unlocked = int(meta.p.world)
	world_sel = clampi(world_sel, 0, unlocked)
	var w = D.WORLDS[world_sel]
	var stage = PanelContainer.new()
	stage.clip_contents = true
	stage.custom_minimum_size.y = 560
	stage.add_theme_stylebox_override("panel", app.box(Color("111b24"), Color("6e6042"), 1, 16, 0))
	c.add_child(stage)
	var bg = TextureRect.new()
	var bg_file = "battle_bg.png" if world_sel == 0 else "battle_bg_%d.png" % (world_sel + 1)
	bg.texture = art(bg_file) if art(bg_file) != null else art("home_bg.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(bg)
	var shade = TextureRect.new()
	var grad = Gradient.new()
	grad.set_color(0, Color(0.02, 0.04, 0.07, 0.65))
	grad.add_point(0.35, Color(0.02, 0.04, 0.07, 0.05))
	grad.add_point(0.7, Color(0.02, 0.04, 0.07, 0.1))
	grad.set_color(grad.get_point_count() - 1, Color(0.02, 0.04, 0.07, 0.85))
	var gt = GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	shade.texture = gt
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(shade)
	var layer = Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_PASS
	stage.add_child(layer)
	# üst: dünya adı ve oklar
	var head = HBoxContainer.new()
	place(layer, head, 0.03, 0.015, 0.97, 0.17)
	head.add_theme_constant_override("separation", 4)
	var prev = btn("‹", head, func(): world_sel -= 1; open("lobby"), world_sel <= 0, false, 40)
	prev.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	prev.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prev.custom_minimum_size.x = 40
	var name_box = VBoxContainer.new()
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.alignment = BoxContainer.ALIGNMENT_CENTER
	name_box.add_theme_constant_override("separation", -2)
	head.add_child(name_box)
	var t1 = title("%d. DÜNYA" % (world_sel + 1), name_box, 14)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var t2 = title(w.name, name_box, 28)
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var best = meta.best_wave(world_sel)
	var t3 = txt("En iyi %d / %d dalga%s" % [best, D.WAVES_PER_WORLD, "  ✓" if best >= D.WAVES_PER_WORLD else ""], name_box, 12, INK)
	t3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var next = btn("›", head, func(): world_sel += 1; open("lobby"), world_sel >= unlocked, false, 40)
	next.size_flags_horizontal = Control.SIZE_SHRINK_END
	next.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	next.custom_minimum_size.x = 40
	# boss gölgesi: bu dünyanın boss'u arkada bekliyor
	var boss_t = art(str(D.BOSSES[world_sel].art) + ".png")
	if boss_t != null:
		var boss = TextureRect.new()
		boss.texture = boss_t
		boss.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		boss.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		boss.modulate = Color(0.55, 0.5, 0.65, 0.85)
		boss.mouse_filter = Control.MOUSE_FILTER_IGNORE
		place(layer, boss, 0.3, 0.17, 0.7, 0.42)
	# takım arenada: 5 kahraman yay şeklinde, canlı
	var spots = [[0.5, 0.7], [0.29, 0.645], [0.71, 0.645], [0.15, 0.585], [0.85, 0.585]]
	var order = [2, 1, 3, 0, 4]
	for k in range(meta.p.deck.size()):
		var h = str(meta.p.deck[k])
		var sp = spots[order.find(k)] if order.find(k) >= 0 else spots[0]
		var sw = 0.36 if k == 2 else 0.28
		var spr = Sprite.new()
		var sheet = art("attack_%s.png" % h)
		spr.setup(sheet, hero_art(h, 3), 2.2 + k * 0.45, k * 0.7)
		spr.flip = float(sp[0]) > 0.5
		spr.ring = STAR_COLORS[clampi(meta.hero_level(h) / 3, 0, 5)]
		place(layer, spr, float(sp[0]) - sw / 2.0, float(sp[1]) - 0.26, float(sp[0]) + sw / 2.0, float(sp[1]))
		var lv = txt("Sv %d" % meta.hero_level(h), layer, 11, GOLD_C)
		lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		place(layer, lv, float(sp[0]) - 0.1, float(sp[1]), float(sp[0]) + 0.1, float(sp[1]) + 0.035)
	var team_b = Button.new()
	team_b.flat = true
	team_b.focus_mode = Control.FOCUS_NONE
	for key in ["normal", "hover", "pressed", "focus"]:
		team_b.add_theme_stylebox_override(key, StyleBoxEmpty.new())
	team_b.pressed.connect(func(): click(); open("uga_heroes"))
	place(layer, team_b, 0.05, 0.44, 0.95, 0.7)
	# yan düğmeler
	var chests = int(meta.p.chests.common) + int(meta.p.chests.rare) + int(meta.p.chests.epic)
	var ready = 0
	for mi in meta.p.missions.list:
		if not mi.claimed and int(mi.progress) >= int(meta.mission_spec(mi.id).goal):
			ready += 1
	var left = [
		["icon_daily_gift.png", "Hediye", func():
			var out = meta.claim_daily()
			if not out.is_empty():
				toast("+%d elmas, +%d altın, sandık" % [out.diamond, out.gold])
			else:
				toast("Yarın yeni hediye", false)
			open("lobby"), meta.daily_ready()],
		["icon_mission.png", "Görev", func(): open("uga_missions"), ready > 0 or meta.ach_ready_count() > 0],
		["scene_chest.png" if art("chest_rare.png") == null else "chest_rare.png", "Sandık", func(): open("uga_chests"), chests > 0],
	]
	var right = [
		["icon_map.png" if art("icon_map.png") != null else "icon_story.png", "Harita", func(): open("uga_map"), false],
		["icon_leaderboard.png", "Sıralama", func(): open("uga_online"), false],
		["icon_star_rebirth.png", "Doğuş", func(): open("uga_rebirth"), meta.can_rebirth()],
	]
	for i in range(left.size()):
		round_btn(layer, 0.015, 0.2 + i * 0.105, left[i])
	for i in range(right.size()):
		round_btn(layer, 0.815, 0.2 + i * 0.105, right[i])
	# alt: SAVAŞ
	var bottom = VBoxContainer.new()
	bottom.add_theme_constant_override("separation", 4)
	place(layer, bottom, 0.12, 0.76, 0.88, 0.98)
	var bar = ProgressBar.new()
	bar.max_value = D.WAVES_PER_WORLD
	bar.value = best
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 8)
	bar.add_theme_stylebox_override("background", app.box(Color(0, 0, 0, 0.6), Color(0, 0, 0, 0), 0, 4, 0))
	bar.add_theme_stylebox_override("fill", app.box(GOLD_C, Color(0, 0, 0, 0), 0, 4, 0))
	bottom.add_child(bar)
	var play = btn("SAVAŞ", bottom, func(): start_run(world_sel), false, true, 64)
	play.add_theme_font_size_override("font_size", 26)
	var pulse = play.create_tween().set_loops()
	play.pivot_offset = Vector2(140, 32)
	pulse.tween_property(play, "scale", Vector2(1.04, 1.04), 0.7).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(play, "scale", Vector2(1.0, 1.0), 0.7).set_trans(Tween.TRANS_SINE)
	var foes = []
	for k in w.enemies:
		foes.append(str(D.ENEMIES[k].name))
	var fl = txt("Düşmanlar: %s · Boss: %s" % [", ".join(foes), D.BOSSES[world_sel].name], bottom, 11, Color("cfd8de"), true)
	fl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# günün meydan okuması
	var ch = card_panel(c, Color("e6b0ff"))
	var chr_ = row(ch, 8)
	icon(chr_, "boss_5.png" if art("boss_5.png") != null else "boss_1.png", 46)
	var chv = VBoxContainer.new()
	chv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chv.add_theme_constant_override("separation", 1)
	chr_.add_child(chv)
	txt("Günün Meydan Okuması", chv, 15, Color("e6b0ff"))
	if meta.challenge_done():
		txt("Bugün tamamlandı: dalga %d. Yarın yeni dalgalar!" % int(meta.p.challenge_best), chv, 12, MUTED, true)
	else:
		txt("Herkes aynı dalgalarla. Ödül: dalga x3 elmas.", chv, 12, INK, true)
		var cb = btn("OYNA", chr_, func():
			challenge_active = true
			race_active = ""
			start_run(meta.challenge_world(), meta.challenge_seed())
			challenge_active = true, false, true, 44)
		cb.size_flags_horizontal = Control.SIZE_SHRINK_END
		cb.custom_minimum_size.x = 84
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_child(grid)
	tile(grid, "Kart Düellosu", "Klasik kart oyunu", "scene_friends.png", func(): open("duel"))
	tile(grid, "Yeniden Doğuş", "Ruh taşı: %d" % int(meta.p.soul), "icon_star_rebirth.png", func(): open("uga_rebirth"))

func place(parent: Control, child: Control, x0: float, y0: float, x1: float, y1: float) -> void:
	# Oransal yerleşim: sahne boyu değişse de düğmeler kaymaz.
	if child.get_parent() == null:
		parent.add_child(child)
	child.anchor_left = x0
	child.anchor_top = y0
	child.anchor_right = x1
	child.anchor_bottom = y1
	child.offset_left = 0
	child.offset_top = 0
	child.offset_right = 0
	child.offset_bottom = 0

func round_btn(layer: Control, x: float, y: float, spec: Array) -> void:
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(layer, box, x, y, x + 0.17, y + 0.1)
	var disc = PanelContainer.new()
	disc.custom_minimum_size = Vector2(46, 46)
	disc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	disc.add_theme_stylebox_override("panel", app.box(Color(0.05, 0.08, 0.12, 0.88), GOLD_C, 2, 23, 3))
	box.add_child(disc)
	var ic = TextureRect.new()
	ic.texture = art(str(spec[0]))
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.add_child(ic)
	var lab = txt(str(spec[1]), box, 11, INK)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if spec[3]:
		var dot = PanelContainer.new()
		dot.add_theme_stylebox_override("panel", app.box(Color("e04848"), Color("ffffff"), 1, 6, 0))
		dot.custom_minimum_size = Vector2(12, 12)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		place(layer, dot, x + 0.12, y, x + 0.12, y)
		dot.offset_right = 12
		dot.offset_bottom = 12
	press(disc, spec[2])

func tile(parent: Node, name: String, sub: String, file: String, cb: Callable) -> void:
	var holder = PanelContainer.new()
	holder.custom_minimum_size = Vector2(0, 74)
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.add_theme_stylebox_override("panel", app.box(Color(0.07, 0.11, 0.15, 0.95), Color("6e6042"), 1, 12, 8))
	parent.add_child(holder)
	var r = HBoxContainer.new()
	r.add_theme_constant_override("separation", 6)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(r)
	icon(r, file, 48)
	var v = VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_child(v)
	var a = txt(name, v, 14, GOLD_C)
	a.custom_minimum_size.x = 10
	a.clip_text = true
	var b = txt(sub, v, 11, MUTED)
	b.custom_minimum_size.x = 10
	b.clip_text = true
	press(holder, cb)

# ---------- dünya haritası ----------

const MAP_NODES = [[0.5, 0.83], [0.28, 0.66], [0.68, 0.49], [0.32, 0.31], [0.56, 0.13]]

func render_map() -> void:
	var c = app.content
	back(c, "Dünya Haritası")
	var holder = PanelContainer.new()
	holder.clip_contents = true
	holder.custom_minimum_size.y = 640
	holder.add_theme_stylebox_override("panel", app.box(Color("111b24"), Color("6e6042"), 1, 16, 0))
	c.add_child(holder)
	var bg = TextureRect.new()
	bg.texture = art("bg_world_map.png") if art("bg_world_map.png") != null else art("home_bg.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(bg)
	var layer = Control.new()
	holder.add_child(layer)
	var unlocked = int(meta.p.world)
	for i in range(D.WORLDS.size()):
		var pos = MAP_NODES[i]
		var open_ = i <= unlocked
		var box = VBoxContainer.new()
		box.add_theme_constant_override("separation", 0)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		place(layer, box, float(pos[0]) - 0.2, float(pos[1]) - 0.075, float(pos[0]) + 0.2, float(pos[1]) + 0.075)
		var disc = PanelContainer.new()
		disc.custom_minimum_size = Vector2(64, 64)
		disc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var ring = GOLD_C if open_ else Color("5a6066")
		if i == world_sel:
			ring = Color("54e0ff")
		disc.add_theme_stylebox_override("panel", app.box(Color(0.04, 0.07, 0.1, 0.9), ring, 3, 32, 4))
		box.add_child(disc)
		var ic = TextureRect.new()
		ic.texture = art("world_%d.png" % (i + 1)) if open_ else art("icon_lock.png")
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not open_:
			ic.modulate = Color(0.7, 0.7, 0.7)
		disc.add_child(ic)
		var plate = PanelContainer.new()
		plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		plate.add_theme_stylebox_override("panel", app.box(Color(0.03, 0.05, 0.08, 0.82), Color(0, 0, 0, 0), 0, 8, 2))
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(plate)
		var pv = VBoxContainer.new()
		pv.add_theme_constant_override("separation", -3)
		pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.add_child(pv)
		var nm = title("%d. %s" % [i + 1, D.WORLDS[i].name], pv, 14)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var best = meta.best_wave(i)
		var st = txt(("%d / %d dalga" % [best, D.WAVES_PER_WORLD]) if open_ else "Önceki dünyayı geç", pv, 11, INK if open_ else MUTED)
		st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if open_:
			var k = i
			press(disc, func():
				world_sel = k
				open("lobby"))
			if i == unlocked:
				var pulse = disc.create_tween().set_loops()
				disc.pivot_offset = Vector2(32, 32)
				pulse.tween_property(disc, "scale", Vector2(1.1, 1.1), 0.6).set_trans(Tween.TRANS_SINE)
				pulse.tween_property(disc, "scale", Vector2(1.0, 1.0), 0.6).set_trans(Tween.TRANS_SINE)
	txt("Bir dünyanın 30 dalgasını geçince sonraki açılır. Her dünyanın kendi boss'u ve düşmanları var.", c, 11, MUTED, true)

# ---------- savaş ----------

func start_run(world: int, seed_override: int = -1) -> void:
	if battle != null and is_instance_valid(battle):
		return
	if seed_override < 0:
		race_active = ""
		challenge_active = false
	var sim = Sim.new(meta.run_seed() if seed_override < 0 else seed_override, world, meta.mods(), meta.castle_bonus(), 0, meta.p.deck)
	battle = Battle.new()
	battle.setup(sim, app.skin_art, app.get_theme_default_font(), app.portrait_font)
	battle.sfx = func(name: String) -> AudioStream: return null if app.muted else app.sfx_stream(name)
	battle.tutorial = not bool(meta.p.tutorial)
	battle.host = app
	battle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	battle.z_index = 50
	app.add_child(battle)
	app.shell_margin.visible = false
	app.set_music("music_battle")
	battle.finished.connect(on_finished)

func on_finished(result: Dictionary) -> void:
	last_result = result
	meta.p.tutorial = true
	last_reward = meta.finish_run(result)
	if last_reward.get("unlocked", false):
		world_sel = int(meta.p.world)
	challenge_gain = 0
	if challenge_active:
		challenge_gain = meta.finish_challenge(int(result.wave))
		challenge_active = false
	if is_instance_valid(battle):
		battle.queue_free()
	battle = null
	app.view = "uga_result"
	app.shell_margin.visible = true
	app.set_music("music_menu")
	if online():
		submit_online(result)
	open("uga_result")

func render_result() -> void:
	var c = app.content
	var r = last_result
	var won = bool(r.get("won", false))
	var b = TextureRect.new()
	b.texture = art("banner_victory.png" if won else "banner_defeat.png")
	b.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	b.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	b.custom_minimum_size = Vector2(0, 120)
	c.add_child(b)
	var t = title(("%s fethedildi!" % D.WORLDS[int(r.get("world", 0))].name) if won else "Dalga %d'de kale düştü" % int(r.get("wave", 0)), c, 24)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if last_reward.get("record", false):
		var rec = txt("Yeni rekor!", c, 16, Color("ffd25a"))
		rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# takım sahnesi: zaferde saldırı pozu, yenilgide yorgun
	var stage = PanelContainer.new()
	stage.clip_contents = true
	stage.custom_minimum_size.y = 170
	stage.add_theme_stylebox_override("panel", app.box(Color("0b141c"), Color("6e6042"), 1, 12, 0))
	c.add_child(stage)
	var wi = int(r.get("world", 0))
	var sbg = TextureRect.new()
	var bgf = "battle_bg.png" if wi == 0 else "battle_bg_%d.png" % (wi + 1)
	sbg.texture = art(bgf) if art(bgf) != null else art("home_bg.png")
	sbg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sbg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	sbg.modulate = Color(1, 1, 1) if won else Color(0.45, 0.42, 0.5)
	sbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(sbg)
	var layer = Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(layer)
	var n = meta.p.deck.size()
	for k in range(n):
		var h = str(meta.p.deck[k])
		var spr = Sprite.new()
		spr.setup(art("attack_%s.png" % h), hero_art(h, 3), (0.9 + k * 0.17) if won else 0.0, k * 0.3)
		spr.flip = k >= n / 2 + 1
		if not won:
			spr.modulate = Color(0.75, 0.72, 0.8)
		var x0 = 0.02 + k * (0.96 / n)
		place(layer, spr, x0, 0.12, x0 + 0.96 / n, 0.98)
	var p = card_panel(c, GOLD_C)
	txt("Ödüller", p, 16, GOLD_C)
	var r1 = row(p, 14)
	stat(r1, "icon_gold_coin.png", "+%d" % int(last_reward.get("gold", 0)), Color("ffd25a"))
	stat(r1, "icon_diamond.png" if art("icon_diamond.png") != null else "icon_dust.png", "+%d" % int(last_reward.get("diamond", 0)), Color("9fe8ff"))
	var shards = last_reward.get("shards", {})
	if not shards.is_empty():
		var parts = []
		for h in shards:
			parts.append("%s +%d" % [D.HEROES[h].name, int(shards[h])])
		txt("Kart parçası: " + ", ".join(parts), p, 13, INK, true)
	if str(last_reward.get("chest", "")) != "":
		txt("Sandık kazandın: %s" % {"common": "Sıradan", "rare": "Nadir", "epic": "Destansı"}[last_reward.chest], p, 14, Color("9fe8ff"))
	if last_reward.get("unlocked", false):
		txt("Yeni dünya açıldı!", p, 15, Color("7dff9a"))
	var s = card_panel(c)
	txt("Yenilen düşman: %d · Boss: %d · Birleştirme: %d · En yüksek yıldız: %d" % [int(r.get("kills", 0)), int(r.get("bosses", 0)), int(r.get("merges", 0)), int(r.get("best_star", 1))], s, 13, MUTED, true)
	if race_active != "":
		var rp = card_panel(c, Color("54e0ff"))
		txt("Yarış %s" % race_active, rp, 16, Color("9fe8ff"))
		if race.get("results", []).is_empty():
			txt("Sonuçlar gönderiliyor…", rp, 13, MUTED)
		for i in range(race.get("results", []).size()):
			var e = race.results[i]
			txt("%d. %s · dalga %d" % [i + 1, e.name, int(e.wave)], rp, 14, INK)
	if challenge_gain > 0:
		var cp = card_panel(c, Color("e6b0ff"))
		txt("Günün meydan okuması tamamlandı: +%d elmas" % challenge_gain, cp, 15, Color("e6b0ff"), true)
	var goal = card_panel(c)
	var bw = meta.best_wave(int(r.get("world", 0)))
	txt("Sonraki hedef: %d. dalga (en iyi %d / %d)" % [mini(bw + 5, D.WAVES_PER_WORLD), bw, D.WAVES_PER_WORLD], goal, 13, INK)
	var gb = ProgressBar.new()
	gb.max_value = D.WAVES_PER_WORLD
	gb.value = bw
	gb.show_percentage = false
	gb.custom_minimum_size = Vector2(0, 10)
	gb.add_theme_stylebox_override("background", app.box(Color(0, 0, 0, 0.6), Color(0, 0, 0, 0), 0, 5, 0))
	gb.add_theme_stylebox_override("fill", app.box(GOLD_C, Color(0, 0, 0, 0), 0, 5, 0))
	goal.add_child(gb)
	if not won:
		txt("İpucu: Kahramanlar ekranında seviye yükselt, totemlerle gücünü katla.", goal, 11, MUTED, true)
	if str(last_reward.get("chest", "")) != "":
		btn("Sandığı aç", c, func(): open("uga_chests"), false, false, 44)
	var rr = row(c, 8)
	btn("Ana sayfa", rr, func(): open("lobby"))
	if race_active != "":
		btn("Yarışa dön", rr, func(): open("uga_online"))
	elif last_reward.get("unlocked", false):
		btn("SONRAKİ DÜNYA", rr, func(): start_run(int(r.get("world", 0)) + 1), false, true, 48)
	else:
		btn("TEKRAR", rr, func(): start_run(int(r.get("world", 0))), false, true, 48)

# ---------- kahramanlar ----------

var hero_sel: String = ""

func render_heroes() -> void:
	var c = app.content
	back(c, "Kahramanlar")
	var dp = card_panel(c)
	txt("Takımın · değiştirmek için bir yuvaya dokun", dp, 12, MUTED, true)
	var cards = row(dp, 5)
	for i in range(5):
		var h = meta.p.deck[i]
		var t = hero_tile(cards, h, 1, 60, i == deck_slot)
		var idx = i
		press(t, func(): deck_slot = idx; hero_sel = meta.p.deck[idx]; open("uga_heroes"))
	if hero_sel == "" or not D.HEROES.has(hero_sel):
		hero_sel = meta.p.deck[deck_slot]
	# seçili kahraman ayrıntısı
	var spec = D.HEROES[hero_sel]
	var lv = meta.hero_level(hero_sel)
	var p = card_panel(c, GOLD_C)
	# kahraman sahnesi: kaide üstünde canlı (bekleme + saldırı karesi)
	var stage = PanelContainer.new()
	stage.clip_contents = true
	stage.custom_minimum_size.y = 230
	stage.add_theme_stylebox_override("panel", app.box(Color("0b141c"), Color("6e6042"), 1, 12, 0))
	p.add_child(stage)
	var sbg = TextureRect.new()
	sbg.texture = art("bg_hero_stage.png") if art("bg_hero_stage.png") != null else art("bg_totem_altar.png")
	sbg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sbg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	sbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(sbg)
	var slayer = Control.new()
	slayer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(slayer)
	var spr = Sprite.new()
	spr.setup(art("attack_%s.png" % hero_sel), hero_art(hero_sel, 3), 1.6)
	spr.ring = STAR_COLORS[clampi(lv / 3, 0, 5)]
	if lv <= 0 and hero_sel != "ejder_yavrusu":
		spr.modulate = Color(0.2, 0.2, 0.25)
	place(slayer, spr, 0.22, 0.04, 0.78, 0.97)
	var v = VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 3)
	p.add_child(v)
	title(str(spec.name), v, 20)
	txt(("Seviye %d / %d" % [lv, Meta.MAX_HERO_LEVEL]) if lv > 0 else "Kilitli", v, 13, Color("ffd25a") if lv > 0 else MUTED)
	txt(str(spec.text), v, 12, INK, true)
	var reach = float(spec.get("reach", 0.2))
	txt("Menzil: " + ("kısa (kaleye yakın)" if reach > 0.3 else "uzun" if reach < 0.15 else "orta"), v, 11, MUTED)
	if hero_sel == "ejder_yavrusu":
		txt("Yalnızca 4★ ve üstü birleştirmede rastgele çıkar.", p, 12, MUTED, true)
	elif lv <= 0:
		txt("Sandıklardan açılır (nadir sandık %35, destansı sandık kesin).", p, 12, MUTED, true)
	else:
		var cost = meta.upgrade_cost(hero_sel)
		var sh = int(meta.p.shards.get(hero_sel, 0))
		var bar = ProgressBar.new()
		bar.max_value = cost.shards
		bar.value = mini(sh, cost.shards)
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 12)
		bar.add_theme_stylebox_override("background", app.box(Color(0, 0, 0, 0.6), Color(0, 0, 0, 0), 0, 6, 0))
		bar.add_theme_stylebox_override("fill", app.box(Color("54e0ff"), Color(0, 0, 0, 0), 0, 6, 0))
		p.add_child(bar)
		txt("Parça %d/%d · %d altın" % [sh, cost.shards, cost.gold], p, 12, Color("cfe8ff"))
		var br = row(p, 8)
		var hh = hero_sel
		btn("YÜKSELT", br, func():
			if meta.upgrade_hero(hh):
				toast("%s seviye %d!" % [spec.name, meta.hero_level(hh)])
			else:
				toast(meta.err, false)
			open("uga_heroes"), lv >= Meta.MAX_HERO_LEVEL or sh < cost.shards or int(meta.p.gold) < cost.gold, true, 46)
		btn("Takımda" if meta.p.deck.has(hh) else "Takıma al", br, func():
			if meta.set_deck_slot(deck_slot, hh):
				toast("%s takımda" % spec.name)
			open("uga_heroes"), meta.p.deck.has(hh), false, 46)
	# tüm kahramanlar ızgarası
	title("Koleksiyon", c, 18)
	var grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_child(grid)
	var all = D.SUMMON_POOL.duplicate()
	all.append("ejder_yavrusu")
	for h in all:
		var hl = meta.hero_level(h)
		var t = hero_tile(grid, h, mini(6, maxi(1, hl / 3 + 1)), 74, h == hero_sel)
		var holder_v = t.get_child(0)
		var info = txt(("Sv %d" % hl) if hl > 0 else ("Efsane" if h == "ejder_yavrusu" else "Kilitli"), holder_v, 10, Color("ffd25a") if hl > 0 else MUTED)
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if hl <= 0 and h != "ejder_yavrusu":
			holder_v.get_child(0).modulate = Color(0.3, 0.3, 0.3)
		if hl > 0:
			var cost = meta.upgrade_cost(h)
			if int(meta.p.shards.get(h, 0)) >= cost.shards and int(meta.p.gold) >= cost.gold and hl < Meta.MAX_HERO_LEVEL:
				var up = txt("▲ yükselt", holder_v, 9, Color("7dff9a"))
				up.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var hh2 = h
		press(t, func(): hero_sel = hh2; open("uga_heroes"))

# ---------- totemler ----------

func scene_panel(parent: Node, bg_file: String, min_h: float) -> VBoxContainer:
	# Arka plan resimli büyük sahne kutusu (menüleri liste yerine sahne gibi gösterir).
	var holder = PanelContainer.new()
	holder.clip_contents = true
	holder.custom_minimum_size = Vector2(0, min_h)
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.add_theme_stylebox_override("panel", app.box(Color("0b141c"), Color("6e6042"), 1, 14, 0))
	parent.add_child(holder)
	var bt = art(bg_file)
	if bt != null:
		var bg = TextureRect.new()
		bg.texture = bt
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(bg)
		var shade = ColorRect.new()
		shade.color = Color(0.02, 0.04, 0.07, 0.35)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(shade)
	var m = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 10)
	holder.add_child(m)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	m.add_child(v)
	return v

func badge(parent: Node, s: String, col: Color = Color("ffd25a")) -> Label:
	var l = txt(s, parent, 12, Color("2a1500"))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_constant_override("outline_size", 0)
	var sb = app.box(col, Color("2a1500"), 1, 9, 2)
	l.add_theme_stylebox_override("normal", sb)
	l.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return l

func render_totems() -> void:
	var c = app.content
	back(c, "Totemler")
	var altar = scene_panel(c, "bg_totem_altar.png", 560)
	var info = txt("Totemler kalıcıdır, yeniden doğuşta da korunur.", altar, 12, INK, true)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	altar.add_child(grid)
	for id in Meta.TOTEMS:
		var spec = Meta.TOTEMS[id]
		var lv = int(meta.p.totems[id])
		var cell = PanelContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_stylebox_override("panel", app.box(Color(0.03, 0.06, 0.09, 0.72), GOLD_C if lv > 0 else Color("6e6042"), 1, 12, 6))
		grid.add_child(cell)
		var v = VBoxContainer.new()
		v.add_theme_constant_override("separation", 3)
		cell.add_child(v)
		var pic = icon(v, spec.art + ".png", 96)
		pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		if lv == 0:
			pic.modulate = Color(0.75, 0.75, 0.75)
		badge(v, "Sv %d" % lv)
		var n = txt(spec.name, v, 13, GOLD_C)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.custom_minimum_size.x = 10
		n.clip_text = true
		var e = txt(spec.text, v, 10, INK, true)
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var cost = meta.totem_cost(id)
		var tid = id
		btn("%d elmas" % cost if lv < Meta.MAX_TOTEM_LEVEL else "MAX", v, func():
			if meta.upgrade_totem(tid):
				toast("%s seviye %d" % [spec.name, int(meta.p.totems[tid])])
			else:
				toast(meta.err, false)
			open("uga_totems"), int(meta.p.diamond) < cost or lv >= Meta.MAX_TOTEM_LEVEL, true, 40)

# ---------- sandıklar ----------

var chest_opening: String = ""

func render_chests() -> void:
	var c = app.content
	back(c, "Sandıklar")
	var vault = scene_panel(c, "bg_chest_vault.png", 330)
	if chest_opening != "":
		# açılma animasyonu: 4 karelik şerit ya da büyüyen sandık
		var stage = Control.new()
		stage.custom_minimum_size = Vector2(0, 230)
		vault.add_child(stage)
		var pic = TextureRect.new()
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stage.add_child(pic)
		var sheet = art("chest_open_%s.png" % chest_opening)
		var kind = chest_opening
		chest_opening = ""
		var tw = app.create_tween()
		if sheet != null:
			var at = AtlasTexture.new()
			at.atlas = sheet
			var fw = sheet.get_width() / 4.0
			at.region = Rect2(0, 0, fw, sheet.get_height())
			pic.texture = at
			tw.tween_method(func(f: float): at.region = Rect2(fw * mini(3, int(f)), 0, fw, sheet.get_height()), 0.0, 3.99, 0.9)
		else:
			pic.texture = art("chest_%s.png" % kind)
			pic.pivot_offset = Vector2(185, 115)
			tw.tween_property(pic, "scale", Vector2(1.25, 1.25), 0.25)
			tw.tween_property(pic, "scale", Vector2(1, 1), 0.2)
		var burst = TextureRect.new()
		burst.texture = art("new_hero_bg.png") if art("new_hero_bg.png") != null else art("merge_burst.png")
		burst.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		burst.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		burst.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		burst.modulate.a = 0.0
		burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(burst)
		stage.move_child(burst, 0)
		tw.tween_property(burst, "modulate:a", 0.9, 0.3)
	var specs = [["common", "Sıradan", 30], ["rare", "Nadir", 90], ["epic", "Destansı", 250]]
	var shelf = row(vault, 6)
	for sp in specs:
		var kind = sp[0]
		var n = int(meta.p.chests[kind])
		var cell = VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 3)
		shelf.add_child(cell)
		var pic = icon(cell, "chest_%s.png" % kind if art("chest_%s.png" % kind) != null else "scene_chest.png", 92)
		pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		if n <= 0:
			pic.modulate = Color(0.55, 0.55, 0.55)
		badge(cell, "×%d" % n, Color("ffd25a") if n > 0 else Color("8a949b"))
		var nm = txt(sp[1], cell, 13, GOLD_C)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var k = kind
		btn("AÇ", cell, func():
			chest_reward = meta.open_chest(k)
			chest_opening = k
			open("uga_chests"), n <= 0, true, 40)
		btn("%d elmas" % sp[2], cell, func():
			if not meta.buy_chest(k):
				toast(meta.err, false)
			open("uga_chests"), int(meta.p.diamond) < int(sp[2]), false, 36)
	if not chest_reward.is_empty():
		var p = card_panel(c, GOLD_C)
		txt("Sandıktan çıkanlar", p, 16, GOLD_C)
		var r = row(p, 14)
		stat(r, "icon_gold_coin.png", "+%d" % int(chest_reward.gold), Color("ffd25a"))
		if int(chest_reward.diamond) > 0:
			stat(r, "icon_diamond.png" if art("icon_diamond.png") != null else "icon_dust.png", "+%d" % int(chest_reward.diamond), Color("9fe8ff"))
		var cards = row(p, 6)
		for h in chest_reward.shards:
			var t = hero_tile(cards, h, 1, 56)
			var lab = txt("+%d parça" % int(chest_reward.shards[h]), t.get_child(0), 10, Color("54e0ff"))
			lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if str(chest_reward.hero) != "":
			var reveal = PanelContainer.new()
			reveal.clip_contents = true
			reveal.custom_minimum_size = Vector2(0, 230)
			reveal.add_theme_stylebox_override("panel", app.box(Color("0b141c"), GOLD_C, 2, 12, 0))
			p.add_child(reveal)
			if art("new_hero_bg.png") != null:
				var rays = TextureRect.new()
				rays.texture = art("new_hero_bg.png")
				rays.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				rays.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
				rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
				reveal.add_child(rays)
			var rv = VBoxContainer.new()
			rv.alignment = BoxContainer.ALIGNMENT_CENTER
			reveal.add_child(rv)
			var hp = TextureRect.new()
			hp.texture = hero_art(chest_reward.hero, 3)
			hp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			hp.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			hp.custom_minimum_size = Vector2(0, 170)
			rv.add_child(hp)
			var nt = title("YENİ KAHRAMAN: %s!" % D.HEROES[chest_reward.hero].name, rv, 18)
			nt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chest_reward = {}
	txt("Sıradan: altın ve az parça · Nadir: çok parça, elmas, %35 yeni kahraman · Destansı: bol ödül, kesin yeni kahraman", c, 11, MUTED, true)

# ---------- görevler ----------

func render_missions() -> void:
	var c = app.content
	back(c, "Görevler")
	meta.ensure_missions()
	var board = scene_panel(c, "bg_mission_board.png", 300)
	var hdr = txt("Günlük görevler · her gün yenilenir", board, 13, INK)
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for i in range(meta.p.missions.list.size()):
		var m = meta.p.missions.list[i]
		var spec = meta.mission_spec(m.id)
		var done = int(m.progress) >= int(spec.goal)
		var note = PanelContainer.new()
		note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var paper = Color(0.93, 0.86, 0.68, 0.94) if not m.claimed else Color(0.6, 0.6, 0.6, 0.8)
		note.add_theme_stylebox_override("panel", app.box(paper, Color("6b4a1e"), 2, 6, 8))
		board.add_child(note)
		var r = HBoxContainer.new()
		r.add_theme_constant_override("separation", 8)
		note.add_child(r)
		icon(r, "icon_mission.png" if art("icon_mission.png") != null else "icon_wave.png", 40)
		var v = VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 2)
		r.add_child(v)
		var t = txt(spec.text % int(spec.goal), v, 14, Color("3a2206"), true)
		t.add_theme_constant_override("outline_size", 0)
		var bar = ProgressBar.new()
		bar.max_value = int(spec.goal)
		bar.value = mini(int(m.progress), int(spec.goal))
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 10)
		bar.add_theme_stylebox_override("background", app.box(Color(0.3, 0.2, 0.1, 0.4), Color(0, 0, 0, 0), 0, 5, 0))
		bar.add_theme_stylebox_override("fill", app.box(Color("2f8f5a"), Color(0, 0, 0, 0), 0, 5, 0))
		v.add_child(bar)
		var pr = txt("%d / %d · %d elmas" % [mini(int(m.progress), int(spec.goal)), int(spec.goal), int(spec.reward)], v, 11, Color("5a3a12"))
		pr.add_theme_constant_override("outline_size", 0)
		var idx = i
		var b = btn("✓" if m.claimed else "AL", r, func():
			if meta.claim_mission(idx):
				toast("+%d elmas" % int(spec.reward))
			open("uga_missions"), m.claimed or not done, done and not m.claimed, 44)
		b.size_flags_horizontal = Control.SIZE_SHRINK_END
		b.custom_minimum_size.x = 64
	# başarımlar: kalıcı hedefler, bir kez elmas
	ribbon(c, "Başarımlar", 44)
	var list = Meta.ACHIEVEMENTS.duplicate()
	list.sort_custom(func(a, b):
		var ra = 0 if (not meta.p.ach.has(a[0]) and meta.ach_value(a[2]) >= int(a[3])) else (2 if meta.p.ach.has(a[0]) else 1)
		var rb = 0 if (not meta.p.ach.has(b[0]) and meta.ach_value(b[2]) >= int(b[3])) else (2 if meta.p.ach.has(b[0]) else 1)
		return ra < rb)
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	c.add_child(grid)
	for a in list:
		var got = meta.p.ach.has(a[0])
		var val = meta.ach_value(a[2])
		var ready = not got and val >= int(a[3])
		var cell = PanelContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_stylebox_override("panel", app.box(Color(0.06, 0.1, 0.14, 0.95), Color("ffd25a") if ready else Color("3a4a55"), 2 if ready else 1, 10, 7))
		grid.add_child(cell)
		var v = VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		cell.add_child(v)
		var t = txt(str(a[1]), v, 12, INK if not got else MUTED)
		t.custom_minimum_size.x = 10
		t.clip_text = true
		var pb = ProgressBar.new()
		pb.max_value = int(a[3])
		pb.value = mini(val, int(a[3]))
		pb.show_percentage = false
		pb.custom_minimum_size = Vector2(0, 6)
		pb.add_theme_stylebox_override("background", app.box(Color(0, 0, 0, 0.6), Color(0, 0, 0, 0), 0, 3, 0))
		pb.add_theme_stylebox_override("fill", app.box(Color("54e0ff") if not got else Color("4a6070"), Color(0, 0, 0, 0), 0, 3, 0))
		v.add_child(pb)
		var id = str(a[0])
		var rw = int(a[4])
		var b = btn("✓ alındı" if got else ("AL +%d elmas" % rw if ready else "%d / %d" % [mini(val, int(a[3])), int(a[3])]), v, func():
			if meta.claim_ach(id):
				toast("+%d elmas" % rw)
			open("uga_missions"), not ready, ready, 30)
		b.add_theme_font_size_override("font_size", 12)

# ---------- yeniden doğuş ----------

func render_rebirth() -> void:
	var c = app.content
	back(c, "Yeniden Doğuş")
	var p = card_panel(c, Color("b06be0"))
	icon(p, "banner_rebirth.png", 100)
	txt("Dünyaları ve kahraman seviyelerini sıfırla, kalıcı ruh taşı kazan. Her ruh taşı tüm hasarı %5 artırır. Totemler, elmaslar ve açılan kahramanlar korunur.", p, 13, INK, true)
	txt("Şu anki ruh taşı: %d (hasar +%d%%)" % [int(meta.p.soul), int(meta.p.soul) * 5], p, 14, Color("e6b0ff"))
	txt("Yeniden doğarsan kazanacağın: %d" % meta.rebirth_gain(), p, 15, GOLD_C)
	if not meta.can_rebirth():
		txt("Koşul: 1. dünyayı (30 dalga) bitir.", p, 13, Color("ff9a8a"), true)
	btn("YENİDEN DOĞ", p, func():
		if meta.rebirth():
			toast("Yeniden doğdun! Ruh taşı: %d" % int(meta.p.soul))
			world_sel = 0
			open("lobby")
		else:
			toast(meta.err, false), not meta.can_rebirth() or meta.rebirth_gain() <= 0, true, 52)

# ---------- çevrimiçi: sıralama ve arkadaş yarışı ----------

func online() -> bool:
	return not app.offline_mode and not app.account.is_empty()

func submit_online(result: Dictionary) -> void:
	var body = {"world": int(result.world), "wave": int(result.wave)}
	if str(meta.p.get("name", "")).length() >= 3:
		body["name"] = str(meta.p.name)
	await app.api("uga/score", HTTPClient.METHOD_POST, body)
	if race_active != "":
		var r = await app.api("uga/race/%s/result" % race_active, HTTPClient.METHOD_POST, {"wave": int(result.wave)})
		if not r.has("error"):
			race = r
			if app.view == "uga_result":
				app.render()

func load_board(world: int) -> void:
	if board_loading:
		return
	board_loading = true
	var r = await app.api("uga/board/%d" % world)
	board_loading = false
	board_data = r if not r.has("error") else {"error": str(r.error), "world": world}
	board_data["world"] = world
	if app.view == "uga_online":
		app.render()

func create_race() -> void:
	var r = await app.api("uga/race", HTTPClient.METHOD_POST, {"world": world_sel})
	if r.has("error"):
		toast(str(r.error), false)
		return
	race = r
	app.render()

func join_race(code: String) -> void:
	code = code.strip_edges().to_upper()
	if code.length() != 6:
		toast("Kod 6 karakter olmalı.", false)
		return
	var r = await app.api("uga/race/%s" % code)
	if r.has("error"):
		toast(str(r.error), false)
		return
	race = r
	app.render()

func render_online() -> void:
	var c = app.content
	back(c, "Sıralama & Yarış")
	var rec = card_panel(c)
	txt("Rekorların", rec, 16, GOLD_C)
	for w in range(D.WORLDS.size()):
		if w > int(meta.p.world) and meta.best_wave(w) == 0:
			continue
		txt("%d. %s · en iyi dalga %d/%d" % [w + 1, D.WORLDS[w].name, meta.best_wave(w), D.WAVES_PER_WORLD], rec, 13, INK)
	var np = card_panel(c)
	txt("Oyuncu adın (sıralamada görünür)", np, 13, MUTED)
	var nr = row(np, 8)
	var name_edit = LineEdit.new()
	name_edit.max_length = 16
	name_edit.placeholder_text = "3-16 harf"
	name_edit.text = str(meta.p.get("name", ""))
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.custom_minimum_size = Vector2(10, 42)
	nr.add_child(name_edit)
	var nb = btn("Kaydet", nr, func():
		var clean = name_edit.text.strip_edges()
		if clean.length() < 3 or clean.length() > 16:
			toast("Ad 3-16 karakter olmalı.", false)
			return
		meta.p.name = clean
		meta.save()
		toast("Ad kaydedildi")
		if online():
			app.api("uga/score", HTTPClient.METHOD_POST, {"world": world_sel, "wave": meta.best_wave(world_sel), "name": clean})
		board_data = {}
		open("uga_online"), false, false, 42)
	nb.size_flags_horizontal = Control.SIZE_SHRINK_END
	nb.custom_minimum_size.x = 90
	if not online():
		var p = card_panel(c, Color("e7a36d"))
		txt("Çevrimdışısın. Dünya sıralaması ve arkadaş yarışı için internete bağlanıp ayarlardan sunucuya bağlan. Oyunun geri kalanı internetsiz çalışır.", p, 13, INK, true)
		return
	# sıralama
	var bp = card_panel(c)
	var hr = row(bp, 6)
	title("%d. Dünya sıralaması" % (world_sel + 1), hr, 17)
	if board_data.is_empty() or int(board_data.get("world", -1)) != world_sel:
		txt("Yükleniyor…", bp, 13, MUTED)
		load_board(world_sel)
	elif board_data.has("error"):
		txt(str(board_data.error), bp, 13, Color("ff9a8a"), true)
	else:
		var top = board_data.get("top", [])
		if top.is_empty():
			txt("Henüz kimse yok. İlk sen ol!", bp, 13, MUTED)
		for i in range(top.size()):
			txt("%d. %s · %d dalga" % [i + 1, top[i].name, int(top[i].wave)], bp, 14, Color("ffd25a") if i < 3 else INK)
		if board_data.get("me") != null:
			txt("Sen (%s): %d. sıra · %d dalga" % [board_data.me.name, int(board_data.me.rank), int(board_data.me.wave)], bp, 14, Color("9fe8ff"))
	# yarış
	var rp = card_panel(c, Color("54e0ff"))
	title("Arkadaşınla yarış", rp, 17)
	txt("Bir yarış kur, kodu arkadaşına gönder. İkiniz aynı dalgaları oynarsınız; kim daha uzağa giderse kazanır.", rp, 12, MUTED, true)
	if not race.is_empty():
		txt("Kod: %s · %d. Dünya" % [race.code, int(race.world) + 1], rp, 18, Color("ffe9b0"))
		for i in range(race.get("results", []).size()):
			var e = race.results[i]
			txt("%d. %s · dalga %d" % [i + 1, e.name, int(e.wave)], rp, 14, INK)
		var rr = row(rp, 8)
		btn("Kodu kopyala", rr, func(): DisplayServer.clipboard_set(str(race.code)); toast("Kod kopyalandı"))
		btn("YARIŞI OYNA", rr, func():
			race_active = str(race.code)
			challenge_active = false
			start_run(int(race.world), int(race.seed)), false, true, 46)
		btn("Sonuçları yenile", rp, func(): join_race(str(race.code)))
	else:
		btn("Yarış kur (%d. Dünya)" % (world_sel + 1), rp, func(): create_race(), false, true, 46)
	var jr = row(rp, 8)
	var edit = LineEdit.new()
	edit.placeholder_text = "Yarış kodu"
	edit.max_length = 6
	edit.text = race_input
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.custom_minimum_size = Vector2(10, 42)
	edit.text_changed.connect(func(t): race_input = t)
	jr.add_child(edit)
	var jb = btn("Katıl", jr, func(): join_race(race_input), false, false, 42)
	jb.size_flags_horizontal = Control.SIZE_SHRINK_END
	jb.custom_minimum_size.x = 90
