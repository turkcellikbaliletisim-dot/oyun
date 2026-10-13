extends "res://native/main.gd"
## Presentation only. Accounts, rules, rewards and legal moves remain in main.gd.
var game_header: HBoxContainer
var arena: Control
var table_bg: Control
var drag_origin = Vector2.ZERO
var drag_options: Array = []
var drag_active = false
var drag_card: Control
var pointer = Vector2.ZERO
var portrait_font: Font
var feedback: Control
var saved_preferences = ""
var deck_account = ""
var drag_preview: Control
var touch_index = -1
var suppress_card_tap_until = 0
var application_paused = false
var connected = false
var reconnect_delay = 1.0
var reconnect_timer: Timer
var last_visual_play: Dictionary = {}
var connection_indicator: Label
const MobileGeometry = preload("res://native/mobile_geometry.gd")

func _ready() -> void:
	super._ready()
	Engine.max_fps = 60
	if OS.get_environment("DESTAN_SESSION_DIR") == "":
		show_loading_screen.call_deferred(false)
	reconnect_timer = Timer.new()
	reconnect_timer.one_shot = true
	reconnect_timer.timeout.connect(attempt_reconnect)
	add_child(reconnect_timer)
	var cfg = ConfigFile.new()
	if cfg.load(SESSION_FILE) == OK:
		muted = bool(cfg.get_value("preferences", "muted", true))
		hero_choice = clampi(int(cfg.get_value("preferences", "hero_choice", 0)), 0, HERO_FILES.size() - 1)
		deck_account = str(cfg.get_value("preferences", "deck_account", ""))
		var saved = cfg.get_value("preferences", "deck", [])
		if saved is Array and saved.size() == 20 and saved.all(func(id): return cards.has(int(id))):
			custom_deck = saved.duplicate()
			use_custom = bool(cfg.get_value("preferences", "use_custom", false))
		sound_button.text = "Ses: kapalı" if muted else "Ses: açık"
		sound_icon()

# ---------- ses ve müzik (skin/audio) ----------
const SFX_FILES = {"play": "play_card", "attack": "attack", "hit": "hit", "heal": "heal", "spell": "spell", "turn": "turn_start", "end": "end_turn", "win": "victory", "lose": "defeat", "click": "click", "pack": "pack_open", "flip": "card_flip"}
var sfx_cache = {}
var music_player: AudioStreamPlayer
var music_name = ""

func sfx_stream(name: String) -> AudioStream:
	if not sfx_cache.has(name):
		var path = "res://native/skin/audio/%s.ogg" % name
		sfx_cache[name] = load(path) if ResourceLoader.exists(path) else null
	return sfx_cache[name]

func play_sound(kind: String = "play") -> void:
	if muted:
		return
	var stream = sfx_stream(str(SFX_FILES.get(kind, "")))
	if stream == null:
		super.play_sound(kind)
		return
	audio.stream = stream
	audio.play()

func set_music(name: String) -> void:
	if music_player == null:
		music_player = AudioStreamPlayer.new()
		music_player.volume_db = -14.0
		add_child(music_player)
	if muted or name == "":
		music_player.stop()
		music_name = ""
		return
	if name == music_name and music_player.playing:
		return
	var stream = sfx_stream(name)
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	music_name = name
	music_player.stream = stream
	music_player.play()


func content_width() -> float:
	return maxf(1, get_viewport_rect().size.x - shell_margin.get_theme_constant("margin_left") - shell_margin.get_theme_constant("margin_right"))

func resize_layout() -> void:
	if view == "deck" and not deck_counts.is_empty():
		custom_deck = builder_deck()
	compact = get_viewport_rect().size.x < 700
	if is_instance_valid(shell_margin) and OS.get_name() in ["Android", "iOS"]:
		var margins = MobileGeometry.safe_margins(get_viewport_rect().size, Vector2(DisplayServer.screen_get_size()), Rect2(DisplayServer.get_display_safe_area()))
		for entry in [["left", margins.x], ["top", margins.y], ["right", margins.z], ["bottom", margins.w]]:
			shell_margin.add_theme_constant_override("margin_" + entry[0], int(entry[1]))
	if is_instance_valid(content):
		render()

func persist_session() -> void:
	super.persist_session()
	var cfg = ConfigFile.new()
	cfg.load(SESSION_FILE)
	cfg.set_value("preferences", "muted", muted)
	cfg.set_value("preferences", "hero_choice", hero_choice)
	cfg.set_value("preferences", "deck", custom_deck)
	cfg.set_value("preferences", "use_custom", use_custom)
	cfg.set_value("preferences", "deck_account", account.get("id", deck_account))
	cfg.save(SESSION_FILE)

func sound_icon() -> void:
	var tex = skin_art("icon_sound_off.png" if muted else "icon_sound_on.png")
	if tex != null and is_instance_valid(sound_button):
		sound_button.icon = tex
		sound_button.expand_icon = true
		sound_button.add_theme_constant_override("icon_max_width", 24)

func toggle_sound() -> void:
	super.toggle_sound()
	sound_icon()
	set_music("music_battle" if (not room.is_empty() and not gallery_open) else "music_menu")
	play_sound("click")
	persist_session()

func accept_account(result: Dictionary) -> void:
	super.accept_account(result)
	if not deck_account.is_empty() and deck_account != str(account.id):
		use_custom = false
		custom_deck = data.decks.starter.cards.duplicate()
		deck_counts = {}
	deck_account = str(account.id)

func connect_account() -> void:
	var next = address.text.strip_edges()
	if OS.has_feature("mobile") and not OS.has_feature("editor") and not OS.has_feature("web") and not next.begins_with("https://"):
		notice.text = "Oyun sunucusunun HTTPS adresini gir."
		if account.is_empty():
			await enter_offline()
			notice.text = "Çevrimdışı mod · Çevrimiçi için sunucunun HTTPS adresini gir."
			notice.visible = true
		else:
			network_panel.get_parent().visible = true
		render()
		return
	await super.connect_account()

func api(path: String, method: int = HTTPClient.METHOD_GET, body: Dictionary = {}) -> Dictionary:
	var response = await super.api(path, method, body)
	if path != "health":
		if response.get("network", false):
			connected = false
			cancel_gesture()
			if is_instance_valid(poll):
				poll.stop()
			if is_instance_valid(reconnect_timer) and reconnect_timer.is_stopped() and not application_paused:
				reconnect_timer.start(reconnect_delay)
		elif not response.has("error"):
			connected = true
			reconnect_delay = 1.0
			if is_instance_valid(reconnect_timer):
				reconnect_timer.stop()

		if is_instance_valid(connection_indicator):
			connection_indicator.text = "OFFLINE" if offline_mode else ("ON" if connected else "OFF")
			connection_indicator.add_theme_color_override("font_color", Color("90dcaa") if connected else Color("e7a36d"))
			connection_indicator.tooltip_text = "Çevrimdışı mod" if offline_mode else ("Bağlı" if connected else "Bağlantı bekleniyor")
	if response.has("error") and path != "health" and is_instance_valid(notice):
		toast("Bağlantı kesildi · Yeniden bağlanılıyor" if response.get("network", false) else str(response.error), Color("ffc491"))
	return response

func attempt_reconnect() -> void:
	if application_paused:
		return
	if busy:
		reconnect_timer.start(1.0)
		return
	if account.is_empty():
		await connect_account()
	else:
		await refresh()
	if connected and is_instance_valid(poll):
		poll.start()
	elif not connected:
		reconnect_delay = minf(30, reconnect_delay * 2)
		reconnect_timer.start(reconnect_delay)

func mutate(path: String, body: Dictionary, retryable: bool = false) -> void:
	if not connected:
		toast("Bağlantının dönmesini bekle", Color("ffc491"))
		return
	await super.mutate(path, body, retryable)

func move(action: Dictionary) -> void:
	if connected:
		if not busy and action.get("type") == "play" and room.get("state") != null:
			var hand: Array = room.state.players[0].hand
			var index = int(action.get("index", -1))
			if index >= 0 and index < hand.size():
				last_visual_play = {"cardId": int(hand[index]), "target": str(action.get("target", "")), "version": room.version}
		await super.move(action)
		last_visual_play = {}
	else:
		toast("Bağlantının dönmesini bekle", Color("ffc491"))

func build_shell() -> void:
	BG = Color("0c1720")
	SURFACE = Color("18252e")
	SURFACE_HI = Color("293943")
	GOLD = Color("ddbf7e")
	INK = Color("f7ecd4")
	MUTED = Color("a7b4bd")
	theme = make_theme()
	skin_theme_extras()
	portrait_font = skin_font("font_title.ttf", 700) if skin_font("font_title.ttf", 700) != null else load("res://native/mobile-assets/fonts/CormorantGaramond.ttf")
	picture(load("res://native/mobile-assets/backdrop.svg"), self)
	shell_margin = MarginContainer.new()
	shell_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		shell_margin.add_theme_constant_override("margin_" + side, 10)
	add_child(shell_margin)
	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 6)
	shell_margin.add_child(layout)
	game_header = HBoxContainer.new()
	game_header.custom_minimum_size.y = 50
	layout.add_child(game_header)
	var brand = label("DESTAN DİYARLARI", game_header, 18)
	brand.add_theme_font_override("font", portrait_font)
	brand.add_theme_color_override("font_color", GOLD)
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brand.clip_text = true
	brand.autowrap_mode = TextServer.AUTOWRAP_OFF
	var wordmark = skin_art("logo_wordmark.png")
	if wordmark != null:
		# Yazı yerine logo; metin erişilebilirlik için ipucu olarak kalır.
		brand.text = ""
		brand.tooltip_text = "Destan Diyarları"
		var logo = TextureRect.new()
		logo.name = "SkinWordmark"
		logo.texture = wordmark
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		logo.custom_minimum_size = Vector2(200, 50)
		logo.tooltip_text = "Destan Diyarları"
		logo.set_meta("skin_asset", "logo_wordmark.png")
		game_header.add_child(logo)
		game_header.move_child(logo, brand.get_index())
	account_line = label("", game_header, 11)
	account_line.visible = false
	connection_indicator = label("ON", game_header, 10)
	connection_indicator.autowrap_mode = TextServer.AUTOWRAP_OFF
	connection_indicator.add_theme_color_override("font_color", Color("e7a36d"))
	var settings_button = small_button("", game_header, func(): network_panel.get_parent().visible = not network_panel.get_parent().visible)
	settings_button.icon = skin_art("icon_settings.png") if skin_art("icon_settings.png") != null else load("res://native/mobile-assets/gear.svg")
	settings_button.expand_icon = true
	for key in ["normal", "hover", "pressed", "focus"]:
		settings_button.add_theme_stylebox_override(key, StyleBoxEmpty.new())
	settings_button.custom_minimum_size = Vector2(44, 44)
	notice = label("Bağlanılıyor…", layout, 12)
	notice.visible = false
	network_panel = panel(layout, SURFACE, GOLD, 1, 12)
	network_panel.get_parent().visible = false
	heading("BAĞLANTI VE SES", network_panel, 17)
	var line = HBoxContainer.new()
	network_panel.add_child(line)
	address = LineEdit.new()
	address.text = endpoint
	address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	address.custom_minimum_size.y = 56
	line.add_child(address)
	button("Bağlan", line, connect_account)
	var tools = HFlowContainer.new()
	network_panel.add_child(tools)
	sound_button = button("Ses: kapalı", tools, toggle_sound)
	sound_icon()
	button("Hesabım", tools, func(): network_panel.get_parent().visible = false; render_profile())
	if OS.get_name() not in ["Android", "iOS"]:
		button("Yerel sunucu", tools, func(): address.text = "http://127.0.0.1:8080"; connect_account())
	if OS.get_name() not in ["Android", "iOS"]:
		button("Tam ekran", tools, toggle_fullscreen)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	action_bar = HFlowContainer.new()
	action_bar.visible = false
	layout.add_child(action_bar)
	nav_bar = HBoxContainer.new()
	nav_bar.add_theme_constant_override("separation", 0)
	layout.add_child(nav_bar)
	for entry in [["play", "Oyna", "play"], ["story", "Yolculuk", "story"], ["collection", "Kartlar", "cards"], ["deck", "Destem", "deck"]]:
		var nav = Button.new()
		nav.custom_minimum_size = Vector2(0, 66)
		nav.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nav.pressed.connect(open_tab.bind(entry[0]))
		nav_bar.add_child(nav)
		nav_buttons[entry[0]] = nav
		var center = VBoxContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center.alignment = BoxContainer.ALIGNMENT_CENTER
		center.add_theme_constant_override("separation", 2)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nav.add_child(center)
		var icon = TextureRect.new()
		icon.texture = skin_art("icon_%s.png" % entry[2]) if skin_art("icon_%s.png" % entry[2]) != null else load("res://native/mobile-assets/" + entry[2] + ".svg")
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(32, 32)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(icon)
		var text = label(entry[1], center, 12)
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	save_dialog = FileDialog.new()
	save_dialog.use_native_dialog = OS.get_name() not in ["Android", "iOS"]
	save_dialog.access = FileDialog.ACCESS_FILESYSTEM
	save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	save_dialog.file_selected.connect(func(path):
		var file = FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_string(save_text)
			toast("Kaydedildi", GOLD))
	add_child(save_dialog)

func picture(texture: Texture2D, parent: Node, alpha: float = 1.0) -> TextureRect:
	var art = TextureRect.new()
	art.texture = texture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.modulate.a = alpha
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(art)
	return art

func heading(text: String, parent: Node, size: int = 22) -> Label:
	var title = super.heading(text, parent, size)
	if portrait_font != null:
		title.add_theme_font_override("font", portrait_font)
	return title

func open_tab(tab: String) -> void:
	if busy:
		return
	gallery_open = tab == "collection"
	view = "deck" if tab == "deck" else "story" if tab == "story" else "merge" if tab == "merge" else "lobby"
	selected = []
	focus = {}
	scroll.scroll_vertical = 0
	render()

func update_nav() -> void:
	var active = "collection" if gallery_open else "deck" if view == "deck" else "story" if view == "story" else "play"
	for key in nav_buttons:
		var on = key == active
		var style = box(Color("263b43") if on else Color("111e27"), GOLD if on else Color("293741"), 1, 4, 3)
		if on:
			style.border_width_top = 3
		nav_buttons[key].add_theme_stylebox_override("normal", style)

func render() -> void:
	if not is_instance_valid(content):
		return
	cancel_gesture()
	clear_content()
	if is_instance_valid(feedback):
		feedback.queue_free()
	if is_instance_valid(drag_preview):
		drag_preview.queue_free()
		drag_preview = null
	arena = null
	if is_instance_valid(table_bg):
		table_bg.queue_free()
	table_bg = null
	unit_nodes = {}
	hero_nodes = {}
	for child in action_bar.get_children():
		action_bar.remove_child(child)
		child.queue_free()
	action_bar.visible = false
	content.custom_minimum_size.y = 0
	var battle = not room.is_empty() and not gallery_open and view not in ["deck", "story"]
	nav_bar.visible = not battle
	set_music("music_battle" if battle else "music_menu")
	game_header.visible = true
	notice.visible = account.is_empty()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if battle else ScrollContainer.SCROLL_MODE_AUTO
	update_nav()
	if not account.is_empty():
		var preferences = JSON.stringify([muted, use_custom, custom_deck, account.id])
		if preferences != saved_preferences:
			saved_preferences = preferences
			persist_session()
	if gallery_open:
		render_collection()
	elif view == "story" and not account.is_empty():
		render_story()
	elif view == "deck" and not account.is_empty():
		render_deck_builder()
	elif view == "merge" and not account.is_empty():
		render_merge()
	elif room.is_empty():
		render_lobby()
	else:
		render_match()

