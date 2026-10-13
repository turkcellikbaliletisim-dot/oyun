extends RefCounted
# UGACHA modu menüleri: ana merkez, kahramanlar, totemler, sandıklar,
# görevler, yeniden doğuş ve koşu sonu. Tüm satırlar 370 px genişliğe sığacak
# şekilde sabit/esnek ölçülerle kurulur (taşma ve kayma olmasın).

const D = preload("res://native/uga/uga_data.gd")
const Meta = preload("res://native/uga/uga_meta.gd")
const Sim = preload("res://native/uga/uga_sim.gd")
const Battle = preload("res://native/uga/uga_battle.gd")

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

func back(parent: Node, label: String) -> void:
	var r = row(parent, 8)
	var b = btn("‹ Geri", r, func(): open("lobby"), false, false, 38)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.custom_minimum_size.x = 86
	title(label, r, 22)
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
	if meta.daily_ready():
		var g = card_panel(c, Color("54e0ff"))
		var r = row(g)
		icon(r, "icon_daily_gift.png" if art("icon_daily_gift.png") != null else "scene_chest.png", 34)
		txt("Günlük hediye hazır", r, 15, INK, true)
		var b = btn("Al", r, func():
			var out = meta.claim_daily()
			if not out.is_empty():
				toast("+%d elmas, +%d altın, sandık" % [out.diamond, out.gold])
			open("lobby"), false, true, 40)
		b.size_flags_horizontal = Control.SIZE_SHRINK_END
		b.custom_minimum_size.x = 80
	# dünya kartı
	var unlocked = int(meta.p.world)
	world_sel = clampi(world_sel, 0, unlocked)
	var w = D.WORLDS[world_sel]
	var holder = PanelContainer.new()
	holder.clip_contents = true
	holder.custom_minimum_size.y = 250
	holder.add_theme_stylebox_override("panel", app.box(Color("111b24"), Color("6e6042"), 1, 14, 0))
	c.add_child(holder)
	var bg = TextureRect.new()
	bg.texture = art("home_bg.png") if art("home_bg.png") != null else art("scene_play.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(bg)
	var shade = ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.07, 0.45)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(shade)
	var m = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 14)
	holder.add_child(m)
	var col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	m.add_child(col)
	var top = row(col, 6)
	var prev = btn("‹", top, func(): world_sel -= 1; open("lobby"), world_sel <= 0, false, 40)
	prev.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	prev.custom_minimum_size.x = 44
	var name_box = VBoxContainer.new()
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.add_theme_constant_override("separation", 0)
	top.add_child(name_box)
	var t1 = title("%d. Dünya" % (world_sel + 1), name_box, 16)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var t2 = title(w.name, name_box, 26)
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var next = btn("›", top, func(): world_sel += 1; open("lobby"), world_sel >= unlocked, false, 40)
	next.size_flags_horizontal = Control.SIZE_SHRINK_END
	next.custom_minimum_size.x = 44
	var gap = Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(gap)
	var best = meta.best_wave(world_sel)
	var info = txt("En iyi: %d / %d dalga%s" % [best, D.WAVES_PER_WORLD, "  ✓" if best >= D.WAVES_PER_WORLD else ""], col, 15, INK)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var bar = ProgressBar.new()
	bar.max_value = D.WAVES_PER_WORLD
	bar.value = best
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	bar.add_theme_stylebox_override("background", app.box(Color(0, 0, 0, 0.6), Color(0, 0, 0, 0), 0, 5, 0))
	bar.add_theme_stylebox_override("fill", app.box(GOLD_C, Color(0, 0, 0, 0), 0, 5, 0))
	col.add_child(bar)
	btn("SAVAŞ", col, func(): start_run(world_sel), false, true, 58)
	# takım
	var deck_box = card_panel(c)
	var dr = row(deck_box, 6)
	title("Takımın", dr, 18)
	var sp = Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dr.add_child(sp)
	var change = btn("Değiştir", dr, func(): open("uga_heroes"), false, false, 34)
	change.size_flags_horizontal = Control.SIZE_SHRINK_END
	change.custom_minimum_size.x = 96
	var cards = row(deck_box, 5)
	for h in meta.p.deck:
		var tile = hero_tile(cards, h, 1, 62)
		var lv = txt("Sv %d" % meta.hero_level(h), tile.get_child(0), 10, GOLD_C)
		lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# menü kutuları (2 sütun)
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_child(grid)
	var chests = int(meta.p.chests.common) + int(meta.p.chests.rare) + int(meta.p.chests.epic)
	var ready = 0
	for mi in meta.p.missions.list:
		if not mi.claimed and int(mi.progress) >= int(meta.mission_spec(mi.id).goal):
			ready += 1
	tile(grid, "Kahramanlar", "Yükselt, takım kur", "unit_kilic_4.png", func(): open("uga_heroes"))
	tile(grid, "Totemler", "Gücünü katla", "totem_1.png", func(): open("uga_totems"))
	tile(grid, "Sandıklar" + (" (%d)" % chests if chests > 0 else ""), "Kahraman ve parça", "chest_rare.png" if art("chest_rare.png") != null else "scene_chest.png", func(): open("uga_chests"))
	tile(grid, "Görevler" + (" (%d)" % ready if ready > 0 else ""), "Günlük elmas", "icon_mission.png" if art("icon_mission.png") != null else "icon_wave.png", func(): open("uga_missions"))
	tile(grid, "Yeniden Doğuş", "Ruh taşı: %d" % int(meta.p.soul), "icon_star_rebirth.png", func(): open("uga_rebirth"))
	tile(grid, "Kart Düellosu", "Klasik kart oyunu", "scene_friends.png", func(): open("duel"))

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