func resource_row(parent: Node) -> void:
	if account.is_empty():
		return
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	art_chip(row, "chip_gold.png", Rect2(39, 5, 322, 110), "%d altın" % int(account.profile.gold), "icon_gold.png", Color("2a1500"))
	art_chip(row, "chip_dust.png", Rect2(28, 5, 344, 110), "%d toz" % int(account.profile.dust), "icon_dust.png", Color("fff4ff"))
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var league_icon = TextureRect.new()
	league_icon.texture = skin_art("badge_rank_bronze.png" if int(account.mmr) < 1200 else "badge_rank_silver.png" if int(account.mmr) < 1600 else "badge_rank_gold.png")
	if league_icon.texture == null:
		league_icon.texture = skin_art("icon_league.png")
	league_icon.tooltip_text = str(account.league)
	league_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	league_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	league_icon.custom_minimum_size = Vector2(24, 24)
	row.add_child(league_icon)
	var rank = muted_label(str(account.league), row, 14)
	rank.autowrap_mode = TextServer.AUTOWRAP_OFF

func feature(parent: Node, art_id: int, title: String, sub: String, height: float, scene: String = "") -> VBoxContainer:
	var holder = PanelContainer.new()
	holder.clip_contents = true
	holder.custom_minimum_size.y = height
	holder.add_theme_stylebox_override("panel", box(Color("111b24"), Color("6e6042"), 1, 14, 0))
	parent.add_child(holder)
	var scene_tex = skin_art(scene) if scene != "" else null
	picture(scene_tex if scene_tex != null else (load("res://native/mobile-assets/chest.svg") if art_id == -1 else texture_for(art_id)), holder)
	var shade = GradientTexture2D.new()
	shade.gradient = Gradient.new()
	shade.gradient.set_color(0, Color(0.025, 0.05, 0.08, 0.1))
	shade.gradient.set_color(1, Color(0.025, 0.05, 0.08, 0.98))
	shade.gradient.add_point(0.4, Color(0.025, 0.05, 0.08, 0.72))
	shade.fill_from = Vector2(0, 0)
	shade.fill_to = Vector2(0, 1)
	picture(shade, holder)
	var margin = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	holder.add_child(margin)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)
	var gap = Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(gap)
	var title_label = heading(title, column, 28 if height > 180 else 20)
	var sub_label = muted_label(sub, column, 14)
	for text_label in [title_label, sub_label]:
		text_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		text_label.add_theme_constant_override("outline_size", 5)
	sub_label.add_theme_color_override("font_color", Color("d8dde0"))
	return column

func render_lobby() -> void:
	if account.is_empty():
		var disconnected = feature(content, 27, "Destanın seni bekliyor", "Bağlantı kurulunca yolculuğa çık.", 250)
		var offline_art = art_slice(disconnected, "offline.png")
		if offline_art != null:
			offline_art.custom_minimum_size = Vector2(0, 90)
			disconnected.move_child(offline_art, 0)
		primary_button("Yeniden bağlan", disconnected, connect_account)
		var tips = ["Kartı sürükleyip sahaya bırakarak oynayabilirsin.", "Her tur enerjin bir kristal artar.", "Bir kahramanı hedeflemek için kartına dokun, sonra rakibe sürükle.", "Yolculuk bölümlerini bitirdikçe sandık kazanırsın."]
		var tip_panel = art_slice(content, "loading_tip_panel.png")
		if tip_panel != null:
			tip_panel.custom_minimum_size = Vector2(0, 76)
			var tip = label("İPUCU · " + tips[int(Time.get_ticks_msec() / 1000) % tips.size()], tip_panel, 12)
			tip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			tip.offset_left = 28
			tip.offset_right = -28
			tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			tip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			tip.add_theme_color_override("font_color", Color("ead9b0"))
		return
	resource_row(content)
	var landscape = get_viewport_rect().size.x > 650
	var features: Container = HBoxContainer.new() if landscape else VBoxContainer.new()
	features.add_theme_constant_override("separation", 14)
	content.add_child(features)
	var quick_holder = VBoxContainer.new()
	quick_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	features.add_child(quick_holder)
	var quick = feature(quick_holder, 27, "Efsaneni yaz", "Anadolu'nun kadim gücü senin elinde.", clampf(get_viewport_rect().size.y * 0.44, 180, 330) if landscape else 300, "scene_play.png")
	primary_button("OYNA  ›", quick, choose_mode)
	var journey_holder = VBoxContainer.new()
	journey_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	features.add_child(journey_holder)
	var next = data.chapters[next_chapter_id() - 1]
	var journey = feature(journey_holder, 6, "Anadolu yolculuğu", "%d. %s" % [next.id, next.title], clampf(get_viewport_rect().size.y * 0.44, 180, 330) if landscape else 160, "scene_story.png")
	primary_button("DEVAM ET  ›", journey, func(): view = "lobby"; mutate("solo", {"chapterId": next.id}))
	progress_art(journey, chapters_done(), 10)
	var more: Container = HBoxContainer.new()
	more.add_theme_constant_override("separation", 14)
	content.add_child(more)
	var cards_holder = VBoxContainer.new()
	cards_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	more.add_child(cards_holder)
	var cards_tile = feature(cards_holder, -1, "Sandık", "Kartlarını topla.", 140, "scene_chest.png")
	tile_press(cards_tile, func(): open_tab("collection"))
	var friends_holder = VBoxContainer.new()
	friends_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	more.add_child(friends_holder)
	var friends_tile = feature(friends_holder, 2, "Düello", "Oda kur, kodu paylaş.", 140, "scene_friends.png")
	tile_press(friends_tile, render_social)
	var merge_tile = feature(content, 4, "Birleştir", "Birlikleri birleştir, dalgaları geç. İnternetsiz oynanır.", 120)
	tile_press(merge_tile, func(): open_tab("merge"))

var merge_pick: int = -1
var merge_speed: int = 1
var merge_info: String = ""

const Merge_ = preload("res://native/merge_engine.gd")
const MERGE_COLORS = [Color("5a2b2b"), Color("2b4a2b"), Color("3c2b5a"), Color("2b3f5a")]

func merge_pic(file: String, height: float, parent: Node = null) -> TextureRect:
	var tex = skin_art(file)
	if tex == null:
		return null
	var view = TextureRect.new()
	view.texture = tex
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.custom_minimum_size = Vector2(0, height)
	(parent if parent != null else content).add_child(view)
	return view

func merge_stat(parent: Node, icon_file: String, text: String) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	var tex = skin_art(icon_file)
	if tex != null:
		var icon = TextureRect.new()
		icon.texture = tex
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(26, 26)
		row.add_child(icon)
	var stat_label = label(text, row, 14)
	stat_label.autowrap_mode = TextServer.AUTOWRAP_OFF

func merge_cell_style(file: String, fallback: Color) -> StyleBox:
	var tex = skin_art(file)
	if tex == null:
		return box(fallback, Color("3a4a55"), 1, 8, 4)
	var style = StyleBoxTexture.new()
	style.texture = tex
	style.content_margin_top = 16
	style.content_margin_bottom = 20
	style.content_margin_left = 6
	style.content_margin_right = 6
	return style

func merge_animate(b: Dictionary) -> void:
	clear_content()
	var title = ("BOSS · " if b.boss else "") + "Dalga %d savaşı" % int(b.wave)
	heading(title, content, 24)
	if b.boss:
		var boss_tex = skin_art("boss_%d.png" % (((int(b.wave) / 5 - 1) % 3) + 1))
		if boss_tex != null:
			var boss_view = TextureRect.new()
			boss_view.texture = boss_tex
			boss_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			boss_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			boss_view.custom_minimum_size = Vector2(0, 180)
			content.add_child(boss_view)
	else:
		var frame_tex = skin_art("merge_frame.png")
		if frame_tex != null:
			var frame_view = TextureRect.new()
			frame_view.texture = frame_tex
			frame_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			frame_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			frame_view.custom_minimum_size = Vector2(0, 110)
			content.add_child(frame_view)
	var counts = muted_label("", content, 14)
	var foe_files = ["enemy_kurt.png", "enemy_haydut.png", "enemy_iskelet.png", "enemy_cin.png", "enemy_golem_kucuk.png", "enemy_kara_okcu.png"]
	var foe_row = HBoxContainer.new()
	foe_row.add_theme_constant_override("separation", 4)
	foe_row.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(foe_row)
	for fi in range(mini(int(b.foes0), 6)):
		var foe_pic = merge_pic(foe_files[(int(b.wave) + fi) % foe_files.size()], 56, foe_row)
		if foe_pic != null:
			foe_pic.custom_minimum_size = Vector2(56, 56)
	muted_label("Düşman", content, 12)
	var foe_bar = ProgressBar.new()
	foe_bar.custom_minimum_size = Vector2(0, 26)
	foe_bar.max_value = maxf(1.0, float(b.foes_hp0))
	foe_bar.value = foe_bar.max_value
	foe_bar.show_percentage = false
	foe_bar.add_theme_stylebox_override("fill", box(Color("b0443a"), Color(0, 0, 0, 0), 0, 6, 0))
	content.add_child(foe_bar)
	muted_label("Senin ordun", content, 12)
	var my_bar = ProgressBar.new()
	my_bar.custom_minimum_size = Vector2(0, 26)
	my_bar.max_value = maxf(1.0, float(b.mine_hp0))
	my_bar.value = my_bar.max_value
	my_bar.show_percentage = false
	my_bar.add_theme_stylebox_override("fill", box(Color("4c9a52"), Color(0, 0, 0, 0), 0, 6, 0))
	content.add_child(my_bar)
	var round_no = 0
	for frame in b.frames:
		round_no += 1
		var fsum = 0
		for h in frame.foes:
			fsum += int(h)
		var msum = 0
		for h in frame.mine:
			msum += int(h)
		foe_bar.value = fsum
		my_bar.value = msum
		counts.text = "Tur %d · %d birliğin vs %d düşman" % [round_no, frame.mine.size(), frame.foes.size()]
		if is_inside_tree() and not DisplayServer.get_name() == "headless":
			await get_tree().create_timer(0.3 / merge_speed).timeout

func merge_do(path: String, body: Dictionary = {}) -> void:
	var result = merge_call(path, body)
	if result.has("battle"):
		await merge_animate(result.battle)
		merge_pic("banner_victory.png" if result.battle.won else "banner_defeat.png", 110)
		if result.battle.won:
			var burst = skin_art("merge_burst.png")
			if burst != null:
				var burst_view = TextureRect.new()
				burst_view.texture = burst
				burst_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				burst_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				burst_view.custom_minimum_size = Vector2(0, 160)
				content.add_child(burst_view)
			if is_inside_tree() and not DisplayServer.get_name() == "headless":
				await get_tree().create_timer(0.8).timeout
	if result.has("error"):
		merge_info = str(result.error)
	elif result.has("battle"):
		var b = result.battle
		merge_info = ("Dalga %d kazanıldı! +%d altın" % [int(b.wave), int(b.get("reward", 0))]) if b.won else ("Dalga %d kaybedildi. Kalan can: %d%s" % [int(b.wave), int(b.lives), " · Koşu bitti" if b.over else ""])
	else:
		merge_info = ""
	merge_pick = -1
	render()

func render_merge() -> void:
	var v = merge_call("merge")
	var g = v.state
	heading("Birleştir · Dalga %d" % int(g.wave), content, 24)
	var stats = HBoxContainer.new()
	stats.add_theme_constant_override("separation", 12)
	content.add_child(stats)
	merge_stat(stats, "icon_gold_coin.png", str(int(g.gold)))
	merge_stat(stats, "icon_heart.png", str(int(g.lives)))
	merge_stat(stats, "icon_wave.png", "%d/%d" % [int(g.wave), int(v.enemies)])
	merge_stat(stats, "icon_star_rebirth.png", "%d (en iyi %d)" % [int(g.stars), int(v.best)])
	if bool(g.over):
		merge_pic("banner_rebirth.png", 110)
	if merge_info != "":
		label(merge_info, content, 15)
	if bool(v.boss):
		merge_pic("banner_boss_warning.png", 70)
		var boss_icon = skin_art("boss_%d.png" % (((int(g.wave) / 5 - 1) % 3) + 1))
		if boss_icon != null:
			var boss_banner = TextureRect.new()
			boss_banner.texture = boss_icon
			boss_banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			boss_banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			boss_banner.custom_minimum_size = Vector2(0, 120)
			content.add_child(boss_banner)
		label("⚠ Boss dalgası: %s seni bekliyor (ödül ×2)" % Merge_.BOSS_NAMES[(int(g.wave) / 5 - 1) % Merge_.BOSS_NAMES.size()], content, 14)
	if int(g.wave) == 1 and g.log.is_empty() and not bool(g.over):
		muted_label("Totem seç (koşunun başında):", content, 12)
		var totem_row = HBoxContainer.new()
		totem_row.add_theme_constant_override("separation", 6)
		content.add_child(totem_row)
		for ti in range(v.totems.size()):
			var tt = v.totems[ti]
			var tb = Button.new()
			tb.text = "%s\n%s" % [tt.name, tt.text]
			tb.add_theme_font_size_override("font_size", 9)
			tb.clip_text = true
			tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tb.custom_minimum_size = Vector2(0, 52)
			var totem_tex = skin_art("totem_%d.png" % (ti + 1))
			if totem_tex != null:
				tb.icon = totem_tex
				tb.expand_icon = true
				tb.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
				tb.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
				tb.add_theme_constant_override("icon_max_width", 48)
				tb.custom_minimum_size = Vector2(0, 92)
			tb.disabled = int(v.best) < int(tt.unlock)
			if tb.disabled:
				tb.text = "%d. dalga" % int(tt.unlock)
				var lock_tex = skin_art("icon_lock.png")
				if lock_tex != null:
					tb.icon = lock_tex
			tb.add_theme_stylebox_override("normal", box(Color("172530"), GOLD if int(g.totem) == ti else Color("3a4a55"), 3 if int(g.totem) == ti else 1, 8, 4))
			tb.pressed.connect(func(): merge_do("merge/totem", {"id": ti}))
			totem_row.add_child(tb)
	var grid = GridContainer.new()
	grid.columns = int(v.cols)
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	var board_tex = skin_art("merge_board_bg.png")
	if board_tex != null:
		var board_panel = PanelContainer.new()
		board_panel.clip_contents = true
		board_panel.add_theme_stylebox_override("panel", box(Color("0d1a24"), Color("6e6042"), 1, 12, 0))
		content.add_child(board_panel)
		var board_back = TextureRect.new()
		board_back.texture = board_tex
		board_back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		board_back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		board_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		board_panel.add_child(board_back)
		var board_margin = MarginContainer.new()
		for side in ["left", "right", "top", "bottom"]:
			board_margin.add_theme_constant_override("margin_" + side, 8)
		board_panel.add_child(board_margin)
		board_margin.add_child(grid)
	else:
		content.add_child(grid)
	for i in range(g.board.size()):
		var cell = g.board[i]
		var b = Button.new()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		var fill = Color("172530")
		var text = ""
		if cell != null:
			var kind = v.kinds[int(cell.k)]
			var m = pow(1.9, int(cell.t) - 1) * (1.0 + 0.1 * int(g.stars))
			text = "%d·⚔%d ♥%d" % [int(cell.t), int(round(kind.atk * m)), int(round(kind.hp * m))]
			fill = MERGE_COLORS[int(cell.k)]
			var unit_tex = skin_art("unit_%s_%d.png" % [kind.id, (int(cell.t) + 1) / 2])
			if unit_tex != null:
				b.icon = unit_tex
				b.expand_icon = true
				b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
				b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
				b.add_theme_constant_override("icon_max_width", 40)
			else:
				text = "%s\n%s" % [kind.name, text]
		b.text = text
		b.custom_minimum_size = Vector2(0, 100)
		b.add_theme_font_size_override("font_size", 8)
		b.clip_text = true
		var cell_style = merge_cell_style("merge_cell_selected.png" if i == merge_pick else "merge_cell.png", fill)
		b.add_theme_stylebox_override("normal", cell_style)
		b.add_theme_stylebox_override("hover", cell_style)
		b.add_theme_stylebox_override("pressed", merge_cell_style("merge_cell_selected.png", fill.lightened(0.2)))
		b.pressed.connect(func():
			if merge_pick < 0:
				if cell != null:
					merge_pick = i
					render()
			elif merge_pick == i:
				merge_pick = -1
				render()
			else:
				merge_do("merge/move", {"from": merge_pick, "to": i}))
		grid.add_child(b)
	var bar = HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	content.add_child(bar)
	var buy_button = primary_button("Al (%d)" % int(v.buyCost), bar, func(): merge_do("merge/buy"), bool(g.over))
	var buy_icon = skin_art("icon_buy.png")
	if buy_icon != null:
		buy_button.icon = buy_icon
		buy_button.expand_icon = true
		buy_button.add_theme_constant_override("icon_max_width", 26)
	var fight = primary_button("SAVAŞ ›", bar, func(): merge_do("merge/battle"), bool(g.over))
	var fight_icon = skin_art("icon_auto_battle.png")
	if fight_icon != null:
		fight.icon = fight_icon
		fight.expand_icon = true
		fight.add_theme_constant_override("icon_max_width", 28)
	var speed_button = Button.new()
	speed_button.text = "x%d" % merge_speed
	speed_button.custom_minimum_size = Vector2(52, 0)
	var speed_icon = skin_art("icon_speed_%d.png" % merge_speed)
	if speed_icon != null:
		speed_button.icon = speed_icon
		speed_button.expand_icon = true
		speed_button.add_theme_constant_override("icon_max_width", 24)
	speed_button.pressed.connect(func():
		merge_speed = 2 if merge_speed == 1 else 1
		render())
	bar.add_child(speed_button)
	var bar2 = HBoxContainer.new()
	bar2.add_theme_constant_override("separation", 8)
	content.add_child(bar2)
	var sell_button = primary_button("Sat", bar2, func(): merge_do("merge/sell", {"cell": merge_pick}), merge_pick < 0 or bool(g.over))
	var sell_icon = skin_art("icon_sell.png")
	if sell_icon != null:
		sell_button.icon = sell_icon
		sell_button.expand_icon = true
		sell_button.add_theme_constant_override("icon_max_width", 24)
	primary_button("Yeniden doğ" if bool(g.over) else "Yeni koşu", bar2, func(): merge_do("merge/restart"))
	muted_label("Aynı türden ve aynı seviyeden iki birliği üst üste sürükle/dokun: seviye atlar. Her 5 dalga en iyi sonuç +%10 güç yıldızı kazandırır.", content, 12).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func render_story() -> void:
	heading("ANADOLU YOLCULUĞU", content, 26)
	divider_art(content)
	muted_label("Her zafer bir efsanenin kapısını açar. %d / 10 tamamlandı." % chapters_done(), content, 14)
	var grid = GridContainer.new()
	grid.columns = 3 if get_viewport_rect().size.x > 850 else 2 if get_viewport_rect().size.x > 600 else 1
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	content.add_child(grid)
	for chapter in data.chapters:
		var done = account.profile.chapterRewards.has(chapter.id)
		var unlocked = chapter.id == 1 or account.profile.chapterRewards.has(chapter.id - 1)
		var cell = VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.custom_minimum_size.x = maxf(0, (content_width() - 12 - (grid.columns - 1) * 12) / grid.columns)
		grid.add_child(cell)
		var card = feature(cell, [1, 6, 19, 35, 5, 16, 18, 8, 25, 28][int(chapter.id) - 1], str(chapter.title), str(chapter.place), 180, "chapter_%02d.png" % int(chapter.id))
		var chapter_button = primary_button("Tamamlandı" if done else "SAVAŞA GİR" if unlocked else "Kilitli", card, func(): view = "lobby"; mutate("solo", {"chapterId": int(chapter.id)}), not unlocked)
		var state_icon = skin_art("icon_check.png" if done else "icon_lock.png" if not unlocked else "")
		if chapter_button != null and state_icon != null:
			chapter_button.icon = state_icon
			chapter_button.expand_icon = true
			chapter_button.add_theme_constant_override("icon_max_width", 22)

func render_social() -> void:
	clear_content()
	heading("ARKADAŞLA DÜELLO", content, 25)
	divider_art(content)
	var card = feature(content, 2, "Aynı masada buluşun", "Oda oluştur ve kodu arkadaşınla paylaş.", 200, "scene_friends.png")
	primary_button("Oda oluştur", card, func(): view = "lobby"; mutate("rooms", {"deck": deck_payload()}))
	room_code = LineEdit.new()
	room_code.placeholder_text = "8 karakter oda kodu"
	room_code.max_length = 8
	room_code.custom_minimum_size.y = 56
	content.add_child(room_code)
	primary_button("Odaya katıl", content, func(): view = "lobby"; mutate("join", {"code": room_code.text.strip_edges().to_upper(), "deck": deck_payload()}))

func render_profile() -> void:
	clear_content()
	heading("HESABIM", content, 25)
	resource_row(content)
	hero_picker(content)
	if not recovery_key.is_empty():
		button("Anahtarı kopyala", content, func(): DisplayServer.clipboard_set(recovery_key); toast("Kurtarma anahtarı kopyalandı", GOLD))
		button("Kurtarma anahtarını kaydet", content, func(): save_file(recovery_key + "\n", "destan-kurtarma.txt"))
	recover_input = LineEdit.new()
	recover_input.secret = true
	recover_input.placeholder_text = "Hesap kurtarma anahtarı"
	recover_input.custom_minimum_size.y = 56
	content.add_child(recover_input)
	button("Hesabı kurtar", content, recover_account)
	for entry in account.history:
		button("%s · %s" % [entry.kind, entry.result], content, open_match.bind(entry.id))

func render_collection() -> void:
	resource_row(content)
	heading("KART KOLEKSİYONUN", content, 25)
	divider_art(content)
	var pack = feature(content, -1, "Kadim sandık", "Yeni kartlarla desteni güçlendir.", 140, "scene_chest.png")
	if not account.is_empty():
		var free = int(account.profile.freePacks) > 0
		primary_button("SANDIĞI AÇ · ÜCRETSİZ" if free else "SANDIĞI AÇ · 300 ALTIN", pack, func(): mutate("collection/pack", {}, true), not free and int(account.profile.gold) < 300)
	if last_pack.is_empty():
		pack_anim_shown.clear()
	else:
		render_pack_reveal()
	filter_chip_row(content, [["all", "Tümü"], ["warrior", "Savaşçı"], ["spell", "Büyü"], ["trap", "Tuzak"]], collection_filter, func(key): collection_filter = key; render())
	var grid = GridContainer.new()
	grid.columns = maxi(2, int(content_width() / 155))
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	content.add_child(grid)
	var width = minf(160, (content_width() - 12 - (grid.columns - 1) * 12) / grid.columns)
	for id in range(1, 41):
		if not card_visible(id):
			continue
		var amount = int(account.profile.inventory.get(str(id), 0)) if not account.is_empty() else 1
		mini_card(id, grid, width, {}, collection_detail.bind(id), "" if amount else "dim", "×%d" % amount, true)
	if grid.get_child_count() == 0:
		var empty = art_slice(content, "empty_collection.png")
		if empty != null:
			empty.custom_minimum_size = Vector2(minf(300, content_width()), minf(300, content_width()) * 0.667)
		label("Bu türde kart yok. Sandık açarak koleksiyonunu büyüt.", content, 14)

func collection_detail(id: int) -> void:
	var dialog = AcceptDialog.new()
	dialog.title = cards[id].name
	dialog.ok_button_text = "Kapat"
	add_child(dialog)
	var column = VBoxContainer.new()
	dialog.add_child(column)
	mini_card(id, column, 180, {}, Callable(), "", "", true)
	if not account.is_empty():
		var amount = int(account.profile.inventory.get(str(id), 0))
		var cost = {"common": 40, "rare": 100, "legendary": 400}[cards[id].rarity]
		var cap = 1 if cards[id].rarity == "legendary" else 2
		button("Üret · %d toz" % cost, column, func(): dialog.queue_free(); mutate("collection/craft", {"cardId": id}, true), amount >= cap or int(account.profile.dust) < cost)
		button("Parçala", column, func(): dialog.queue_free(); mutate("collection/dismantle", {"cardId": id}, true), amount == 0)
		if account.profile.chapterRewards.has(10) and int(account.profile.archiveLeft) > 0:
			button("Arşivden seç", column, func(): dialog.queue_free(); mutate("collection/archive", {"cardId": id}, true), amount > 0)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered_clamped(Vector2i(260, 440), 0.92)

func mini_card_flat(id: int, parent: Node, width: float, unit: Dictionary = {}, tap: Callable = Callable(), state: String = "", corner: String = "", full: bool = false) -> PanelContainer:
	var info: Dictionary = cards[id]
	var height = width * (1.7 if full else 1.34)
	var rarity_color: Color = RARITY[info.rarity]
	var rim: Color = Color("82e6a9") if state == "ready" else Color("fff0a9") if state == "picked" else rarity_color
	var wrap = PanelContainer.new()
	wrap.custom_minimum_size = Vector2(width, height)
	wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var style = box(Color("1b1611"), rim, 3, 12, 0)
	style.shadow_color = Color(0, 0, 0, 0.65)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 3)
	if state in ["ready", "picked"]:
		style.shadow_color = Color(rim.r, rim.g, rim.b, 0.8)
		style.shadow_size = 10
		style.shadow_offset = Vector2.ZERO
		var glow = wrap.create_tween().set_loops()
		glow.tween_property(style, "shadow_size", 16, 0.7).set_trans(Tween.TRANS_SINE)
		glow.tween_property(style, "shadow_size", 8, 0.7).set_trans(Tween.TRANS_SINE)
	elif info.rarity == "legendary":
		style.shadow_color = Color(1.0, 0.8, 0.3, 0.55)
		style.shadow_size = 9
		style.shadow_offset = Vector2.ZERO
	wrap.add_theme_stylebox_override("panel", style)
	parent.add_child(wrap)
	wrap.set_meta("card_id", id)
	if state in ["dim", "tired"]:
		wrap.modulate = Color(0.62, 0.65, 0.72, 1)
	if not unit.is_empty():
		unit_nodes[int(unit.uid)] = wrap
	var face = Control.new()
	face.custom_minimum_size = Vector2(width, height)
	wrap.add_child(face)
	if state == "picked" and not unit.is_empty():
		var ring = art_slice(face, "target_ring.png")
		if ring != null:
			ring.size = Vector2(width * 1.25, width * 1.25)
			ring.position = Vector2(-width * 0.125, (width * 1.34 - ring.size.y) * 0.5)
			ring.set_meta("skin_asset", "target_ring.png")
			ring.z_index = 3
			ring.pivot_offset = ring.size / 2
			var target_pulse = ring.create_tween().set_loops()
			target_pulse.tween_property(ring, "modulate:a", 0.55, 0.5)
			target_pulse.tween_property(ring, "modulate:a", 1.0, 0.5)
	var on_board = not unit.is_empty()
	var art_height = (height * 0.5 if full else height * 0.6) if not on_board else height - 8
	var art = TextureRect.new()
	art.texture = texture_for(id)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.position = Vector2(5, 5)
	art.size = Vector2(width - 10, art_height)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.clip_contents = true
	face.add_child(art)
	var frame_line = Panel.new()
	frame_line.position = Vector2(4, 4)
	frame_line.size = Vector2(width - 8, art_height + 2)
	frame_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame_line.add_theme_stylebox_override("panel", box(Color(0, 0, 0, 0), Color("e9cf8f"), 2, 7, 0))
	face.add_child(frame_line)
	if not on_board:
		var slab = Panel.new()
		slab.position = Vector2(5, art_height + 7)
		slab.size = Vector2(width - 10, height - art_height - 12)
		slab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slab.add_theme_stylebox_override("panel", box(Color("2a2118"), Color("6e5a38"), 1, 6, 0))
		face.add_child(slab)
		var ribbon = Panel.new()
		ribbon.position = Vector2(8, art_height - 14)
		ribbon.size = Vector2(width - 16, 20)
		ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ribbon.add_theme_stylebox_override("panel", box(Color(0.07, 0.05, 0.03, 0.9), Color("c9a85f"), 1, 6, 0))
		face.add_child(ribbon)
		var nameplate = Label.new()
		nameplate.text = info.name
		nameplate.position = Vector2(10, art_height - 14)
		nameplate.set_deferred("size", Vector2(width - 20, 20))
		nameplate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nameplate.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		nameplate.autowrap_mode = TextServer.AUTOWRAP_OFF
		nameplate.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nameplate.custom_minimum_size = Vector2(0, 20)
		nameplate.clip_text = true
		nameplate.add_theme_font_size_override("font_size", 14 if width > 120 else (11 if width > 70 else 9))
		nameplate.add_theme_color_override("font_color", Color("f3dc9c"))
		nameplate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.add_child(nameplate)
		var gem_dot = Panel.new()
		gem_dot.size = Vector2(12, 12)
		gem_dot.position = Vector2(width / 2 - 6, art_height + 12)
		gem_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gem_dot.add_theme_stylebox_override("panel", box(rarity_color, Color("fff3cf"), 1, 6, 0))
		face.add_child(gem_dot)
	if full:
		var kind = Label.new()
		kind.text = "%s · %s" % [TYPE_NAME[info.type], RARITY_NAME[info.rarity]]
		kind.position = Vector2(8, art_height + 22)
		kind.size = Vector2(width - 16, 16)
		kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		kind.add_theme_font_size_override("font_size", 11)
		kind.add_theme_color_override("font_color", rarity_color)
		kind.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.add_child(kind)
		var effect = Label.new()
		effect.text = info.text
		effect.position = Vector2(10, art_height + 40)
		effect.custom_minimum_size = Vector2(width - 20, 0)
		effect.set_deferred("size", Vector2(width - 20, maxf(20, height - art_height - 80)))
		effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		effect.add_theme_font_size_override("font_size", 12)
		effect.add_theme_color_override("font_color", Color("ead9b0"))
		effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.add_child(effect)
	cost_gem(face, str(int(info.cost)), Vector2(-5, -5), 30 if width > 90 else 26)
	if info.type == "warrior":
		badge(face, str(unit_attack(unit) if not unit.is_empty() else int(info.attack)), Vector2(-4, height - 27), Color("b8861f"), 28)
		var hp_now = int(unit.get("hp", info.hp))
		badge(face, str(hp_now), Vector2(width - 24, height - 27), Color("b53a3a") if hp_now >= int(unit.get("maxHp", info.hp)) else Color("e06a2c"), 28)
	else:
		var mark = label("BÜYÜ" if info.type == "spell" else "TUZAK", face, 10 if width < 120 else 13)
		mark.autowrap_mode = TextServer.AUTOWRAP_OFF
		mark.position = Vector2(width / 2 - (14 if width < 120 else 20), height - 22)
		mark.add_theme_color_override("font_color", Color("8fe0e8") if info.type == "spell" else Color("c1a8ff"))
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if corner != "":
		badge(face, corner, Vector2(width - 29, 3), Color("243a35"), 25)
	if tap.is_valid():
		var overlay = Button.new()
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		overlay.set_meta("card_overlay", true)
		overlay.tooltip_text = "%s · %s" % [info.name, info.text]
		for key in ["normal", "hover", "pressed", "focus"]:
			overlay.add_theme_stylebox_override(key, StyleBoxEmpty.new())
		overlay.pressed.connect(func():
			if Time.get_ticks_msec() >= suppress_card_tap_until:
				tap.call())
		wrap.add_child(overlay)
	return wrap