# ---------- savaş ----------

func start_run(world: int) -> void:
	if battle != null and is_instance_valid(battle):
		return
	var sim = Sim.new(meta.run_seed(), world, meta.mods(), meta.castle_bonus(), 0, meta.p.deck)
	battle = Battle.new()
	battle.setup(sim, app.skin_art, app.get_theme_default_font(), app.portrait_font)
	battle.sfx = func(name: String) -> AudioStream: return null if app.muted else app.sfx_stream(name)
	battle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	battle.z_index = 50
	app.add_child(battle)
	app.shell_margin.visible = false
	app.set_music("music_battle")
	battle.finished.connect(on_finished)

func on_finished(result: Dictionary) -> void:
	last_result = result
	last_reward = meta.finish_run(result)
	if is_instance_valid(battle):
		battle.queue_free()
	battle = null
	app.shell_margin.visible = true
	app.set_music("music_menu")
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
	var rr = row(c, 8)
	btn("Ana sayfa", rr, func(): open("lobby"))
	btn("TEKRAR", rr, func(): start_run(int(r.get("world", 0))), false, true, 48)

# ---------- kahramanlar ----------

func render_heroes() -> void:
	var c = app.content
	back(c, "Kahramanlar")
	var dp = card_panel(c)
	txt("Takım: değiştirmek istediğin yuvaya dokun, sonra aşağıdan kahraman seç.", dp, 12, MUTED, true)
	var cards = row(dp, 5)
	for i in range(5):
		var h = meta.p.deck[i]
		var t = hero_tile(cards, h, 1, 60, i == deck_slot)
		var idx = i
		press(t, func(): deck_slot = idx; open("uga_heroes"))
	var all = D.SUMMON_POOL.duplicate()
	all.append("ejder_yavrusu")
	for h in all:
		var spec = D.HEROES[h]
		var lv = meta.hero_level(h)
		var p = card_panel(c, GOLD_C if meta.p.deck.has(h) else Color("6e6042"))
		var r = row(p, 8)
		var pic = TextureRect.new()
		pic.texture = hero_art(h, 3)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.custom_minimum_size = Vector2(64, 64)
		if lv <= 0:
			pic.modulate = Color(0.3, 0.3, 0.3)
		r.add_child(pic)
		var v = VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 2)
		r.add_child(v)
		txt("%s%s" % [spec.name, ("  · Sv %d" % lv) if lv > 0 else ""], v, 15, GOLD_C if lv > 0 else MUTED)
		txt(str(spec.text), v, 12, INK, true)
		if h == "ejder_yavrusu":
			txt("Yalnızca 4★ ve üstü birleştirmede çıkar.", v, 11, MUTED, true)
			continue
		if lv <= 0:
			txt("Kilitli · sandıklardan açılır", v, 12, MUTED)
			continue
		var cost = meta.upgrade_cost(h)
		var sh = int(meta.p.shards.get(h, 0))
		txt("Parça %d/%d · %d altın" % [sh, cost.shards, cost.gold], v, 12, Color("cfe8ff"))
		var br = row(p, 8)
		var hh = h
		btn("Yükselt", br, func():
			if meta.upgrade_hero(hh):
				toast("%s seviye %d!" % [spec.name, meta.hero_level(hh)])
			else:
				toast(meta.err, false)
			open("uga_heroes"), lv >= Meta.MAX_HERO_LEVEL or sh < cost.shards or int(meta.p.gold) < cost.gold)
		btn("Takımda" if meta.p.deck.has(h) else "Takıma al", br, func():
			if meta.set_deck_slot(deck_slot, hh):
				toast("%s takımda" % spec.name)
			open("uga_heroes"), meta.p.deck.has(h))

# ---------- totemler ----------