func cost_gem(parent: Node, text: String, position: Vector2, size: float) -> Control:
	var holder = Control.new()
	holder.position = position
	holder.size = Vector2(size, size)
	holder.custom_minimum_size = Vector2(size, size)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(holder)
	var diamond = Panel.new()
	diamond.size = Vector2(size * 0.72, size * 0.72)
	diamond.position = Vector2(size * 0.14, size * 0.14)
	diamond.pivot_offset = diamond.size / 2
	diamond.rotation = PI / 4
	diamond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gem_style = box(Color("2a77c4"), Color("f5e1a8"), 2, 4, 0)
	gem_style.shadow_color = Color(0.2, 0.5, 1.0, 0.6)
	gem_style.shadow_size = 5
	diamond.add_theme_stylebox_override("panel", gem_style)
	holder.add_child(diamond)
	var number = Label.new()
	number.text = text
	number.size = Vector2(size, size)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	number.add_theme_font_size_override("font_size", int(size * 0.55))
	number.add_theme_color_override("font_color", Color("ffffff"))
	number.add_theme_color_override("font_outline_color", Color("0a2a50"))
	number.add_theme_constant_override("outline_size", 4)
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(number)
	return holder

func badge(parent: Node, text: String, position: Vector2, color: Color, diameter: float) -> PanelContainer:
	var holder = PanelContainer.new()
	holder.position = position
	holder.custom_minimum_size = Vector2(diameter, diameter)
	var badge_style = box(color, Color("f5db9c"), 2, int(diameter / 2), 0)
	badge_style.shadow_color = Color(0, 0, 0, 0.55)
	badge_style.shadow_size = 3
	badge_style.shadow_offset = Vector2(0, 2)
	holder.add_theme_stylebox_override("panel", badge_style)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(holder)
	var number = label(text, holder, 17 if diameter > 24 else 13)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	number.add_theme_color_override("font_color", Color("ffffff"))
	number.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	number.add_theme_constant_override("outline_size", 4)
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return holder

func hero_flat(parent: Control, index: int, player: Dictionary, at: Vector2, diameter: float) -> void:
	var frame = PanelContainer.new()
	frame.position = at
	frame.custom_minimum_size = Vector2(diameter, diameter)
	frame.clip_contents = true
	var ring = box(Color("2a2523"), Color("e3bf6c"), 4, 18, 4)
	ring.shadow_color = Color(0.9, 0.7, 0.25, 0.55)
	ring.shadow_size = 9
	frame.add_theme_stylebox_override("panel", ring)
	parent.add_child(frame)
	picture(texture_for(25 if index == 0 else 28), frame)
	hero_nodes[index] = frame
	badge(parent, str(int(player.hp)), at + Vector2(diameter - 22, diameter - 25), Color("b53a3a") if int(player.hp) > 8 else Color("e0301f"), 32)
	var target = selected.filter(func(action): return str(action.get("target", "")) == "hero:" + str(index))
	var hit = Button.new()
	hit.position = at
	hit.size = Vector2(diameter, diameter)
	hit.add_theme_stylebox_override("normal", box(Color.TRANSPARENT, Color("82e6a9") if not target.is_empty() else Color.TRANSPARENT, 3 if not target.is_empty() else 0, 16, 0))
	for key in ["hover", "pressed"]:
		hit.add_theme_stylebox_override(key, box(Color(1, 1, 1, 0.12), GOLD, 2, 16, 0))
	hit.pressed.connect(func():
		if not target.is_empty():
			move(target[0]))
	parent.add_child(hit)

func battlefield_lane(units: Array, own: bool, legal: Array, area: Rect2, card_width: float) -> void:
	var gap = 6.0
	var total = units.size() * card_width + maxi(0, units.size() - 1) * gap
	var start = area.position.x + (area.size.x - total) / 2
	for index in units.size():
		var unit: Dictionary = units[index]
		var uid = int(unit.uid)
		var options = legal.filter(func(action): return action.type == "attack" and int(action.uid) == uid)
		var hits = selected.filter(func(action): return str(action.get("target", "")) == "unit:" + str(uid))
		var card = mini_card(int(unit.id), arena, card_width, unit, func():
			if not hits.is_empty():
				move(hits[0])
			elif own and not options.is_empty():
				focus = {"id": int(unit.id), "unit": unit}
				selected = options
				render()
			else:
				inspect_card(int(unit.id), unit), "picked" if not hits.is_empty() else "ready" if own and not options.is_empty() else "tired" if own else "")
		card.position = Vector2(start + index * (card_width + gap), area.position.y + maxf(0, (area.size.y - card_width * 1.34) / 2))
		if own and not options.is_empty():
			install_drag(card, options)

func compact_portrait_button(node: Button) -> void:
	# Dikey maçta düğme kahraman portresinin yanında kalır; kenar boşlukları daraltılır.
	var tight = StyleBoxEmpty.new()
	tight.content_margin_left = 20
	tight.content_margin_right = 12
	tight.content_margin_top = 8
	tight.content_margin_bottom = 8
	for key in ["normal", "hover", "pressed", "disabled", "focus"]:
		node.add_theme_stylebox_override(key, tight)
	node.add_theme_font_size_override("font_size", 11)
	node.alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.clip_text = false
	node.custom_minimum_size = Vector2(0, 42)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func render_match() -> void:
	if room.get("state") == null:
		render_waiting_room()
		return
	var state: Dictionary = room.state
	var legal: Array = room.get("actions", [])
	var mine: Dictionary = state.players[0]
	var foe: Dictionary = state.players[1]
	var width = content_width()
	var height = maxf(250, get_viewport_rect().size.y - shell_margin.get_theme_constant("margin_top") - shell_margin.get_theme_constant("margin_bottom") - 50)
	var landscape = width > 600
	arena = Control.new()
	arena.custom_minimum_size = Vector2(0, height)
	arena.clip_contents = true
	content.add_child(arena)
	var table_art = skin_art("background_land.png" if landscape else "background.png")
	if table_art != null:
		table_bg = Control.new()
		table_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		table_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(table_bg)
		move_child(table_bg, 1)
		picture(table_art, table_bg)
		var dim = ColorRect.new()
		dim.color = Color(0, 0, 0, 0.18)
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		table_bg.add_child(dim)
	else:
		picture(load("res://native/mobile-assets/table.svg"), arena)
	atmosphere(width, height)
	# Yatay düzen: solda kahramanlar/deste, ortada iki şerit + el, sağda kontroller.
	var side = 112.0 if landscape else 0.0
	var right_col = 190.0 if landscape else 0.0
	var play_x = side if landscape else width * 0.05
	var play_w = (width - side - right_col) if landscape else width * 0.9
	var portrait_size = 58.0 if landscape else clampf(height * 0.14, 40, 92)
	var hand_width = clampf(height * 0.2, 56, 68) if landscape else clampf(height * 0.22, 56, 96)
	if not landscape:
		# Elde 5+ kart varsa hepsi ekrana sığsın (yatay kaydırma gerekmesin).
		var hand_count = maxi(1, mine.hand.size())
		hand_width = minf(hand_width, maxf(46.0, (width - 16.0 - 4.0 * (hand_count - 1)) / hand_count))
	var hand_height = hand_width * 1.34 + 6
	var hand_top = height - hand_height
	var foe_hero_at = Vector2((side - portrait_size) / 2, 8) if landscape else Vector2((width - portrait_size) / 2, 2)
	hero(arena, 1, foe, foe_hero_at, portrait_size)
	var own_hero_y = (height - portrait_size - 12) if landscape else (hand_top - portrait_size - 4)
	hero(arena, 0, mine, Vector2((side - portrait_size) / 2, own_hero_y) if landscape else Vector2((width - portrait_size) / 2, own_hero_y), portrait_size)
	var lane_count = maxi(4, maxi(foe.board.size(), mine.board.size()))
	var lanes_top = 36.0 if landscape else portrait_size + 4
	var lane_height = ((hand_top - 4 - lanes_top - 2) / 2) if landscape else (own_hero_y - portrait_size - 8) / 2
	var card_width = minf(clampf((lane_height - 14) / 1.34, 40, 84), (play_w - 12 - 6.0 * (lane_count - 1)) / lane_count) if landscape else minf(88, (width * 0.9 - 6.0 * (lane_count - 1)) / lane_count)
	for lane_index in 2:
		var strip = Panel.new()
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lane_style = box(Color(0.35, 0.05, 0.05, 0.3) if lane_index == 0 else Color(0.05, 0.03, 0.01, 0.3), Color(0.95, 0.78, 0.4, 0.75), 2, 14, 0)
		lane_style.shadow_color = Color(0, 0, 0, 0.45)
		lane_style.shadow_size = 8
		strip.add_theme_stylebox_override("panel", lane_style)
		arena.add_child(strip)
		strip.position = Vector2(play_x - 4, lanes_top + lane_index * (lane_height + 2))
		strip.size = Vector2(play_w + 8, lane_height)
		var lane_art = art_slice(strip, "lane_enemy.png" if lane_index == 0 else "lane.png", Rect2(), "h3", Vector4(246, 0, 246, 0))
		if lane_art != null:
			lane_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			lane_art.modulate = Color(1, 1, 1, 0.92)
			strip.add_theme_stylebox_override("panel", box(Color(0, 0, 0, 0.0), Color(0, 0, 0, 0), 0, 14, 0))
	battlefield_lane(foe.board, false, legal, Rect2(play_x, lanes_top, play_w, lane_height), card_width)
	battlefield_lane(mine.board, true, legal, Rect2(play_x, lanes_top + lane_height + 2, play_w, lane_height), card_width)
	var foe_back = HBoxContainer.new()
	foe_back.add_theme_constant_override("separation", -9)
	foe_back.position = Vector2(play_x if landscape else width * 0.1, 3 if landscape else 5)
	arena.add_child(foe_back)
	for index in mini(foe.hand.size(), 7):
		var back = art_slice(foe_back, "card_back.png", Rect2(26, 6, 460, 668))
		if back != null:
			back.custom_minimum_size = Vector2(22, 32) if landscape else Vector2(26, 38)
		else:
			back = PanelContainer.new()
			back.custom_minimum_size = Vector2(23, 32)
			back.add_theme_stylebox_override("panel", box(Color("21464c"), GOLD, 2, 4, 0))
			foe_back.add_child(back)
	var turn = label("TUR %d" % ceili(float(state.turn) / 2), arena, 12)
	turn.autowrap_mode = TextServer.AUTOWRAP_OFF
	turn.position = Vector2(14, 76) if landscape else Vector2(12, height * 0.34)
	small_icon(arena, "icon_turn.png", turn.position + Vector2(0, -22), 20)
	turn.add_theme_color_override("font_color", Color("f1dfb7"))
	turn_clock = label("", arena, 11)
	turn_clock.autowrap_mode = TextServer.AUTOWRAP_OFF
	turn_clock.position = Vector2(14, 94) if landscape else Vector2(12, height * 0.4)
	var hand_scroll = ScrollContainer.new()
	hand_scroll.position = Vector2(play_x if landscape else 0, height - hand_height)
	hand_scroll.size = Vector2(play_w if landscape else width, hand_height)
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	arena.add_child(hand_scroll)
	var hand = HBoxContainer.new()
	hand.alignment = BoxContainer.ALIGNMENT_CENTER
	hand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand.add_theme_constant_override("separation", 4)
	hand_scroll.add_child(hand)
	var mulligan = state.status == "mulligan" and state.active == 0
	for index in mine.hand.size():
		var id = int(mine.hand[index])
		var options = legal.filter(func(action): return action.type == "play" and int(action.index) == index)
		var change = mulligan and not mine.mulliganPinned.has(id)
		var picked = mulligan_indices.has(index) or int(focus.get("hand_index", -1)) == index
		var card = mini_card(id, hand, hand_width, {}, func():
			if change:
				if mulligan_indices.has(index):
					mulligan_indices.erase(index)
				else:
					mulligan_indices.append(index)
				render()
			else:
				focus = {"id": id, "hand_index": index}
				selected = options
				render(), "picked" if picked else "ready" if change or not options.is_empty() else "dim", "✓" if mulligan_indices.has(index) else "")
		card.set_meta("hand_index", index)
		if not options.is_empty():
			install_drag(card, options)
	var controls = VBoxContainer.new()
	var controls_x = width * 0.5 + portrait_size * 0.5 + 6.0
	controls.position = Vector2(width - 186, height - 142) if landscape else Vector2(controls_x, own_hero_y + portrait_size * 0.12)
	controls.size = Vector2(180, 0) if landscape else Vector2(width - controls_x - 8.0, 0)
	arena.add_child(controls)
	if state.status == "finished":
		pass
	elif state.active == 0:
		if mulligan:
			var start_button = primary_button("Başla", controls, func(): move({"type": "mulligan", "indices": mulligan_indices.duplicate()}))
			if not landscape:
				compact_portrait_button(start_button)
		else:
			for action in legal:
				if action.type == "end":
					var end_button = primary_button("Turu bitir", controls, func(): move(action))
					if not landscape:
						compact_portrait_button(end_button)
				elif action.type in ["scry", "discard"]:
					small_button(action_name(action), controls, func(): move(action))
	else:
		var waiting = art_slice(controls, "end_turn_wait.png", END_TURN_REGION, "h3", Vector4(150, 0, 150, 0))
		if waiting != null:
			waiting.custom_minimum_size = Vector2(170, 62)
			waiting.set_meta("skin_asset", "end_turn_wait.png")
			var wait_text = label("Rakibin turu", waiting, 14)
			wait_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			wait_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			wait_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			wait_text.add_theme_color_override("font_color", Color("d9c9a0"))
			if portrait_font != null:
				wait_text.add_theme_font_override("font", portrait_font)
		else:
			muted_label("Rakibin turu", controls, 14)
	if landscape and state.status != "finished":
		for depth in range(3):
			var deck = art_slice(arena, "card_back.png", Rect2(26, 6, 460, 668))
			if deck != null:
				deck.position = Vector2(34 + depth * 3, own_hero_y - 66 + depth * 3)
				deck.size = Vector2(34, 49)
			else:
				deck = PanelContainer.new()
				deck.position = Vector2(34 + depth * 3, own_hero_y - 66 + depth * 3)
				deck.custom_minimum_size = Vector2(34, 47)
				deck.add_theme_stylebox_override("panel", box(Color("1e3d43"), Color("bda775"), 2, 4, 2))
				arena.add_child(deck)
				var mark = label("D", deck, 18)
				mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var deck_count = label(str(mine.deck.size()), arena, 12)
		deck_count.autowrap_mode = TextServer.AUTOWRAP_OFF
		deck_count.position = Vector2(46, own_hero_y - 66 + 54)
		small_icon(arena, "icon_deck_count.png", deck_count.position + Vector2(-18, -2), 16)
	for child in controls.get_children():
		if child is Button:
			child.custom_minimum_size.x = minf(child.custom_minimum_size.x, 180)
	var max_energy = maxi(int(mine.maxEnergy), 1)
	if skin_art("icon_energy_full.png") != null:
		var crystal_row = HBoxContainer.new()
		crystal_row.add_theme_constant_override("separation", -2)
		var crystal_size = 24.0 if landscape else minf(24.0, 120.0 / max_energy)
		crystal_row.position = Vector2(width - 14 - 22.0 * max_energy, height - 62) if landscape else Vector2(14, own_hero_y + portrait_size * 0.2)
		arena.add_child(crystal_row)
		for crystal_index in max_energy:
			var full = crystal_index < int(mine.energy)
			var crystal = art_slice(crystal_row, "icon_energy_full.png" if full else "icon_energy_empty.png")
			crystal.custom_minimum_size = Vector2(crystal_size, crystal_size)
	else:
		var crystals = label("◆".repeat(int(mine.energy)) + "◇".repeat(maxi(0, int(mine.maxEnergy) - int(mine.energy))), arena, 18)
		crystals.autowrap_mode = TextServer.AUTOWRAP_OFF
		crystals.position = Vector2(width - 40 - 15 * maxi(int(mine.maxEnergy), 1), height - 56)
		crystals.add_theme_color_override("font_color", Color("6cc3ff"))
		crystals.add_theme_color_override("font_outline_color", Color(0, 0.1, 0.25, 0.9))
		crystals.add_theme_constant_override("outline_size", 3)
	var energy = label("%d/%d ENERJİ" % [int(mine.energy), int(mine.maxEnergy)], arena, 13)
	energy.autowrap_mode = TextServer.AUTOWRAP_OFF
	energy.position = Vector2(width - 100, height - 31) if landscape else Vector2(14, own_hero_y + portrait_size * 0.2 + 28)
	energy.add_theme_color_override("font_color", Color("8aceff"))
	if not focus.is_empty():
		var info: Dictionary = cards[int(focus.id)]
		var details = VBoxContainer.new()
		details.position = Vector2(width - 186, 56) if landscape else Vector2(12, 45)
		details.size = Vector2(180, 0) if landscape else Vector2(minf(155, width * 0.25), 0)
		arena.add_child(details)
		label(info.name, details, 13)
		if landscape:
			muted_label(info.text, details, 11)
		for action in selected:
			if not str(action.get("target", "")).begins_with("unit:") and not str(action.get("target", "")).begins_with("hero:"):
				small_button(action_name(action), details, func(): move(action))
		if not selected.is_empty():
			small_button("İptal", details, func(): selected = []; focus = {}; render())
	var exit = small_button("‹", arena, confirm_leave)
	exit.position = Vector2(width - 52, 4)
	exit.custom_minimum_size = Vector2(48, 48)
	if skin_art("icon_back.png") != null:
		exit.text = ""
		exit.icon = skin_art("icon_back.png")
		exit.expand_icon = true
		for key in ["normal", "hover", "pressed", "focus"]:
			exit.add_theme_stylebox_override(key, StyleBoxEmpty.new())
	if state.status == "finished":
		render_result(state, width, height)
	run_effects(state)

func install_drag(card: Control, options: Array) -> void:
	card.set_meta("drag_actions", options)
	var overlay = card.get_child(card.get_child_count() - 1)
	overlay.gui_input.connect(func(event):
		if touch_index < 0 and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			begin_gesture(card, options, overlay.get_global_rect().position + event.position))

func draggable_at(node: Node, position: Vector2) -> Control:
	if node is Control and not node.is_visible_in_tree():
		return null
	if node is ScrollContainer and not node.get_global_rect().has_point(position):
		return null
	if node.has_meta("drag_actions") and node.get_global_rect().has_point(position):
		return node
	var children = node.get_children()
	children.reverse()
	for child in children:
		var found = draggable_at(child, position)
		if found != null:
			return found
	return null

func begin_gesture(card: Control, options: Array, position: Vector2) -> void:
	drag_origin = position
	pointer = position
	drag_options = options.duplicate()
	drag_card = card

func update_gesture(position: Vector2) -> void:
	if not is_instance_valid(drag_card) or drag_options.is_empty():
		return
	pointer = position
	if pointer.distance_to(drag_origin) < 14 and not drag_active:
		return
	if not drag_active and drag_options[0].type == "play":
		drag_preview = mini_card(int(drag_card.get_meta("card_id")), self, 82, {}, Callable(), "ready")
		drag_preview.z_index = 100
		drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(drag_preview):
		drag_preview.position = pointer - Vector2(41, 50)
	drag_active = true
	selected = drag_options.duplicate()
	queue_redraw()

func cancel_gesture() -> void:
	drag_active = false
	touch_index = -1
	drag_card = null
	drag_options = []
	if is_instance_valid(drag_preview):
		drag_preview.queue_free()
		drag_preview = null
	queue_redraw()

func finish_gesture(position: Vector2, canceled: bool = false) -> void:
	var options = drag_options.duplicate()
	var origin = drag_origin
	var was_dragging = drag_active
	cancel_gesture()
	if not was_dragging:
		return
	suppress_card_tap_until = Time.get_ticks_msec() + 200
	get_viewport().set_input_as_handled()
	if not canceled:
		for action in options:
			var target = str(action.get("target", ""))
			var node: Control
			if target.begins_with("hero:"):
				node = hero_nodes.get(int(target.trim_prefix("hero:")))
			elif target.begins_with("unit:"):
				node = unit_nodes.get(int(target.trim_prefix("unit:")))
			if is_instance_valid(node) and node.get_global_rect().grow(12).has_point(position):
				move(action)
				return
			if target == "" and is_instance_valid(arena) and arena.get_global_rect().has_point(position) and position.y < origin.y - 25:
				move(action)
				return
	selected = []
	focus = {}
	render()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if touch_index >= 0:
				get_viewport().set_input_as_handled()
				return
			if is_instance_valid(arena):
				var card = draggable_at(arena, event.position)
				if card != null:
					touch_index = event.index
					begin_gesture(card, card.get_meta("drag_actions"), event.position)
		elif event.index == touch_index:
			finish_gesture(event.position, event.canceled)
		return
	if event is InputEventScreenDrag:
		if event.index == touch_index:
			update_gesture(event.position)
			if drag_active:
				get_viewport().set_input_as_handled()
		return
	if touch_index >= 0:
		return
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		update_gesture(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		finish_gesture(event.position)

func _draw() -> void:
	if drag_active:
		var arrow = skin_art("drag_arrow.png")
		if arrow != null and pointer.distance_to(drag_origin) > 40:
			var direction = (pointer - drag_origin)
			draw_line(drag_origin, pointer - direction.normalized() * 30, Color(1.0, 0.89, 0.6, 0.55), 5, true)
			draw_set_transform(pointer, direction.angle() + PI / 2, Vector2.ONE)
			draw_texture_rect_region(arrow, Rect2(-34, -50, 68, 68), Rect2(0, 0, 256, 256))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_line(drag_origin, pointer, Color("ffe299"), 4, true)
			draw_circle(pointer, 9, Color("ffe299"), false, 3, true)

func toast(text: String, color: Color) -> void:
	if is_instance_valid(feedback):
		feedback.queue_free()
	var holder = PanelContainer.new()
	holder.custom_minimum_size = Vector2(minf(320, get_viewport_rect().size.x - 40), 48)
	holder.position = Vector2((get_viewport_rect().size.x - holder.custom_minimum_size.x) / 2, 60)
	holder.add_theme_stylebox_override("panel", box(Color("15232c"), color, 1, 12, 10))
	holder.z_index = 120
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	feedback = holder
	var text_node = label(text, holder, 16)
	text_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_node.add_theme_color_override("font_color", color)
	text_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tween = create_tween()
	tween.tween_interval(0.8)
	tween.tween_property(holder, "modulate:a", 0.0, 0.25)
	tween.tween_callback(holder.queue_free)

func atmosphere(width: float, height: float) -> void:
	var vignette = GradientTexture2D.new()
	vignette.fill = GradientTexture2D.FILL_RADIAL
	vignette.fill_from = Vector2(0.5, 0.5)
	vignette.fill_to = Vector2(1.0, 0.85)
	vignette.gradient = Gradient.new()
	vignette.gradient.set_color(0, Color(0, 0, 0, 0))
	vignette.gradient.set_color(1, Color(0.02, 0.01, 0.0, 0.68))
	vignette.gradient.add_point(0.55, Color(0, 0, 0, 0.05))
	picture(vignette, arena)
	var center_art = art_slice(arena, "table_center.png")
	if center_art != null:
		var diameter = minf(width * 0.35, height * 0.5)
		center_art.size = Vector2(diameter, diameter)
		center_art.position = Vector2((width - diameter) * 0.5, (height - diameter) * 0.5)
		center_art.modulate.a = 0.22
		center_art.set_meta("skin_asset", "table_center.png")
	var dust = CPUParticles2D.new()
	dust.position = Vector2(width / 2, height / 2)
	dust.amount = 22
	dust.lifetime = 8.0
	dust.preprocess = 8.0
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(width / 2, height / 2)
	dust.direction = Vector2(0.3, -1)
	dust.spread = 40
	dust.gravity = Vector2.ZERO
	dust.initial_velocity_min = 5
	dust.initial_velocity_max = 14
	dust.scale_amount_min = 1.0
	dust.scale_amount_max = 2.6
	dust.color = Color(1.0, 0.85, 0.5, 0.35)
	dust.z_index = 1
	arena.add_child(dust)

func burst(center: Vector2, color: Color, amount: int = 16, speed: float = 150.0) -> void:
	var sparks = CPUParticles2D.new()
	sparks.one_shot = true
	sparks.emitting = true
	sparks.amount = amount
	sparks.lifetime = 0.6
	sparks.explosiveness = 1.0
	sparks.direction = Vector2(0, -1)
	sparks.spread = 180
	sparks.initial_velocity_min = speed * 0.4
	sparks.initial_velocity_max = speed
	sparks.gravity = Vector2(0, 260)
	sparks.scale_amount_min = 2.0
	sparks.scale_amount_max = 4.5
	sparks.color = color
	sparks.z_index = 130
	add_child(sparks)
	sparks.global_position = center
	get_tree().create_timer(1.0).timeout.connect(sparks.queue_free)

func shake(strength: float = 6.0) -> void:
	var tween = create_tween()
	for step in 5:
		tween.tween_property(self, "position", Vector2(randf_range(-strength, strength), randf_range(-strength, strength)) * (1.0 - step / 5.0), 0.04)
	tween.tween_property(self, "position", Vector2.ZERO, 0.04)

func fx_sprite(file: String, center: Vector2, size: float, life: float = 0.5, additive: bool = false) -> void:
	var tex = skin_art(file)
	if tex == null:
		return
	var node = TextureRect.new()
	node.texture = tex
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.size = Vector2(size, size)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.z_index = 110
	if additive:
		var material = CanvasItemMaterial.new()
		material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		node.material = material
	add_child(node)
	node.global_position = center - node.size / 2
	node.pivot_offset = node.size / 2
	node.scale = Vector2(0.45, 0.45)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(node, "scale", Vector2(1.2, 1.2), life).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "modulate:a", 0.0, life * 0.7).set_delay(life * 0.3)
	tween.chain().tween_callback(node.queue_free)

const SPELL_ART = {28: "fx_slash.png", 29: "fx_heal.png", 30: "fx_spark.png", 31: "fx_shield.png", 32: "fx_spark.png", 33: "fx_frost.png", 34: "fx_flood.png", 35: "fx_fire.png"}

func spell_effect(card_id: int, target: String) -> void:
	if not SPELL_ART.has(card_id) or not is_instance_valid(arena):
		return
	var targets: Array = []
	if target.begins_with("hero:"):
		targets.append(hero_nodes.get(int(target.trim_prefix("hero:"))))
	elif target.begins_with("unit:"):
		targets.append(unit_nodes.get(int(target.trim_prefix("unit:"))))
	elif card_id in [33, 34, 35]:
		for player_index in 2:
			for unit in room.state.players[player_index].board:
				if card_id == 34 or (card_id == 33 and player_index == 1) or (card_id == 35 and player_index == 0):
					targets.append(unit_nodes.get(int(unit.uid)))
	if targets.is_empty():
		targets.append(arena)
	for target_node in targets:
		if is_instance_valid(target_node):
			fx_sprite(SPELL_ART[card_id], target_node.get_global_rect().get_center(), minf(180, target_node.size.x * 1.8), 0.7, true)
	play_sound("spell")

func float_text(target: Control, text: String, color: Color) -> void:
	if not is_instance_valid(target):
		return
	var holder = Control.new()
	holder.size = Vector2(60, 44)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.z_index = 130
	add_child(holder)
	holder.global_position = target.get_global_rect().get_center() - holder.size / 2
	var backdrop = art_slice(holder, "fx_number_bg.png")
	if backdrop != null:
		backdrop.size = holder.size
	var number = label(text, holder, 24)
	number.size = holder.size
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.add_theme_color_override("font_color", color)
	outlined(number, Color.BLACK, 3)
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tween = holder.create_tween().set_parallel(true)
	tween.tween_property(holder, "position:y", holder.position.y - 48, 0.8)
	tween.tween_property(holder, "modulate:a", 0.0, 0.5).set_delay(0.3)
	tween.chain().tween_callback(holder.queue_free)

func run_effects(state: Dictionary) -> void:
	var current = {"id": str(room.get("id", "")), "hero": [int(state.players[0].hp), int(state.players[1].hp)], "units": {}, "turn": int(state.turn), "status": str(state.status)}
	for player in state.players:
		for unit in player.board:
			current.units[int(unit.uid)] = {"hp": int(unit.hp), "name": str(cards[int(unit.id)].name), "rect": Rect2()}
	var old = prev_state
	prev_state = current
	var attack = last_attack
	last_attack = {}
	var visual_play = last_visual_play
	last_visual_play = {}
	if old.is_empty() or old.id != current.id:
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(arena) or room.get("id", "") != current.id:
		return
	for uid in current.units:
		if unit_nodes.has(uid) and is_instance_valid(unit_nodes[uid]):
			current.units[uid].rect = unit_nodes[uid].get_global_rect()
	if not visual_play.is_empty() and int(room.version) > int(visual_play.version):
		spell_effect(int(visual_play.cardId), str(visual_play.target))
	var big_hit = false
	for index in 2:
		var delta = current.hero[index] - old.hero[index]
		if delta != 0 and hero_nodes.has(index):
			float_text(hero_nodes[index], str(delta), Color("ff7567") if delta < 0 else Color("90e6af"))
			flash(hero_nodes[index], Color(1.5, 0.6, 0.5) if delta < 0 else Color(0.6, 1.5, 0.8))
			burst(hero_nodes[index].get_global_rect().get_center(), Color("ff5a4a") if delta < 0 else Color("7dffb0"), 22)
			fx_sprite("fx_hit.png" if delta < 0 else "fx_heal.png", hero_nodes[index].get_global_rect().get_center(), 150, 0.5, delta > 0)
			if delta > 0:
				fx_sprite("fx_spark.png", hero_nodes[index].get_global_rect().get_center(), 120, 0.6, true)
			big_hit = big_hit or delta <= -3
	for uid in current.units:
		var node = unit_nodes.get(uid)
		if not is_instance_valid(node):
			continue
		if not old.units.has(uid):
			pop(node)
			burst(node.get_global_rect().get_center(), Color("ffd479"), 14, 120.0)
			fx_sprite("fx_summon.png", node.get_global_rect().get_center(), node.size.x * 2.1, 0.6, true)
			fx_sprite("fx_dust.png", node.get_global_rect().get_center() + Vector2(0, node.size.y * 0.35), node.size.x * 1.6, 0.5)
		elif current.units[uid].hp != old.units[uid].hp:
			var change = current.units[uid].hp - old.units[uid].hp
			float_text(node, ("+%d" if change > 0 else "%d") % change, Color("ff7567") if change < 0 else Color("90e6af"))
			flash(node, Color(1.6, 0.55, 0.5) if change < 0 else Color(0.6, 1.5, 0.8))
			burst(node.get_global_rect().get_center(), Color("ff6b5a") if change < 0 else Color("7dffb0"), 10, 110.0)
			fx_sprite("fx_hit.png" if change < 0 else "fx_heal.png", node.get_global_rect().get_center(), node.size.x * 1.7, 0.45, change > 0)
	for uid in old.units:
		if not current.units.has(uid) and old.units[uid].rect.size.x > 0:
			ghost(old.units[uid].rect, old.units[uid].name)
			burst(old.units[uid].rect.get_center(), Color("c9c0b0"), 26, 190.0)
			fx_sprite("fx_death.png", old.units[uid].rect.get_center(), old.units[uid].rect.size.x * 2.2, 0.7)
			big_hit = true
	if not attack.is_empty() and unit_nodes.has(int(attack.uid)):
		pulse(unit_nodes[int(attack.uid)])
		fx_sprite("fx_slash.png", unit_nodes[int(attack.uid)].get_global_rect().get_center(), unit_nodes[int(attack.uid)].size.x * 1.9, 0.35, true)
	if big_hit:
		shake(7.0)
		play_sound("hit")
	if current.status == "finished" and old.status != "finished":
		play_sound("win" if state.winner == 0 else "lose")
	elif current.turn != old.turn and state.active == 0:
		banner_toast("SENİN TURUN", GOLD)
		play_sound("turn")