func render_totems() -> void:
	var c = app.content
	back(c, "Totemler")
	txt("Totemler kalıcıdır; yeniden doğuşta da korunur.", c, 12, MUTED, true)
	for id in Meta.TOTEMS:
		var spec = Meta.TOTEMS[id]
		var lv = int(meta.p.totems[id])
		var p = card_panel(c)
		var r = row(p, 10)
		icon(r, spec.art + ".png", 72)
		var v = VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(v)
		txt("%s · Sv %d" % [spec.name, lv], v, 16, GOLD_C)
		txt(spec.text, v, 12, INK, true)
		var cost = meta.totem_cost(id)
		var tid = id
		btn("Yükselt · %d elmas" % cost, v, func():
			if meta.upgrade_totem(tid):
				toast("%s seviye %d" % [spec.name, int(meta.p.totems[tid])])
			else:
				toast(meta.err, false)
			open("uga_totems"), int(meta.p.diamond) < cost or lv >= Meta.MAX_TOTEM_LEVEL)

# ---------- sandıklar ----------

func render_chests() -> void:
	var c = app.content
	back(c, "Sandıklar")
	if not chest_reward.is_empty():
		var p = card_panel(c, GOLD_C)
		txt("Sandıktan çıkanlar", p, 16, GOLD_C)
		var r = row(p, 14)
		stat(r, "icon_gold_coin.png", "+%d" % int(chest_reward.gold), Color("ffd25a"))
		if int(chest_reward.diamond) > 0:
			stat(r, "icon_diamond.png" if art("icon_diamond.png") != null else "icon_dust.png", "+%d" % int(chest_reward.diamond), Color("9fe8ff"))
		var parts = []
		for h in chest_reward.shards:
			parts.append("%s +%d" % [D.HEROES[h].name, int(chest_reward.shards[h])])
		txt("Parça: " + ", ".join(parts), p, 13, INK, true)
		if str(chest_reward.hero) != "":
			var hr = row(p, 8)
			hero_tile(hr, chest_reward.hero, 3, 70)
			txt("YENİ KAHRAMAN: %s!" % D.HEROES[chest_reward.hero].name, hr, 16, Color("7dff9a"), true)
		chest_reward = {}
	var specs = [["common", "Sıradan Sandık", "Altın ve az parça", 30], ["rare", "Nadir Sandık", "Çok parça, elmas, %35 yeni kahraman", 90], ["epic", "Destansı Sandık", "Bol ödül, kesin yeni kahraman", 250]]
	for s in specs:
		var kind = s[0]
		var n = int(meta.p.chests[kind])
		var p = card_panel(c)
		var r = row(p, 10)
		icon(r, "chest_%s.png" % kind if art("chest_%s.png" % kind) != null else "scene_chest.png", 72)
		var v = VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(v)
		txt("%s  ×%d" % [s[1], n], v, 16, GOLD_C)
		txt(s[2], v, 12, INK, true)
		var br = row(v, 6)
		var k = kind
		btn("AÇ", br, func():
			chest_reward = meta.open_chest(k)
			open("uga_chests"), n <= 0, true, 40)
		btn("%d elmas" % s[3], br, func():
			if not meta.buy_chest(k):
				toast(meta.err, false)
			open("uga_chests"), int(meta.p.diamond) < int(s[3]))

# ---------- görevler ----------

func render_missions() -> void:
	var c = app.content
	back(c, "Görevler")
	txt("Her gün 3 yeni görev. Ödül: elmas.", c, 12, MUTED, true)
	meta.ensure_missions()
	for i in range(meta.p.missions.list.size()):
		var m = meta.p.missions.list[i]
		var spec = meta.mission_spec(m.id)
		var p = card_panel(c, GOLD_C if int(m.progress) >= int(spec.goal) and not m.claimed else Color("6e6042"))
		var r = row(p, 8)
		icon(r, "icon_mission.png" if art("icon_mission.png") != null else "icon_wave.png", 40)
		var v = VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(v)
		txt(spec.text % int(spec.goal), v, 15, INK, true)
		var bar = ProgressBar.new()
		bar.max_value = int(spec.goal)
		bar.value = mini(int(m.progress), int(spec.goal))
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 10)
		bar.add_theme_stylebox_override("background", app.box(Color(0, 0, 0, 0.6), Color(0, 0, 0, 0), 0, 5, 0))
		bar.add_theme_stylebox_override("fill", app.box(Color("54e0ff"), Color(0, 0, 0, 0), 0, 5, 0))
		v.add_child(bar)
		txt("%d / %d · ödül %d elmas" % [mini(int(m.progress), int(spec.goal)), int(spec.goal), int(spec.reward)], v, 12, MUTED)
		var idx = i
		var b = btn("Alındı" if m.claimed else "Al", r, func():
			if meta.claim_mission(idx):
				toast("+%d elmas" % int(spec.reward))
			open("uga_missions"), m.claimed or int(m.progress) < int(spec.goal), not m.claimed, 40)
		b.size_flags_horizontal = Control.SIZE_SHRINK_END
		b.custom_minimum_size.x = 80

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