func _process(_delta: float) -> void:
	if is_instance_valid(turn_clock) and not room.is_empty() and room.get("state") != null:
		if room.get("deadline") == null or room.status == "finished":
			turn_clock.text = "Süresiz"
		else:
			var left = maxi(0, ceili((float(room.deadline) - server_offset - Time.get_unix_time_from_system() * 1000) / 1000))
			turn_clock.text = "%d sn" % left

# ---------------------------------------------------------------------------
# Görsel paket (native/skin/*.png) ile çizim
# ---------------------------------------------------------------------------
const FRAMES = {
	"warrior": {"file": "frame_unit.png", "bbox": Rect2(20, 27, 472, 626), "win": Rect2(60, 69, 394, 384)},
	"spell": {"file": "frame_spell.png", "bbox": Rect2(20, 27, 472, 626), "win": Rect2(60, 69, 394, 384)},
	"trap": {"file": "frame_trap.png", "bbox": Rect2(20, 27, 472, 626), "win": Rect2(54, 77, 404, 372)},
	"legend": {"file": "frame_legend.png", "bbox": Rect2(20, 25, 472, 628), "win": Rect2(70, 73, 372, 382)},
}
const BUTTON_REGION = Rect2(25, 8, 551, 162)
const BUTTON_CAP = 110.0
const END_TURN_REGION = Rect2(29, 34, 643, 189)
const CHIP_FILTER_REGION = Rect2(16, 4, 267, 91)
const CHIP_FILTER_ACTIVE_REGION = Rect2(24, 4, 250, 91)
var art_cache: Dictionary = {}
var font_cache: Dictionary = {}

func skin_font(file: String, weight: int) -> Font:
	var key = "%s:%d" % [file, weight]
	if font_cache.has(key):
		return font_cache[key]
	var result: Font = null
	if ResourceLoader.exists(skin_dir + file):
		var variation = FontVariation.new()
		variation.base_font = load(skin_dir + file)
		var tag = TextServerManager.get_primary_interface().name_to_tag("wght")
		variation.variation_opentype = {tag: weight}
		result = variation
	font_cache[key] = result
	return result

func skin_texture_font() -> Font:
	var body = skin_font("font.ttf", 600)
	return body if body != null else super.skin_texture_font()
var number_font: Font

func small_icon(parent: Node, file: String, position: Vector2, size: float) -> TextureRect:
	var texture = skin_art(file)
	if texture == null:
		return null
	var icon = TextureRect.new()
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = position
	icon.size = Vector2(size, size)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)
	return icon

func skin_art(file: String) -> Texture2D:
	if art_cache.has(file):
		return art_cache[file]
	var result: Texture2D = null
	var source = skin_texture(file)
	if source != null:
		var image = source.get_image()
		if image != null:
			if file.begins_with("background"):
				var smooth = image.duplicate()
				smooth.resize(maxi(1, int(image.get_width() / 3.0)), maxi(1, int(image.get_height() / 3.0)), Image.INTERPOLATE_LANCZOS)
				smooth.resize(image.get_width(), image.get_height(), Image.INTERPOLATE_CUBIC)
				image = smooth
			image.generate_mipmaps()
			result = ImageTexture.create_from_image(image)
		else:
			result = source
	art_cache[file] = result
	return result

func art_slice(parent: Node, file: String, region: Rect2 = Rect2(), mode: String = "full", caps: Vector4 = Vector4.ZERO, cap_scale: float = 1.0) -> ArtSlice:
	var tex = skin_art(file)
	if tex == null:
		return null
	var node = ArtSlice.new().setup(tex, region, mode, caps, cap_scale)
	parent.add_child(node)
	return node

func fit_size(text: String, font: Font, max_width: float, start: int, minimum: int = 7) -> int:
	var size = start
	while size > minimum and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > max_width:
		size -= 1
	return size

func outlined(node: Label, outline: Color = Color(0, 0, 0, 0.9), amount: int = 4) -> void:
	node.add_theme_color_override("font_outline_color", outline)
	node.add_theme_constant_override("outline_size", amount)

func stat_gem(parent: Node, kind: String, text: String, position: Vector2, size: float, tint: Color = Color.WHITE) -> Control:
	var file = "gem_%s.png" % kind
	var holder = Control.new()
	holder.position = position
	holder.size = Vector2(size, size)
	holder.custom_minimum_size = Vector2(size, size)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(holder)
	var slice = art_slice(holder, file)
	if slice == null:
		holder.queue_free()
		return null
	slice.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slice.modulate = tint
	var number = Label.new()
	number.text = text
	number.size = Vector2(size, size)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	number.add_theme_font_size_override("font_size", int(size * 0.55))
	if number_font == null and ResourceLoader.exists(skin_dir + "font_numbers.ttf"):
		number_font = load(skin_dir + "font_numbers.ttf")
	if number_font != null:
		number.add_theme_font_override("font", number_font)
	elif portrait_font != null:
		number.add_theme_font_override("font", portrait_font)
	number.add_theme_color_override("font_color", Color.WHITE)
	outlined(number, Color(0.05, 0.02, 0.0, 0.95), maxi(3, int(size * 0.14)))
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(number)
	return holder

func art_chip(parent: Node, file: String, region: Rect2, text: String, icon_file: String, ink: Color) -> void:
	if skin_art(file) == null:
		chip(text, parent, Color("685128"), 14, Color("ffe2a0"))
		return
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	parent.add_child(row)
	var holder = Control.new()
	var font = portrait_font
	var text_width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	holder.custom_minimum_size = Vector2(text_width + 74, 36)
	row.add_child(holder)
	var body = art_slice(holder, file, region, "h3", Vector4(region.size.y * 0.55 / 0.34 * 0.5, 0, region.size.y * 0.55 / 0.34 * 0.5, 0))
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var icon = art_slice(holder, icon_file)
	if icon != null:
		icon.position = Vector2(3, 3)
		icon.size = Vector2(30, 30)
	var node = Label.new()
	node.text = text
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	node.offset_left = 36
	node.offset_right = -8
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.add_theme_font_override("font", font)
	node.add_theme_font_size_override("font_size", 13)
	node.add_theme_color_override("font_color", ink)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(node)

func filter_chip_row(parent: Node, options: Array, current: String, on_pick: Callable) -> void:
	if skin_art("chip_filter.png") == null:
		super.filter_chip_row(parent, options, current, on_pick)
		return
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	for entry in options:
		var key: String = entry[0]
		var pick = small_button(entry[1], row, on_pick.bind(key))
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pick.custom_minimum_size = Vector2(0, 44)
		var on = key == current
		dress_button(pick, "chip_filter_active.png" if on else "chip_filter.png", Color("2a1800") if on else Color("f1deb0"), Color("120a00") if on else Color("fff4d2"), portrait_font, CHIP_FILTER_ACTIVE_REGION if on else CHIP_FILTER_REGION, 26.0)
		pick.add_theme_font_size_override("font_size", 12)
		pick.autowrap_mode = TextServer.AUTOWRAP_OFF
		pick.custom_minimum_size.x = 0
		pick.clip_text = true

func corner_badge(face: Control, text: String, width: float) -> void:
	var is_new = text == "YENİ"
	var file = "badge_new.png" if is_new else "badge_count.png"
	if skin_art(file) == null:
		badge(face, text, Vector2(width - 29, 3), Color("243a35"), 25)
		return
	var size = Vector2(46, 23) if is_new else Vector2(28, 28)
	var holder = Control.new()
	holder.position = Vector2(width - size.x + 6, -4)
	holder.size = size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(holder)
	var slice = art_slice(holder, file, Rect2(11, 28, 234, 72) if is_new else Rect2(6, 6, 115, 116))
	slice.size = size
	var node = Label.new()
	node.text = text
	node.size = size
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.add_theme_font_size_override("font_size", 9 if is_new else 12)
	node.add_theme_font_override("font", number_font if number_font != null else portrait_font)
	node.add_theme_color_override("font_color", Color("3a1c00") if is_new else Color.WHITE)
	if not is_new:
		outlined(node, Color(0, 0, 0, 0.9), 3)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(node)

func mini_card(id: int, parent: Node, width: float, unit: Dictionary = {}, tap: Callable = Callable(), state: String = "", corner: String = "", full: bool = false) -> PanelContainer:
	var info: Dictionary = cards[id]
	var kind = "legend" if info.rarity == "legendary" else str(info.type)
	var spec: Dictionary = FRAMES[kind]
	if skin_art(spec.file) == null:
		return mini_card_flat(id, parent, width, unit, tap, state, corner, full)
	var frame_height = width * 1.34
	var height = width * 1.72 if full else frame_height
	var rarity_color: Color = RARITY[info.rarity]
	var rim: Color = Color("82e6a9") if state == "ready" else Color("fff0a9") if state == "picked" else rarity_color
	var wrap = PanelContainer.new()
	wrap.custom_minimum_size = Vector2(width, height)
	wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var style = box(Color("120d09"), Color(0, 0, 0, 0), 0, 14, 0)
	style.shadow_color = Color(0, 0, 0, 0.7)
	style.shadow_size = 7
	style.shadow_offset = Vector2(0, 4)
	if state in ["ready", "picked"]:
		style.shadow_color = Color(rim.r, rim.g, rim.b, 0.45)
		style.shadow_size = 8
		style.shadow_offset = Vector2.ZERO
	elif info.rarity == "legendary":
		style.shadow_color = Color(1.0, 0.78, 0.3, 0.35)
		style.shadow_size = 8
		style.shadow_offset = Vector2.ZERO
	wrap.add_theme_stylebox_override("panel", style)
	parent.add_child(wrap)
	wrap.set_meta("card_id", id)
	if state in ["dim", "tired"]:
		wrap.modulate = Color(0.62, 0.65, 0.72, 1)
	if not unit.is_empty():
		unit_nodes[int(unit.uid)] = wrap
	var face = Control.new()
	face.custom_minimum_size = Vector2(width, height)
	wrap.add_child(face)
	if state == "picked" and not unit.is_empty():
		var ring = art_slice(face, "target_ring.png")
		if ring != null:
			ring.size = Vector2(width * 1.25, width * 1.25)
			ring.position = Vector2(-width * 0.125, (width * 1.34 - ring.size.y) * 0.5)
			ring.set_meta("skin_asset", "target_ring.png")
			ring.z_index = 3
			ring.pivot_offset = ring.size / 2
			var target_pulse = ring.create_tween().set_loops()
			target_pulse.tween_property(ring, "modulate:a", 0.55, 0.5)
			target_pulse.tween_property(ring, "modulate:a", 1.0, 0.5)
	if state in ["ready", "picked"] or info.rarity == "legendary":
		var glow_file = "fx_glow_legend.png" if info.rarity == "legendary" and state not in ["ready", "picked"] else "fx_glow_ready.png"
		var glow_sprite = art_slice(face, glow_file)
		if glow_sprite != null:
			glow_sprite.set_meta("decor", true)
			glow_sprite.position = Vector2(-width * 0.28, -frame_height * 0.22)
			glow_sprite.size = Vector2(width * 1.56, frame_height * 1.44)
			if state in ["ready", "picked"]:
				var pulse_tween = glow_sprite.create_tween().set_loops()
				pulse_tween.tween_property(glow_sprite, "modulate:a", 0.55, 0.7).set_trans(Tween.TRANS_SINE)
				pulse_tween.tween_property(glow_sprite, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)
	var bbox: Rect2 = spec.bbox
	var win: Rect2 = spec.win
	var sx = width / bbox.size.x
	var sy = frame_height / bbox.size.y
	var window = Rect2((win.position.x - bbox.position.x) * sx, (win.position.y - bbox.position.y) * sy, win.size.x * sx, win.size.y * sy)
	var art = TextureRect.new()
	art.texture = texture_for(id)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.position = window.position - Vector2(1, 1)
	art.size = window.size + Vector2(2, 2)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.clip_contents = true
	face.add_child(art)
	var frame = art_slice(face, spec.file, bbox)
	frame.size = Vector2(width, frame_height)
	var plate_top = window.end.y + frame_height * 0.025
	var plate_bottom = frame_height * 0.93
	var plate_h = plate_bottom - plate_top
	var name_font: Font = portrait_font if portrait_font != null and width >= 100 else get_theme_default_font()
	var name_width = width * (0.62 if width >= 100 else 0.68)
	var name_size = fit_size(info.name, name_font, name_width - 10, 15 if width > 120 else 12, 7)
	var nameplate = Label.new()
	nameplate.text = info.name
	var narrow = width < 100
	nameplate.position = Vector2((width - name_width) / 2, plate_top + plate_h * (0.12 if narrow else 0.04))
	nameplate.custom_minimum_size = Vector2(0, 0)
	nameplate.set_deferred("size", Vector2(name_width, plate_h * (0.62 if narrow else 0.46)))
	nameplate.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nameplate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nameplate.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nameplate.autowrap_mode = TextServer.AUTOWRAP_OFF
	nameplate.clip_text = true
	nameplate.add_theme_font_override("font", name_font)
	nameplate.add_theme_font_size_override("font_size", name_size)
	nameplate.add_theme_color_override("font_color", Color("f7e3a6"))
	outlined(nameplate, Color(0.1, 0.05, 0.0, 0.95), 3)
	nameplate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(nameplate)
	var sub = TextServer.AUTOWRAP_OFF
	var second = Label.new()
	second.text = "BÜYÜ" if info.type == "spell" else "TUZAK" if info.type == "trap" else RARITY_NAME[info.rarity].to_upper()
	second.position = Vector2((width - name_width) / 2, plate_top + plate_h * 0.50)
	second.visible = not narrow
	second.set_deferred("size", Vector2(name_width, plate_h * 0.34))
	second.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	second.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	second.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	second.autowrap_mode = sub
	second.clip_text = true
	second.add_theme_font_size_override("font_size", 9 if width > 70 else 7)
	second.add_theme_color_override("font_color", Color("8fe0e8") if info.type == "spell" else Color("c1a8ff") if info.type == "trap" else rarity_color.lightened(0.25))
	outlined(second, Color(0, 0, 0, 0.9), 2)
	second.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(second)
	if not narrow and width > 70:
		var kind_icon = "icon_type_spell.png" if info.type == "spell" else "icon_type_trap.png" if info.type == "trap" else "icon_rarity_%s.png" % info.rarity
		var icon_size = plate_h * 0.36
		small_icon(face, kind_icon, Vector2(width * 0.5 - name_width * 0.5, plate_top + plate_h * 0.52), icon_size)
	if full:
		var slab = Panel.new()
		slab.position = Vector2(4, frame_height + 2)
		slab.size = Vector2(width - 8, height - frame_height - 6)
		slab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slab.add_theme_stylebox_override("panel", box(Color("1c1510"), Color("7a6238"), 1, 8, 0))
		face.add_child(slab)
		var effect = Label.new()
		effect.text = info.text
		effect.position = Vector2(10, frame_height + 6)
		effect.custom_minimum_size = Vector2(width - 20, 0)
		effect.set_deferred("size", Vector2(width - 20, maxf(20, height - frame_height - 14)))
		effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		effect.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		effect.add_theme_font_size_override("font_size", 12)
		effect.add_theme_color_override("font_color", Color("ead9b0"))
		effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.add_child(effect)
	var gem = clampf(width * 0.36, 24, 44)
	stat_gem(face, "mana", str(int(info.cost)), Vector2(-gem * 0.22, -gem * 0.2), gem)
	if info.type == "warrior":
		var small = gem * 0.86
		stat_gem(face, "attack", str(unit_attack(unit) if not unit.is_empty() else int(info.attack)), Vector2(-small * 0.2, frame_height - small * 0.85), small)
		var hp_now = int(unit.get("hp", info.hp))
		var hurt = hp_now < int(unit.get("maxHp", info.hp))
		stat_gem(face, "health", str(hp_now), Vector2(width - small * 0.8, frame_height - small * 0.85), small, Color(1.0, 0.62, 0.45) if hurt else Color.WHITE)
	if corner != "":
		corner_badge(face, corner, width)
	if tap.is_valid():
		var overlay = Button.new()
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		overlay.set_meta("card_overlay", true)
		overlay.tooltip_text = "%s · %s" % [info.name, info.text]
		for key in ["normal", "hover", "pressed", "focus"]:
			overlay.add_theme_stylebox_override(key, StyleBoxEmpty.new())
		overlay.pressed.connect(func():
			if Time.get_ticks_msec() >= suppress_card_tap_until:
				tap.call())
		wrap.add_child(overlay)
	return wrap

var hero_choice = 0
const HERO_FILES = ["hero_player.png", "hero_player_alt1.png", "hero_player_alt2.png", "hero_player_alt3.png", "hero_player_alt4.png", "hero_player_alt5.png"]

func hero_file(index: int) -> String:
	if index == 0:
		return HERO_FILES[hero_choice] if skin_art(HERO_FILES[hero_choice]) != null else "hero_player.png"
	var chapter = int(room.get("chapterId", 0))
	if chapter >= 1 and chapter <= 10 and skin_art("enemy_%02d.png" % chapter) != null:
		return "enemy_%02d.png" % chapter
	return "hero_foe.png"

func hero(parent: Control, index: int, player: Dictionary, at: Vector2, diameter: float) -> void:
	var portrait_file = hero_file(index)
	var tex = skin_art(portrait_file)
	if tex == null:
		hero_flat(parent, index, player, at, diameter)
		return
	var frame = Control.new()
	frame.position = at
	frame.size = Vector2(diameter, diameter)
	frame.custom_minimum_size = Vector2(diameter, diameter)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(frame)
	var glow = Panel.new()
	glow.size = Vector2(diameter, diameter)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glow_style = box(Color("0d0a08"), Color(0, 0, 0, 0), 0, int(diameter / 2), 0)
	glow_style.shadow_color = Color(1.0, 0.78, 0.3, 0.5)
	glow_style.shadow_size = 10
	glow.add_theme_stylebox_override("panel", glow_style)
	frame.add_child(glow)
	var portrait = art_slice(frame, portrait_file)
	portrait.size = Vector2(diameter, diameter)
	var hero_border = art_slice(frame, "hero_ring.png")
	if hero_border != null:
		hero_border.size = Vector2(diameter, diameter)
		hero_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hero_border.set_meta("skin_asset", "hero_ring.png")
	hero_nodes[index] = frame
	var hp = maxi(0, int(player.hp))
	var gem = clampf(diameter * 0.6, 30, 52)
	stat_gem(parent, "health", str(hp), at + Vector2(diameter - gem * 0.72, diameter - gem * 0.8), gem, Color.WHITE if hp > 8 else Color(1.0, 0.45, 0.35))
	var target = selected.filter(func(action): return str(action.get("target", "")) == "hero:" + str(index))
	if not target.is_empty():
		var ring = art_slice(parent, "target_ring.png", Rect2(11, 11, 234, 234))
		if ring != null:
			ring.size = Vector2(diameter * 1.45, diameter * 1.45)
			ring.position = at - Vector2(diameter * 0.225, diameter * 0.225)
			ring.set_meta("skin_asset", "target_ring.png")
			ring.pivot_offset = ring.size / 2
			var pulse = ring.create_tween().set_loops()
			pulse.tween_property(ring, "scale", Vector2(1.08, 1.08), 0.5)
			pulse.tween_property(ring, "scale", Vector2.ONE, 0.5)
	var hit = Button.new()
	hit.position = at
	hit.size = Vector2(diameter, diameter)
	hit.add_theme_stylebox_override("normal", box(Color.TRANSPARENT, Color("82e6a9") if not target.is_empty() else Color.TRANSPARENT, 3 if not target.is_empty() else 0, int(diameter / 2), 0))
	for key in ["hover", "pressed"]:
		hit.add_theme_stylebox_override(key, box(Color(1, 1, 1, 0.12), GOLD, 2, int(diameter / 2), 0))
	hit.pressed.connect(func():
		if not target.is_empty():
			move(target[0]))
	parent.add_child(hit)

func dress_button(node: Button, file: String, ink: Color, ink_hi: Color, font: Font = null, region: Rect2 = BUTTON_REGION, cap: float = BUTTON_CAP) -> void:
	var old = node.get_meta("art_slice") if node.has_meta("art_slice") else null
	if is_instance_valid(old):
		node.remove_child(old)
		old.free()
	var tex = skin_art(file)
	if tex == null:
		return
	var pad = StyleBoxEmpty.new()
	var cap_margin = cap * node.custom_minimum_size.y / region.size.y * 0.75 + 8
	pad.content_margin_left = cap_margin
	pad.content_margin_right = cap_margin
	pad.content_margin_top = 8
	pad.content_margin_bottom = 8
	for key in ["normal", "hover", "pressed", "disabled", "focus"]:
		node.add_theme_stylebox_override(key, pad)
	var slice = ArtSlice.new().setup(tex, region, "h3", Vector4(cap, 0, cap, 0))
	slice.show_behind_parent = true
	slice.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	node.add_child(slice)
	node.move_child(slice, 0)
	node.set_meta("art_slice", slice)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		node.add_theme_color_override(key, ink if key != "font_hover_color" else ink_hi)
	node.add_theme_color_override("font_disabled_color", Color(0.93, 0.88, 0.78, 0.95))
	if font != null:
		node.add_theme_font_override("font", font)
	var text_width = (font if font != null else node.get_theme_font("font")).get_string_size(node.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
	node.custom_minimum_size.x = maxf(node.custom_minimum_size.x, text_width + cap_margin * 2)
	if node.disabled:
		slice.modulate = Color(0.5, 0.5, 0.5, 0.95)
	if not node.has_meta("art_hooks"):
		node.set_meta("art_hooks", true)
		var reference = weakref(node)
		node.mouse_entered.connect(tint_button_art.bind(reference, Color(1.15, 1.1, 1.0)))
		node.mouse_exited.connect(tint_button_art.bind(reference, Color.WHITE))
		node.button_down.connect(tint_button_art.bind(reference, Color(0.78, 0.74, 0.7)))
		node.button_up.connect(tint_button_art.bind(reference, Color.WHITE))

func tint_button_art(reference: WeakRef, tint: Color) -> void:
	var node = reference.get_ref()
	if not is_instance_valid(node):
		return
	var art = node.get_meta("art_slice", null)
	if is_instance_valid(art):
		art.modulate = Color(0.55, 0.55, 0.55, 0.9) if node.disabled else tint

func button(text: String, parent: Node, callback: Callable, disabled: bool = false) -> Button:
	var node = super.button(text, parent, callback, disabled)
	var icon_file = "icon_close.png" if text in ["İptal", "Kapat"] or text.ends_with("Kapat") else "icon_lock.png" if text == "Kilitli" else "icon_check.png" if "Tamamlandı" in text or text == "Başla" else "icon_league.png" if "LİG" in text else ""
	if not icon_file.is_empty():
		node.icon = skin_art(icon_file)
		node.expand_icon = true
		node.add_theme_constant_override("icon_max_width", 20)
	if text.length() <= 7 or not node.get_theme_font("font"):
		return node
	if text.begins_with("Teslim"):
		dress_button(node, "button_red.png", Color("fff1e0"), Color.WHITE)
		if skin_art("icon_surrender.png") != null:
			node.icon = skin_art("icon_surrender.png")
			node.expand_icon = true
			node.add_theme_constant_override("icon_max_width", 22)
	else:
		dress_button(node, "button_dark.png", Color("f6e3ae"), Color("fff6d6"))
	return node

func icon_on(node: Button, file: String) -> Button:
	var tex = skin_art(file)
	if node != null and tex != null:
		node.icon = tex
		node.expand_icon = true
		node.add_theme_constant_override("icon_max_width", 22)
	return node

func primary_button(text: String, parent: Node, callback: Callable, disabled: bool = false) -> Button:
	var node = super.primary_button(text, parent, callback, disabled)
	if text == "Turu bitir" and skin_art("end_turn_ready.png") != null:
		node.custom_minimum_size.y = 62
		dress_button(node, "end_turn_ready.png", Color("2c1904"), Color("120a00"), portrait_font, END_TURN_REGION, 150.0)
		node.autowrap_mode = TextServer.AUTOWRAP_OFF
		node.add_theme_font_size_override("font_size", 15)
		node.custom_minimum_size.x = 170
	else:
		dress_button(node, "button_gold.png", Color("2c1904"), Color("120a00"), portrait_font)
	if portrait_font != null:
		var font_size = 17 if text.length() <= 11 else 14
		node.add_theme_font_size_override("font_size", font_size)
		var measured = portrait_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 76
		node.custom_minimum_size.x = minf(maxf(node.custom_minimum_size.x, measured), 240 if compact else 340)
		node.autowrap_mode = TextServer.AUTOWRAP_OFF
	if text != "Turu bitir":
		node.custom_minimum_size.y = 56
	return node


func banner_toast(text: String, color: Color) -> void:
	if skin_art("toast_banner.png") == null:
		toast(text, color)
		return
	var holder = Control.new()
	holder.custom_minimum_size = Vector2(300, 66)
	holder.size = Vector2(300, 66)
	holder.z_index = 120
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	var banner = art_slice(holder, "toast_banner.png", Rect2(48, 10, 1104, 240))
	banner.size = holder.size
	var node = Label.new()
	node.text = text
	node.size = holder.size
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.add_theme_font_override("font", portrait_font)
	node.add_theme_font_size_override("font_size", 24)
	node.add_theme_color_override("font_color", Color("fff1c4"))
	outlined(node, Color(0.2, 0.05, 0.0, 0.95), 5)
	holder.add_child(node)
	holder.global_position = (get_viewport_rect().size - holder.size) / 2 - Vector2(0, 40)
	holder.pivot_offset = holder.size / 2
	holder.scale = Vector2(0.6, 0.6)
	var tween = create_tween()
	tween.tween_property(holder, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.8)
	tween.tween_property(holder, "modulate:a", 0.0, 0.35)
	tween.tween_callback(holder.queue_free)

func choose_mode() -> void:
	var dialog = AcceptDialog.new()
	dialog.title = "SAVAŞ MODU"
	dialog.ok_button_text = "Geri"
	add_child(dialog)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	dialog.add_child(column)
	heading("MÜCADELENİ SEÇ", column, 22)
	primary_button("BOT İLE SAVAŞ", column, func(): dialog.queue_free(); view = "lobby"; mutate("solo", {"chapterId": 0, "deck": deck_payload()}))
	button("ARKADAŞLA DÜELLO", column, func(): dialog.queue_free(); render_social())
	icon_on(button("LİG MAÇI", column, func(): dialog.queue_free(); view = "lobby"; mutate("queue", {"deck": deck_payload()}), not account.profile.chapterRewards.has(10)), "icon_league.png")
	if not account.profile.chapterRewards.has(10):
		muted_label("Lig, Anadolu yolculuğu tamamlanınca açılır.", column, 13)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered_clamped(Vector2i(320, 300), 0.92)

func save_file(text: String, filename: String) -> void:
	if OS.has_feature("web"):
		var browser = JavaScriptBridge.get_interface("window")
		browser.destanDownload(text, filename)
	else:
		super.save_file(text, filename)

func render_result(state: Dictionary, width: float, height: float) -> void:
	var won = state.winner == 0
	var crest_file = "result_victory.png" if won else "result_defeat.png"
	var has_art = skin_art("panel.png") != null and skin_art(crest_file) != null
	var result = PanelContainer.new()
	var box_width = minf(330, width - 36)
	result.custom_minimum_size = Vector2(box_width, 180)
	result.position = Vector2((width - box_width) / 2, maxf(8, (height - (330 if has_art else 245)) / 2))
	var style = box(Color("14242b"), GOLD, 2, 14, 20)
	style.shadow_color = Color(0, 0, 0, 0.7)
	style.shadow_size = 20
	if has_art:
		style = StyleBoxEmpty.new()
	result.add_theme_stylebox_override("panel", style)
	arena.add_child(result)
	if has_art:
		var shade = Panel.new()
		var shade_style = box(Color(0, 0, 0, 0.55), Color(0, 0, 0, 0), 0, 24, 0)
		shade_style.shadow_color = Color(0, 0, 0, 0.6)
		shade_style.shadow_size = 24
		shade.add_theme_stylebox_override("panel", shade_style)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		result.add_child(shade)
		var frame = art_slice(result, "panel.png", Rect2(6, 26, 788, 748), "p9", Vector4(110, 110, 110, 110), 0.4)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 34 if has_art else 0)
	result.add_child(margin)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	if has_art:
		var crest = Control.new()
		crest.custom_minimum_size = Vector2(box_width - 68, 112)
		column.add_child(crest)
		var crest_art = art_slice(crest, crest_file, Rect2(48, 28, 1103, 644) if won else Rect2(48, 59, 1104, 581))
		crest_art.size = Vector2(box_width - 68, 112)
		var title = Label.new()
		title.text = "ZAFER" if won else "BERABERE" if state.winner == null else "YENİDEN DENE"
		title.size = Vector2(box_width - 68, 112)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title.add_theme_font_override("font", portrait_font)
		title.add_theme_font_size_override("font_size", 22 if won else 17)
		title.add_theme_color_override("font_color", Color("fff1c4"))
		outlined(title, Color(0.05, 0.1, 0.1, 0.95), 5)
		crest.add_child(title)
	else:
		var symbol = heading("DESTAN", column, 18)
		symbol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var verdict = heading("ZAFER" if won else "BERABERE" if state.winner == null else "YENİDEN DENE", column, 28)
		verdict.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var message = muted_label("Bir efsane daha seninle güçlendi." if won else "Her mücadele desteni daha iyi tanıtır.", column, 13)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.add_theme_color_override("font_color", Color("e8dcc0"))
	primary_button("DEVAM ET", column, leave_match)
	icon_on(small_button("Maç kaydı", column, export_replay), "icon_replay.png")

var pack_anim_shown: Array = []

const LOADING_TIPS = [
	"Enerjin her tur artar; güçlü kartları sabırla oyna.",
	"Hedef halkası yanan kahramana saldırabilirsin.",
	"Desteni koleksiyon ekranından kendin kurabilirsin.",
	"Sandıklardan nadir ve efsane kartlar çıkabilir."
]

func show_loading_screen(force: bool = true) -> Control:
	# Progress follows completed local preparation and the connection attempt.
	var overlay = ColorRect.new()
	overlay.name = "LoadingScreen"
	overlay.color = Color(0.05, 0.03, 0.02, 1)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 200
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var view_size = get_viewport_rect().size
	var splash = skin_art("splash_clean.png")
	if splash == null:
		splash = skin_art("splash.png")
	if splash != null:
		var bg = TextureRect.new()
		bg.texture = splash
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(bg)
	var bar_width = minf(view_size.x * 0.8, 420.0)
	var bar = art_slice(overlay, "loading_bar_frame.png", Rect2(0, 0, 800, 80))
	var fill = art_slice(overlay, "loading_bar_fill.png", Rect2(0, 0, 800, 64))
	var tip_panel = art_slice(overlay, "loading_tip_panel.png", Rect2(0, 0, 900, 160))
	if bar != null and fill != null:
		bar.size = Vector2(bar_width, bar_width * 0.1)
		bar.position = Vector2((view_size.x - bar_width) / 2, view_size.y * 0.78)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fill.position = bar.position + Vector2(bar.size.x * 0.045, bar.size.y * 0.16)
		fill.size = Vector2(0, bar.size.y * 0.68)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.set_meta("loading_fill", fill)
		overlay.set_meta("loading_width", bar.size.x * 0.86)
	if tip_panel != null:
		tip_panel.size = Vector2(bar_width, bar_width * 160.0 / 900.0)
		tip_panel.position = Vector2((view_size.x - bar_width) / 2, view_size.y * 0.78 + bar_width * 0.14)
		tip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tip = Label.new()
		tip.text = LOADING_TIPS[randi() % LOADING_TIPS.size()]
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tip.add_theme_font_size_override("font_size", 12)
		tip.add_theme_color_override("font_color", Color(0.98, 0.9, 0.7))
		tip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 18)
		tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tip_panel.add_child(tip)
	var status = label("Görseller hazırlanıyor…", overlay, 12)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.position = Vector2((view_size.x - bar_width) / 2, view_size.y * 0.78 - 26)
	status.size = Vector2(bar_width, 24)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_meta("loading_status", status)
	if not force:
		prepare_startup.call_deferred(overlay)
	return overlay

func loading_progress(overlay: Control, progress: float, caption: String) -> void:
	if not is_instance_valid(overlay):
		return
	var fill = overlay.get_meta("loading_fill", null)
	if is_instance_valid(fill):
		fill.size.x = float(overlay.get_meta("loading_width")) * clampf(progress, 0, 1)
	var status = overlay.get_meta("loading_status", null)
	if is_instance_valid(status):
		status.text = caption

func prepare_startup(overlay: Control) -> void:
	var files = ["frame_unit.png", "frame_spell.png", "frame_trap.png", "hero_player.png", "hero_foe.png", "lane.png", "lane_enemy.png", "background_land.png", "chest_open.png", "result_victory.png"]
	for index in files.size():
		if not is_instance_valid(overlay):
			return
		skin_art(files[index])
		loading_progress(overlay, 0.8 * float(index + 1) / files.size(), "Görseller hazırlanıyor · %d/%d" % [index + 1, files.size()])
		await get_tree().process_frame
	loading_progress(overlay, 0.85, "Sunucu bağlantısı kontrol ediliyor…")
	var started = Time.get_ticks_msec()
	while busy and Time.get_ticks_msec() - started < 8000:
		await get_tree().process_frame
	if not is_instance_valid(overlay):
		return
	loading_progress(overlay, 1.0, "Oynamaya hazırsın" if connected else "Yerel hazırlık tamam · Sunucu adresini kontrol et")
	var fade = overlay.create_tween()
	fade.tween_property(overlay, "modulate:a", 0.0, 0.25)
	fade.tween_callback(overlay.queue_free)

var inspect_overlay: Control

func inspect_card(id: int, unit: Dictionary = {}) -> void:
	# Kart ayrıntısı: oyunun görünümüne uygun, büyük kartlı ve dokununca kapanan pencere.
	if is_instance_valid(inspect_overlay):
		inspect_overlay.queue_free()
	var info: Dictionary = cards[id]
	var overlay = ColorRect.new()
	overlay.name = "CardInspect"
	overlay.color = Color(0, 0, 0, 0.78)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 170
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	inspect_overlay = overlay
	var view = get_viewport_rect().size
	var wide = view.x > view.y
	var card_width = clampf(minf(view.x * (0.3 if wide else 0.62), (view.y - 120.0) / 1.34 * (1.0 if wide else 0.62)), 110.0, 230.0)
	var box_node = BoxContainer.new()
	box_node.vertical = not wide
	box_node.add_theme_constant_override("separation", 18)
	box_node.alignment = BoxContainer.ALIGNMENT_CENTER
	box_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box_node.offset_left = 20
	box_node.offset_right = -20
	box_node.offset_top = 56
	box_node.offset_bottom = -20
	overlay.add_child(box_node)
	mini_card(id, box_node, card_width, unit, Callable(), "", "", false)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.custom_minimum_size.x = minf(320.0, view.x - 40.0) if not wide else minf(330.0, view.x - card_width - 80.0)
	box_node.add_child(column)
	var title = heading(str(info.name), column, 22)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_color_override("font_color", Color("f1dfb7"))
	var kind = muted_label("%d enerji · %s · %s" % [int(info.cost), TYPE_NAME[info.type], RARITY_NAME[info.rarity]], column, 14)
	kind.add_theme_color_override("font_color", Color("e0c27a"))
	if info.type == "warrior":
		var attack = unit_attack(unit) if not unit.is_empty() else int(info.attack)
		label("Saldırı %d · Can %d" % [attack, int(unit.get("hp", info.hp))], column, 15)
	if not info.keywords.is_empty():
		var words = muted_label(", ".join(info.keywords.map(func(word): return str(word))), column, 13)
		words.add_theme_color_override("font_color", Color("9fd6ff"))
	var description = muted_label(str(info.text), column, 14)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_color_override("font_color", Color("e8dcc0"))
	var close_button = primary_button("Tamam", column, func(): overlay.queue_free())
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	overlay.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			overlay.queue_free())

func show_pack_reveal() -> void:
	# Sandık sallanır, açılır, parlama patlar; dokununca ya da kendiliğinden kapanır.
	var closed = skin_art("chest_closed.png")
	var opened = skin_art("chest_open.png")
	if closed == null or opened == null:
		return
	var overlay = ColorRect.new()
	overlay.name = "PackReveal"
	overlay.color = Color(0, 0, 0, 0.72)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 150
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var view_size = get_viewport_rect().size
	var side = minf(minf(view_size.x, view_size.y) * 0.7, 360.0)
	var burst = skin_art("pack_reveal_burst.png")
	var burst_node = TextureRect.new()
	burst_node.texture = burst
	burst_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	burst_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	burst_node.size = Vector2(side * 1.6, side * 1.6)
	burst_node.position = (view_size - burst_node.size) / 2
	burst_node.pivot_offset = burst_node.size / 2
	burst_node.modulate.a = 0.0
	burst_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(burst_node)
	var chest = TextureRect.new()
	chest.texture = closed
	chest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chest.size = Vector2(side, side)
	chest.position = (view_size - chest.size) / 2
	chest.pivot_offset = chest.size / 2
	chest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(chest)
	play_sound("pack")
	var tween = create_tween()
	for angle in [0.12, -0.12, 0.09, -0.09, 0.0]:
		tween.tween_property(chest, "rotation", angle, 0.09)
	tween.tween_callback(func():
		chest.texture = opened)
	tween.tween_property(chest, "scale", Vector2(1.12, 1.12), 0.12)
	tween.parallel().tween_property(burst_node, "modulate:a", 1.0, 0.18)
	tween.tween_property(burst_node, "scale", Vector2(1.25, 1.25), 0.5)
	tween.parallel().tween_property(burst_node, "rotation", 0.3, 0.5)
	tween.tween_interval(0.35)
	tween.tween_property(overlay, "modulate:a", 0.0, 0.3)
	tween.tween_callback(overlay.queue_free)
	overlay.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed or event is InputEventScreenTouch and event.pressed:
			tween.kill()
			overlay.queue_free())

func render_pack_reveal() -> void:
	var signature = str(last_pack)
	if not pack_anim_shown.has(signature):
		pack_anim_shown.append(signature)
		show_pack_reveal()
	heading("SANDIK AÇILDI", content, 24)
	var row = HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 12)
	row.add_theme_constant_override("v_separation", 12)
	content.add_child(row)
	for reward in last_pack:
		if reward.get("id") != null:
			mini_card(int(reward.id), row, 112, {}, inspect_card.bind(int(reward.id)), "picked", "YENİ", true)
		else:
			chip("+%d toz" % int(reward.get("dust", 0)), row, Color("334367"), 15)
	icon_on(button("Koleksiyona ekledin · Kapat", content, func(): last_pack = []; render()), "icon_close.png")

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		cancel_gesture()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		application_paused = true
		cancel_gesture()
		if is_instance_valid(poll):
			poll.stop()
		if is_instance_valid(reconnect_timer):
			reconnect_timer.stop()
		Engine.max_fps = 10
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		application_paused = false
		Engine.max_fps = 60
		if is_instance_valid(poll):
			refresh.call_deferred()
			if connected:
				poll.start()
			elif is_instance_valid(reconnect_timer):
				reconnect_timer.start(0.2)
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		cancel_gesture()
		if not room.is_empty() and not gallery_open:
			confirm_leave()
		else:
			open_tab("play")


func skin_theme_extras() -> void:
	# Giriş alanı, kaydırma çubuğu ve ipucu paneli için skin dokuları.
	var field = skin_art("input_field.png")
	if field != null:
		# Görsel 800x120: yarı boyuta indirilip 9 parça olarak kullanılır (kenarlar esnemesin).
		var image = field.get_image().get_region(Rect2i(30, 3, 740, 114))
		image.resize(370, 57, Image.INTERPOLATE_LANCZOS)
		image.generate_mipmaps()
		var small_field = ImageTexture.create_from_image(image)
		for state in ["normal", "focus", "read_only"]:
			var style = StyleBoxTexture.new()
			style.texture = small_field
			style.texture_margin_left = 30
			style.texture_margin_right = 30
			style.texture_margin_top = 22
			style.texture_margin_bottom = 22
			style.content_margin_left = 22
			style.content_margin_right = 22
			style.content_margin_top = 4
			style.content_margin_bottom = 4
			if state == "focus":
				style.modulate_color = Color(1.3, 1.2, 1.0)
			theme.set_stylebox(state, "LineEdit", style)
	var bar = skin_art("scrollbar.png")
	if bar != null:
		var grabber = StyleBoxTexture.new()
		grabber.texture = bar
		grabber.region_rect = Rect2(10, 16, 43, 368)
		grabber.texture_margin_top = 16
		grabber.texture_margin_bottom = 16
		grabber.texture_margin_left = 6
		grabber.texture_margin_right = 6
		for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
			theme.set_stylebox(state, "VScrollBar", grabber)
		theme.set_stylebox("scroll", "VScrollBar", StyleBoxEmpty.new())
	var tip = skin_art("tooltip_panel.png")
	if tip != null:
		var style = StyleBoxTexture.new()
		style.texture = tip
		style.region_rect = Rect2(24, 37, 552, 225)
		style.texture_margin_left = 60
		style.texture_margin_right = 60
		style.texture_margin_top = 40
		style.texture_margin_bottom = 40
		style.content_margin_left = 24
		style.content_margin_right = 24
		style.content_margin_top = 14
		style.content_margin_bottom = 14
		theme.set_stylebox("panel", "TooltipPanel", style)
		theme.set_color("font_color", "TooltipLabel", INK)

func divider_art(parent: Node) -> Control:
	var line = art_slice(parent, "divider.png", Rect2(180, 3, 640, 54))
	if line == null:
		return null
	line.custom_minimum_size = Vector2(0, 14)
	line.set_meta("skin_asset", "divider.png")
	return line

func progress_art(parent: Node, value: float, maximum: float) -> Control:
	var frame = art_slice(parent, "progress_frame.png", Rect2(31, 2, 739, 36))
	if frame == null:
		var fallback = ProgressBar.new()
		fallback.max_value = maximum
		fallback.value = value
		fallback.show_percentage = false
		fallback.custom_minimum_size.y = 5
		parent.add_child(fallback)
		return fallback
	frame.custom_minimum_size = Vector2(0, 22)
	frame.set_meta("skin_asset", "progress_frame.png")
	var fill = art_slice(frame, "progress_fill.png", Rect2(0, 0, 800, 40))
	fill.set_meta("skin_asset", "progress_fill.png")
	var apply = func():
		var inner = Rect2(4, 3, frame.size.x - 8, frame.size.y - 6)
		fill.position = inner.position
		fill.size = Vector2(inner.size.x * value / maxf(maximum, 1.0), inner.size.y)
		fill.visible = value > 0
	frame.resized.connect(apply)
	apply.call_deferred()
	return frame

func tile_press(column: Control, callback: Callable) -> void:
	# Tüm kartı dokunulabilir yapar (iç düğme genişliği satırı taşırmasın diye).
	var holder = column.get_parent().get_parent()
	var press = Button.new()
	press.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	press.focus_mode = Control.FOCUS_ALL
	for key in ["normal", "hover", "pressed", "disabled"]:
		press.add_theme_stylebox_override(key, StyleBoxEmpty.new())
	var focus_style = StyleBoxFlat.new()
	focus_style.bg_color = Color.TRANSPARENT
	focus_style.border_color = GOLD
	focus_style.set_border_width_all(2)
	focus_style.set_corner_radius_all(12)
	press.add_theme_stylebox_override("focus", focus_style)
	press.pressed.connect(callback)
	holder.add_child(press)

func hero_picker(parent: Node) -> void:
	if skin_art("hero_player_alt1.png") == null:
		return
	muted_label("Kahramanını seç", parent, 14)
	var row = HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 14)
	parent.add_child(row)
	for index in HERO_FILES.size():
		if skin_art(HERO_FILES[index]) == null:
			continue
		var tile = Button.new()
		tile.custom_minimum_size = Vector2(88, 88)
		tile.tooltip_text = "Kahraman %d" % (index + 1)
		tile.toggle_mode = true
		tile.button_pressed = index == hero_choice
		for key in ["normal", "hover", "pressed", "disabled", "focus"]:
			tile.add_theme_stylebox_override(key, StyleBoxEmpty.new())
		var hero_tex = skin_art(HERO_FILES[index])
		var used = Rect2(hero_tex.get_image().get_used_rect())
		var portrait = art_slice(tile, HERO_FILES[index], used)
		portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		portrait.offset_left = 8
		portrait.offset_right = -8
		portrait.offset_top = 8
		portrait.offset_bottom = -8
		portrait.set_meta("skin_asset", HERO_FILES[index])
		if index == hero_choice:
			var ring = art_slice(tile, "hero_ring.png", Rect2(8, 6, 495, 500))
			if ring != null:
				ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				ring.set_meta("skin_asset", "hero_ring.png")
		tile.pressed.connect(func():
			hero_choice = index
			persist_session()
			render_profile())
		row.add_child(tile)
