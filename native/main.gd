extends Control
## Native Godot client. The shared Node server validates all forty card effects.
signal updated

var SESSION_FILE = "user://destan-session.cfg"
var PENDING_FILE = "user://destan-pending.json"
var BG = Color("0b1519")
var SURFACE = Color("14272e")
var SURFACE_HI = Color("203d45")
var GOLD = Color("d7b668")
var INK = Color("e8dfc5")
var MUTED = Color("93a1a4")
var RARITY = {"common": Color("a0795a"), "rare": Color("5d8fc2"), "legendary": Color("d4a72c")}
var RARITY_NAME = {"common": "Yaygın", "rare": "Nadir", "legendary": "Efsanevi"}
var TYPE_COLOR = {"warrior": Color("b5452f"), "spell": Color("1d7f86"), "trap": Color("5a4a8a")}
var TYPE_NAME = {"warrior": "Savaşçı", "spell": "Büyü", "trap": "Tuzak"}
var network_panel: VBoxContainer
var shell_margin: MarginContainer
var action_bar: HFlowContainer
var nav_bar: HBoxContainer
var scroll: ScrollContainer
var nav_buttons: Dictionary = {}
var sound_button: Button
var compact = false
var local_server_pid = -1
var view = "lobby"
var endpoint = "http://127.0.0.1:8080"
const OfflineService = preload("res://native/offline.gd")
var offline_mode = false
var offline_service = null
var request_timeout = 12.0
var cookie = ""
var account: Dictionary = {}
var room: Dictionary = {}
var data: Dictionary = {}
var cards: Dictionary = {}
var busy = false
var selected: Array = []
var focus: Dictionary = {}
var pending: Dictionary = {}
var recovery_key = ""
var notice: Label
var content: VBoxContainer
var address: LineEdit
var recover_input: LineEdit
var chapter_select: OptionButton
var room_code: LineEdit
var poll: Timer
var save_dialog: FileDialog
var save_text = ""
var account_line: Label
var turn_clock: Label
var server_offset = 0.0
var gallery_open = false
var custom_deck: Array = []
var deck_counts: Dictionary = {}
var use_custom = false
var deck_total: Label
var muted = true
var audio: AudioStreamPlayer
var textures: Dictionary = {}
var mulligan_indices: Array = []
var collection_filter = "all"
var owned_only = false
var last_pack: Array = []
var intro_seen: Dictionary = {}
var unit_nodes: Dictionary = {}
var hero_nodes: Dictionary = {}
var prev_state: Dictionary = {}
var last_attack: Dictionary = {}

const DEFAULT_SKIN = {
	"banner": "1b3138",
	"bar": "10222a",
	"bg": "0b1519",
	"border": "2b4852",
	"border_dim": "22383f",
	"button_text": "f1dfb2",
	"button_text_hi": "fff2c9",
	"card_back": "101d22",
	"card_name": "f3ead2",
	"card_tag": "f6e6b4",
	"card_text": "c3cdd0",
	"chip_dust": "4d5f9e",
	"chip_gold": "8a6d1c",
	"detail": "12262d",
	"disabled_border": "34434a",
	"disabled_fill": "3a4a4c",
	"disabled_text": "829093",
	"disabled_text_gold": "8d9a9c",
	"energy": "2e6e9e",
	"field": "0f1d22",
	"gold": "d7b668",
	"gold_hi": "e6c97d",
	"gold_lo": "bf9a45",
	"hearts": "a83a32",
	"hearts_low": "d0301f",
	"hero": "10262d",
	"ink": "e8dfc5",
	"lane": "0e1b20",
	"muted": "93a1a4",
	"notice": "b9c6c8",
	"ok_text": "7fd6a0",
	"on_gold": "1b1405",
	"placeholder": "7d8c90",
	"quote": "c9bd98",
	"rarity_common": "a0795a",
	"rarity_legendary": "d4a72c",
	"rarity_rare": "5d8fc2",
	"ready_edge": "f4d37a",
	"reveal": "1d2e24",
	"stat_attack": "b5452f",
	"stat_health": "2f7d5b",
	"stat_health_hurt": "c47a1e",
	"surface": "14272e",
	"surface_hi": "203d45",
	"tab_active": "2a4a53",
	"type_spell": "1d7f86",
	"type_trap": "5a4a8a",
	"warn_text": "f1c6a0",
	"white": "ffffff"
}
var skin_colors: Dictionary = {}
var skin_dir = "res://native/skin/"

func sk(name: String) -> Color:
	return Color(str(skin_colors.get(name, DEFAULT_SKIN.get(name, "ff00ff"))))

func load_skin() -> void:
	## Tasarım dosyası: native/skin/skin.json (renk rolleri). İsteğe bağlı görseller:
	## background.png, font.ttf, cards/NN.png (kart resmi), logo.png
	var path = skin_dir + "skin.json"
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary and parsed.get("colors") is Dictionary:
			skin_colors = parsed.colors
	BG = sk("bg")
	SURFACE = sk("surface")
	SURFACE_HI = sk("surface_hi")
	GOLD = sk("gold")
	INK = sk("ink")
	MUTED = sk("muted")
	RARITY = {"common": sk("rarity_common"), "rare": sk("rarity_rare"), "legendary": sk("rarity_legendary")}
	TYPE_COLOR["spell"] = sk("type_spell")
	TYPE_COLOR["trap"] = sk("type_trap")
	TYPE_COLOR["warrior"] = sk("stat_attack")

func skin_texture_font() -> Font:
	for name in ["font.ttf", "font.otf"]:
		if ResourceLoader.exists(skin_dir + name):
			return load(skin_dir + name)
	return null

func skin_texture(name: String) -> Texture2D:
	var path = skin_dir + name
	if ResourceLoader.exists(path):
		return load(path)
	return null

func _ready() -> void:
	var test_dir = OS.get_environment("DESTAN_SESSION_DIR")
	if not test_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(test_dir)
		SESSION_FILE = test_dir.path_join("destan-session.cfg")
		PENDING_FILE = test_dir.path_join("destan-pending.json")
	compact = get_viewport_rect().size.x < 700
	data = JSON.parse_string(FileAccess.get_file_as_string("res://native/data.json"))
	for card in data.cards:
		cards[int(card.id)] = card
	custom_deck = data.decks.starter.cards.duplicate()
	var cfg = ConfigFile.new()
	if cfg.load(SESSION_FILE) == OK:
		endpoint = cfg.get_value("account", "endpoint", endpoint)
		cookie = cfg.get_value("account", "cookie", "")
	if not OS.get_environment("DESTAN_SERVER_URL").is_empty():
		endpoint = OS.get_environment("DESTAN_SERVER_URL")
	if OS.get_environment("DESTAN_SERVER_URL").is_empty() and OS.has_feature("mobile"):
		var client = JSON.parse_string(FileAccess.get_file_as_string("res://native/client.json"))
		if client is Dictionary and str(client.get("server_url", "")).begins_with("https://"):
			if not endpoint.begins_with("https://"):
				endpoint = str(client.server_url)
				cookie = ""
	if OS.has_feature("web"):
		var browser_window = JavaScriptBridge.get_interface("window")
		var browser_origin = str(browser_window.location.origin)
		if browser_origin.begins_with("https://") or browser_origin.begins_with("http://127.0.0.1:") or browser_origin.begins_with("http://localhost:"):
			endpoint = browser_origin
	load_skin()
	build_shell()
	get_viewport().size_changed.connect(resize_layout)
	resize_layout()
	poll = Timer.new()
	poll.wait_time = 1.5
	poll.timeout.connect(refresh)
	add_child(poll)
	poll.start()
	audio = AudioStreamPlayer.new()
	add_child(audio)
	if not OS.get_cmdline_user_args().has("--no-connect"):
		connect_account()

# ---------- small UI helpers ----------

func box(bg: Color, border: Color = Color(0, 0, 0, 0), border_width: int = 0, radius: int = 8, margin: int = 8) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin
	style.content_margin_bottom = margin
	return style

func label(text: String, parent: Node, size: int = 18) -> Label:
	var node = Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(node)
	return node

func muted_label(text: String, parent: Node, size: int = 14) -> Label:
	var node = label(text, parent, size)
	node.add_theme_color_override("font_color", MUTED)
	return node

func heading(text: String, parent: Node, size: int = 22) -> Label:
	var node = label(text, parent, size)
	node.add_theme_color_override("font_color", GOLD)
	return node

func button(text: String, parent: Node, callback: Callable, disabled: bool = false) -> Button:
	var node = Button.new()
	node.text = text
	node.custom_minimum_size.y = 48
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var measured = node.get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 28
	node.custom_minimum_size.x = minf(measured, 200 if compact else 320)
	node.disabled = disabled or busy
	node.pressed.connect(callback)
	parent.add_child(node)
	return node

func primary_button(text: String, parent: Node, callback: Callable, disabled: bool = false) -> Button:
	var node = button(text, parent, callback, disabled)
	node.custom_minimum_size.y = 54
	node.add_theme_font_size_override("font_size", 19)
	node.add_theme_stylebox_override("normal", box(GOLD, GOLD, 1, 9, 10))
	node.add_theme_stylebox_override("hover", box(sk("gold_hi"), GOLD, 1, 9, 10))
	node.add_theme_stylebox_override("pressed", box(sk("gold_lo"), GOLD, 1, 9, 10))
	node.add_theme_stylebox_override("disabled", box(sk("disabled_fill"), sk("disabled_border"), 1, 9, 10))
	node.add_theme_color_override("font_color", sk("on_gold"))
	node.add_theme_color_override("font_hover_color", sk("on_gold"))
	node.add_theme_color_override("font_pressed_color", sk("on_gold"))
	node.add_theme_color_override("font_disabled_color", sk("disabled_text_gold"))
	return node

func small_button(text: String, parent: Node, callback: Callable, disabled: bool = false) -> Button:
	var node = button(text, parent, callback, disabled)
	node.custom_minimum_size.y = 44
	node.add_theme_font_size_override("font_size", 15)
	return node

func panel(parent: Node, bg: Color = sk("surface"), border: Color = sk("border"), border_width: int = 1, margin: int = 12, radius: int = 12) -> VBoxContainer:
	var holder = PanelContainer.new()
	holder.add_theme_stylebox_override("panel", box(bg, border, border_width, radius, margin))
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(holder)
	var inner = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	holder.add_child(inner)
	return inner

func chip(text: String, parent: Node, color: Color, size: int = 14, ink: Color = sk("white")) -> Label:
	var holder = PanelContainer.new()
	holder.add_theme_stylebox_override("panel", box(color, Color(0, 0, 0, 0), 0, 11, 3))
	parent.add_child(holder)
	var node = Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", ink)
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	holder.add_child(node)
	return node

func make_theme() -> Theme:
	var palette = Theme.new()
	palette.default_font_size = 18
	var custom_font = skin_texture_font()
	if custom_font != null:
		palette.default_font = custom_font
	palette.set_color("font_color", "Label", INK)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style = box(SURFACE_HI if state in ["hover", "pressed"] else SURFACE, GOLD if state != "disabled" else sk("disabled_border"), 2 if state == "focus" else 1, 9, 10)
		if state == "focus":
			style.bg_color = Color(0, 0, 0, 0)
			style.border_color = sk("white")
		palette.set_stylebox(state, "Button", style)
	palette.set_color("font_color", "Button", sk("button_text"))
	palette.set_color("font_hover_color", "Button", sk("button_text_hi"))
	palette.set_color("font_disabled_color", "Button", sk("disabled_text"))
	palette.set_stylebox("normal", "LineEdit", box(sk("field"), sk("border"), 1, 9, 10))
	palette.set_stylebox("focus", "LineEdit", box(sk("field"), GOLD, 2, 9, 10))
	palette.set_color("font_color", "LineEdit", INK)
	palette.set_color("font_placeholder_color", "LineEdit", sk("placeholder"))
	return palette

func build_shell() -> void:
	theme = make_theme()
	var backdrop = ColorRect.new()
	backdrop.color = BG
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var wallpaper = skin_texture("background.png")
	if wallpaper != null:
		var picture = TextureRect.new()
		picture.texture = wallpaper
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(picture)
	var margin = MarginContainer.new()
	shell_margin = margin
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 6)
	margin.add_child(layout)
	var title = label("DESTAN DİYARLARI", layout, 20)
	title.add_theme_color_override("font_color", GOLD)
	account_line = label("Hesabına bağlanılıyor…", layout, 13)
	account_line.add_theme_color_override("font_color", MUTED)
	notice = label("Bağlanılıyor…", layout, 13)
	notice.add_theme_color_override("font_color", sk("notice"))
	network_panel = panel(layout)
	network_panel.get_parent().visible = false
	heading("Ayarlar", network_panel, 18)
	var network = HBoxContainer.new()
	network_panel.add_child(network)
	address = LineEdit.new()
	address.text = endpoint
	address.placeholder_text = "Sunucu adresi"
	address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	address.custom_minimum_size.y = 48
	network.add_child(address)
	button("Bağlan", network, connect_account)
	var tools = HFlowContainer.new()
	network_panel.add_child(tools)
	sound_button = button("Ses: kapalı", tools, toggle_sound)
	if OS.get_name() not in ["Android", "iOS"]:
		button("Tam ekran", tools, toggle_fullscreen)
	button("Bu Mac'teki sunucu", tools, func(): address.text = "http://127.0.0.1:8080"; connect_account())
	muted_label("Telefonda ortak HTTPS sunucu adresini kullan. Yerel adres yalnız bu Mac içindir.", network_panel, 13)
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
	action_bar.add_theme_constant_override("h_separation", 6)
	action_bar.add_theme_constant_override("v_separation", 6)
	layout.add_child(action_bar)
	action_bar.visible = false
	nav_bar = HBoxContainer.new()
	nav_bar.add_theme_constant_override("separation", 6)
	layout.add_child(nav_bar)
	for entry in [["play", "Oyun"], ["collection", "Koleksiyon"], ["deck", "Deste"], ["settings", "Ayarlar"]]:
		var tab_button = Button.new()
		tab_button.text = entry[1]
		tab_button.custom_minimum_size.y = 52
		tab_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_button.add_theme_font_size_override("font_size", 16)
		tab_button.pressed.connect(open_tab.bind(entry[0]))
		nav_bar.add_child(tab_button)
		nav_buttons[entry[0]] = tab_button
	save_dialog = FileDialog.new()
	save_dialog.use_native_dialog = OS.get_name() not in ["Android", "iOS"]
	save_dialog.access = FileDialog.ACCESS_FILESYSTEM
	save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	save_dialog.file_selected.connect(func(path: String):
		var file = FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			notice.text = "Dosya kaydedilemedi."
		else:
			file.store_string(save_text)
			file.close()
			notice.text = "Dosya kaydedildi.")
	add_child(save_dialog)

func open_tab(tab: String) -> void:
	if tab == "settings":
		network_panel.get_parent().visible = not network_panel.get_parent().visible
		return
	network_panel.get_parent().visible = false
	if busy:
		return
	selected = []
	focus = {}
	if tab == "collection":
		show_collection()
	elif tab == "deck":
		if account.is_empty():
			notice.text = "Deste kurmak için önce sunucuya bağlan."
			return
		gallery_open = false
		view = "deck"
		render()
	else:
		gallery_open = false
		view = "lobby"
		render()

func update_nav() -> void:
	var active = "collection" if gallery_open else ("deck" if view == "deck" else "play")
	for key in nav_buttons:
		var tab_button: Button = nav_buttons[key]
		var on = key == active
		tab_button.add_theme_stylebox_override("normal", box(sk("tab_active") if on else SURFACE, GOLD if on else sk("border"), 2 if on else 1, 9, 8))
		tab_button.add_theme_color_override("font_color", sk("button_text_hi") if on else sk("quote"))

func toggle_sound() -> void:
	muted = not muted
	sound_button.text = "Ses: kapalı" if muted else "Ses: açık"
	notice.text = "Ses kapalı" if muted else "Ses açık"

func ensure_local_server() -> void:
	# Development convenience only: phones and exported builds use a hosted server.
	if not OS.has_feature("editor") or OS.get_name() not in ["macOS", "Linux", "Windows"]:
		return
	if endpoint != "http://127.0.0.1:8080" and endpoint != "http://localhost:8080":
		return
	var health = await api("health")
	if health.get("ready", false):
		return
	notice.text = "Bu Mac'teki oyun sunucusu başlatılıyor…"
	var candidates = ["/opt/homebrew/bin/node", "/usr/local/bin/node", "/usr/bin/node"]
	for candidate in candidates:
		if FileAccess.file_exists(candidate):
			local_server_pid = OS.create_process(candidate, [ProjectSettings.globalize_path("res://server/http.js")])
			break
	if local_server_pid == -1:
		return
	for attempt in range(15):
		await get_tree().create_timer(0.3).timeout
		var result = await api("health")
		if result.get("ready", false):
			return

func clear_content() -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()

func persist_session() -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("account", "endpoint", endpoint)
	cfg.set_value("account", "cookie", cookie)
	cfg.save(SESSION_FILE)

func offline_save_path() -> String:
	var dir = OS.get_environment("DESTAN_SESSION_DIR")
	return dir.path_join("destan-offline.json") if not dir.is_empty() else "user://destan-offline.json"

func start_offline() -> Dictionary:
	# Sunucuya ulaşılamadığında oyun cihazın içindeki kural motoruyla sürer.
	if offline_service == null:
		offline_service = OfflineService.new(data, offline_save_path())
	offline_mode = true
	cookie = ""
	return offline_service.handle("session", HTTPClient.METHOD_POST, {})

func enter_offline() -> void:
	if busy:
		return
	var result = start_offline()
	accept_account(result)
	notice.text = "Çevrimdışı mod · Bot ve yolculukla oyna. Çevrimiçi için ayarlardan Bağlan."
	network_panel.get_parent().visible = false
	if is_instance_valid(poll):
		poll.start()
	await refresh()
	render()
	updated.emit()

func api(path: String, method: int = HTTPClient.METHOD_GET, body: Dictionary = {}) -> Dictionary:
	if offline_mode:
		return offline_service.handle(path, method, body)
	var request_node = HTTPRequest.new()
	request_node.timeout = request_timeout
	add_child(request_node)
	var headers = PackedStringArray(["Content-Type: application/json"])
	if not OS.has_feature("web"):
		headers.append("Origin: " + endpoint)
	if not cookie.is_empty() and not OS.has_feature("web"):
		headers.append("Cookie: " + cookie)
	if not account.is_empty():
		headers.append("X-Destan-Csrf: " + account.csrf)
	var encoded = "" if method == HTTPClient.METHOD_GET else JSON.stringify(body)
	var error = request_node.request(endpoint + "/api/" + path, headers, method, encoded)
	if error != OK:
		request_node.queue_free()
		return {"error": "Bağlantı başlatılamadı.", "network": true}
	var response: Array = await request_node.request_completed
	request_node.queue_free()
	if response[0] != HTTPRequest.RESULT_SUCCESS:
		return {"error": "Sunucuya ulaşılamadı: " + endpoint + ". Ayarlar üzerinden yeniden bağlan.", "network": true}
	for header in response[2]:
		if str(header).to_lower().begins_with("set-cookie:"):
			cookie = str(header).substr(11).strip_edges().split(";")[0]
			persist_session()
	var parsed = JSON.parse_string(response[3].get_string_from_utf8())
	if not parsed is Dictionary:
		return {"error": "Sunucu yanıtı geçersiz."}
	if response[1] >= 400:
		parsed["http_status"] = response[1]
	return parsed

func valid_endpoint(value: String) -> bool:
	return (value.begins_with("https://") or value.begins_with("http://127.0.0.1:") or value.begins_with("http://localhost:")) and not "@" in value and not "?" in value and not "#" in value and value.trim_prefix("https://").trim_prefix("http://").count("/") == 0

func connect_account() -> void:
	if busy:
		return
	var next = address.text.strip_edges().trim_suffix("/")
	if not valid_endpoint(next):
		notice.text = "HTTPS veya yerel http://127.0.0.1:PORT adresi kullan."
		if account.is_empty():
			await enter_offline()
		return
	if next != endpoint or offline_mode:
		cookie = "" if next != endpoint else cookie
		account = {}
		room = {}
		pending = {}
		recovery_key = ""
	offline_mode = false
	endpoint = next
	busy = true
	notice.text = "Bağlanılıyor…"
	# Old desktop tests saved an ephemeral localhost port into the real account.
	# Only recover unavailable local addresses; never replace a hosted endpoint.
	if OS.has_feature("editor") and OS.get_environment("DESTAN_SERVER_URL").is_empty() and (endpoint.begins_with("http://127.0.0.1:") or endpoint.begins_with("http://localhost:")) and endpoint != "http://127.0.0.1:8080" and endpoint != "http://localhost:8080":
		var health = await api("health")
		if not health.get("ready", false):
			endpoint = "http://127.0.0.1:8080"
			address.text = endpoint
			cookie = ""
			account = {}
			room = {}
			pending = {}
			recovery_key = ""
	await ensure_local_server()
	request_timeout = 5.0
	var result = await api("session", HTTPClient.METHOD_POST)
	request_timeout = 12.0
	if result.get("network", false) and OS.get_environment("DESTAN_NO_OFFLINE").is_empty():
		busy = false
		await enter_offline()
		return
	busy = false
	if result.has("error"):
		notice.text = result.error
		network_panel.get_parent().visible = true
		render()
		updated.emit()
		return
	accept_account(result)
	notice.text = "Çevrimdışı mod · Bot ve yolculukla oyna" if offline_mode else "Bağlandı · Oynamaya hazırsın"
	network_panel.get_parent().visible = false
	if FileAccess.file_exists(PENDING_FILE):
		var saved = JSON.parse_string(FileAccess.get_file_as_string(PENDING_FILE))
		if saved is Dictionary and saved.get("accountId") == account.id and saved.get("endpoint") == endpoint:
			pending = saved
	await refresh()
	render()

func accept_account(result: Dictionary) -> void:
	if result.has("recoveryKey"):
		recovery_key = result.recoveryKey
		result.erase("recoveryKey")
	account = result
	account_line.text = "%s · %d puan · %d altın · %d toz" % [account.league, account.mmr, account.profile.gold, account.profile.dust]

func refresh() -> void:
	if busy or account.is_empty():
		return
	busy = true
	if not pending.is_empty():
		var retry = await api(pending.path, HTTPClient.METHOD_POST, pending.body)
		if not retry.has("network"):
			clear_pending()
		if retry.has("error"):
			notice.text = retry.error
	var result = await api("me")
	if result.has("error"):
		busy = false
		notice.text = result.error
		updated.emit()
		return
	accept_account(result)
	if account.matchId != null:
		var next = await api("matches/" + str(account.matchId))
		if not next.has("error"):
			var changed = room.is_empty() or room.get("version") != next.version or room.get("status") != next.status
			room = next
			server_offset = float(next.serverNow) - Time.get_unix_time_from_system() * 1000.0
			busy = false
			if changed:
				selected = []
				focus = {}
				render()
	else:
		busy = false
	updated.emit()

func clear_pending() -> void:
	pending = {}
	if FileAccess.file_exists(PENDING_FILE):
		if OS.has_feature("web"):
			# Do not unlink while the browser's asynchronous IDBFS sync reads it.
			var file = FileAccess.open(PENDING_FILE, FileAccess.WRITE)
			if file != null:
				file.store_string("{}")
				file.close()
		else:
			DirAccess.remove_absolute(PENDING_FILE)

func mutate(path: String, body: Dictionary, retryable: bool = false) -> void:
	if busy or account.is_empty():
		return
	if not pending.is_empty():
		notice.text = "Önceki işlem sunucuyla eşitleniyor. Bağlantının dönmesini bekle."
		return
	busy = true
	if retryable:
		body["requestId"] = Crypto.new().generate_random_bytes(16).hex_encode()
		pending = {"accountId": account.id, "endpoint": endpoint, "path": path, "body": body}
		var file = FileAccess.open(PENDING_FILE, FileAccess.WRITE)
		if file == null:
			busy = false
			notice.text = "Hamle güvenli kaydedilemedi."
			return
		file.store_string(JSON.stringify(pending))
		file.close()
	var result = await api(path, HTTPClient.METHOD_POST, body)
	if retryable and not result.has("network"):
		clear_pending()
	busy = false
	if result.has("error"):
		notice.text = result.error
		await refresh()
		return
	if result.has("account"):
		accept_account(result.account)
		if result.has("rewards"):
			last_pack = result.rewards
			notice.text = "Paket açıldı."
	elif result.has("state"):
		room = result
		server_offset = float(result.serverNow) - Time.get_unix_time_from_system() * 1000.0
	elif result.has("profile"):
		accept_account(result)
	selected = []
	focus = {}
	mulligan_indices = []
	play_sound()
	render()
	updated.emit()

func move(action: Dictionary) -> void:
	if room.is_empty() or not pending.is_empty():
		return
	if action.type == "attack":
		last_attack = {"uid": int(action.uid)}
	await mutate("matches/" + room.id + "/actions", {"version": room.version, "action": action}, true)


func resize_layout() -> void:
	if view == "deck" and not deck_counts.is_empty():
		custom_deck = builder_deck()
	if OS.get_name() in ["Android", "iOS"] and is_instance_valid(shell_margin):
		var safe = DisplayServer.get_display_safe_area()
		var screen = DisplayServer.screen_get_size()
		if screen.x > 0 and screen.y > 0:
			var scale = get_viewport_rect().size / Vector2(screen)
			shell_margin.add_theme_constant_override("margin_left", maxi(12, int(safe.position.x * scale.x)))
			shell_margin.add_theme_constant_override("margin_right", maxi(12, int((screen.x - safe.end.x) * scale.x)))
			shell_margin.add_theme_constant_override("margin_top", maxi(12, int(safe.position.y * scale.y)))
			shell_margin.add_theme_constant_override("margin_bottom", maxi(12, int((screen.y - safe.end.y) * scale.y)))
	compact = get_viewport_rect().size.x < 700
	if is_instance_valid(content):
		render()


func render() -> void:
	clear_content()
	unit_nodes = {}
	hero_nodes = {}
	for child in action_bar.get_children():
		action_bar.remove_child(child)
		child.queue_free()
	action_bar.visible = false
	var in_match = not gallery_open and view != "deck" and not room.is_empty()
	nav_bar.visible = not in_match
	update_nav()
	if gallery_open:
		render_collection()
	elif view == "deck" and not account.is_empty():
		render_deck_builder()
	elif room.is_empty():
		render_lobby()
	else:
		render_match()

func deck_payload() -> Array:
	return custom_deck if use_custom else data.decks.starter.cards

func chapters_done() -> int:
	var count = 0
	for chapter in data.chapters:
		if account.profile.chapterRewards.has(chapter.id):
			count += 1
	return count

func next_chapter_id() -> int:
	for chapter in data.chapters:
		if not account.profile.chapterRewards.has(chapter.id):
			return int(chapter.id)
	return int(data.chapters.back().id)

func render_lobby() -> void:
	if account.is_empty():
		var offline = panel(content, SURFACE, GOLD, 1, 16, 14)
		heading("Bağlantı bekleniyor", offline, 24)
		muted_label("Oyun sunucusuna ulaşılamıyor. Sunucu adresini Ayarlar sekmesinden kontrol et.", offline, 15)
		primary_button("Yeniden bağlan", offline, connect_account)
		return
	var done = chapters_done()
	var hero = panel(content, sk("hero"), GOLD, 1, 16, 14)
	heading("ANADOLU'DA YOLCULUK", hero, 24)
	muted_label("Efsaneleri kartlara dök, Unutuş'un gölgelerini yen.", hero, 15)
	primary_button("Hızlı maç · Bot ile oyna", hero, func(): mutate("solo", {"chapterId": 0, "deck": deck_payload()}))
	muted_label("Aktif deste: %s" % ("Kendi destem" if use_custom else str(data.decks.starter.name)), hero, 13)
	var next_id = next_chapter_id()
	var chapter = data.chapters[next_id - 1]
	var story = panel(content)
	heading("HİKÂYE · %d/%d BÖLÜM" % [done, data.chapters.size()], story, 18)
	label("%d. %s" % [chapter.id, chapter.title], story, 21)
	muted_label("%s · Rakip: %s" % [chapter.place, chapter.enemy], story, 14)
	var quote = label("“%s”" % chapter.dialogue, story, 15)
	quote.add_theme_color_override("font_color", sk("quote"))
	muted_label("Görev: " + str(chapter.task), story, 14)
	primary_button("Hikâyeye devam et" if done > 0 else "Hikâyeye başla", story, func(): mutate("solo", {"chapterId": next_id}))
	var picker = HBoxContainer.new()
	picker.add_theme_constant_override("separation", 6)
	story.add_child(picker)
	chapter_select = OptionButton.new()
	chapter_select.custom_minimum_size.y = 48
	chapter_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chapter_select.fit_to_longest_item = false
	chapter_select.clip_text = true
	for entry in data.chapters:
		var title = "%d. %s" % [entry.id, entry.title]
		if account.profile.chapterRewards.has(entry.id):
			title += " (tamam)"
		chapter_select.add_item(title, int(entry.id))
		chapter_select.set_item_disabled(chapter_select.item_count - 1, entry.id > 1 and not account.profile.chapterRewards.has(entry.id - 1))
	chapter_select.select(next_id - 1)
	picker.add_child(chapter_select)
	button("Oyna", picker, func(): mutate("solo", {"chapterId": chapter_select.get_selected_id()}))
	var friends = panel(content)
	heading("ARKADAŞINLA OYNA", friends, 18)
	button("Arkadaş odası oluştur", friends, func(): mutate("rooms", {"deck": deck_payload()}))
	var join_row = HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 6)
	friends.add_child(join_row)
	room_code = LineEdit.new()
	room_code.placeholder_text = "8 karakter oda kodu"
	room_code.max_length = 8
	room_code.custom_minimum_size = Vector2(0, 48)
	room_code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_row.add_child(room_code)
	button("Odaya katıl", join_row, func(): mutate("join", {"code": room_code.text.strip_edges().to_upper(), "deck": deck_payload()}))
	var league = panel(content)
	heading("LİG · %s · %d puan" % [account.league, account.mmr], league, 18)
	var unlocked = account.profile.chapterRewards.has(10)
	if not unlocked:
		muted_label("Lig, hikâyenin 10. bölümünü bitirince açılır.", league, 14)
	if account.queued:
		label("Rakip aranıyor…", league, 16)
		button("Lig aramasını iptal et", league, func(): mutate("queue/cancel", {}))
	else:
		button("Lig ara", league, func(): mutate("queue", {"deck": deck_payload()}), not unlocked)
	var keep = panel(content)
	heading("HESABI KORU", keep, 18)
	muted_label("Kurtarma anahtarı hesaba erişim verir. Güvenli bir yere kaydet; yalnız ilk oluşturulduğunda indirilir.", keep, 14)
	if not recovery_key.is_empty():
		button("Kurtarma anahtarını dosyaya kaydet", keep, func(): save_file(recovery_key + "\n", "destan-kurtarma-anahtari.txt"))
	recover_input = LineEdit.new()
	recover_input.secret = true
	recover_input.custom_minimum_size.y = 48
	recover_input.placeholder_text = "Mevcut hesabın kurtarma anahtarı"
	keep.add_child(recover_input)
	button("Hesabı kurtar", keep, recover_account)
	if not account.history.is_empty():
		var history = panel(content)
		heading("SON MAÇLAR", history, 18)
		for match_entry in account.history:
			button("%s · %s" % [match_entry.kind, match_entry.result], history, func(): open_match(match_entry.id))

func recover_account() -> void:
	if busy:
		return
	busy = true
	var result = await api("recover", HTTPClient.METHOD_POST, {"key": recover_input.text.strip_edges()})
	busy = false
	if result.has("error"):
		notice.text = result.error
		return
	recovery_key = ""
	room = {}
	clear_pending()
	accept_account(result)
	await refresh()
	render()

func open_match(id: String) -> void:
	if busy:
		return
	busy = true
	var result = await api("matches/" + id)
	busy = false
	if result.has("error"):
		notice.text = result.error
	else:
		room = result
		render()


func unit_attack(unit: Dictionary) -> int:
	var attack = int(unit.get("attack", cards[int(unit.id)].attack)) + int(unit.get("tempAttack", 0))
	if int(unit.id) == 21 and not room.is_empty() and room.get("state") != null:
		for player in room.state.players:
			if player.board.any(func(member): return int(member.uid) == int(unit.uid)):
				attack += player.board.size() - 1
	return maxi(0, attack)

func mini_card(id: int, parent: Node, width: float, unit: Dictionary = {}, tap: Callable = Callable(), state: String = "", corner: String = "", full: bool = false) -> PanelContainer:
	var card: Dictionary = cards[id]
	var rim: Color = RARITY[card.rarity]
	var edge = rim
	var edge_width = 2
	if state == "ready":
		edge = sk("ready_edge")
		edge_width = 3
	elif state == "picked":
		edge = sk("white")
		edge_width = 3
	var wrap = PanelContainer.new()
	wrap.custom_minimum_size = Vector2(width, 0)
	wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	wrap.add_theme_stylebox_override("panel", box(sk("card_back"), edge, edge_width, 10, 3))
	if state == "dim":
		wrap.modulate = Color(1, 1, 1, 0.5)
	elif state == "tired":
		wrap.modulate = Color(1, 1, 1, 0.72)
	parent.add_child(wrap)
	if not unit.is_empty() and unit.has("uid"):
		unit_nodes[int(unit.uid)] = wrap
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	wrap.add_child(column)
	var small = width < 90
	var art_width = width - 6.0
	var art_holder = Control.new()
	art_holder.custom_minimum_size = Vector2(art_width, art_width * 0.667)
	art_holder.clip_contents = true
	column.add_child(art_holder)
	var art = TextureRect.new()
	art.texture = texture_for(id)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_holder.add_child(art)
	var cost = PanelContainer.new()
	cost.add_theme_stylebox_override("panel", box(TYPE_COLOR[card.type], sk("button_text"), 1, 13, 1))
	cost.custom_minimum_size = Vector2(24, 24) if small else Vector2(28, 28)
	cost.position = Vector2(3, 3)
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_holder.add_child(cost)
	var cost_label = Label.new()
	cost_label.text = str(int(card.cost))
	cost_label.add_theme_font_size_override("font_size", 13 if small else 15)
	cost_label.add_theme_color_override("font_color", sk("white"))
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost.add_child(cost_label)
	if corner != "":
		var corner_holder = PanelContainer.new()
		corner_holder.add_theme_stylebox_override("panel", box(Color(0, 0, 0, 0.7), Color(0, 0, 0, 0), 0, 8, 3))
		corner_holder.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		corner_holder.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		corner_holder.offset_left = -4
		corner_holder.offset_right = -4
		corner_holder.offset_top = 4
		corner_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art_holder.add_child(corner_holder)
		var corner_label = Label.new()
		corner_label.text = corner
		corner_label.add_theme_font_size_override("font_size", 13)
		corner_label.add_theme_color_override("font_color", sk("white"))
		corner_holder.add_child(corner_label)
	var tags: Array = []
	for keyword in unit.get("keywords", card.keywords):
		tags.append(str(keyword))
	if bool(unit.get("shield", false)):
		tags.append("Kalkan")
	if not tags.is_empty():
		var tag = PanelContainer.new()
		tag.add_theme_stylebox_override("panel", box(Color(0, 0, 0, 0.68), Color(0, 0, 0, 0), 0, 4, 2))
		tag.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		tag.grow_vertical = Control.GROW_DIRECTION_BEGIN
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art_holder.add_child(tag)
		var tag_label = Label.new()
		tag_label.text = " · ".join(tags)
		tag_label.add_theme_font_size_override("font_size", 10 if small else 12)
		tag_label.add_theme_color_override("font_color", sk("card_tag"))
		tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag_label.clip_text = true
		tag.add_child(tag_label)
	var name_size = 11 if small else (13 if width < 140 else 15)
	var name_label = Label.new()
	name_label.text = card.name
	name_label.add_theme_font_size_override("font_size", name_size)
	name_label.add_theme_color_override("font_color", sk("card_name"))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.max_lines_visible = 2
	name_label.custom_minimum_size = Vector2(art_width, name_size * 2.5)
	column.add_child(name_label)
	if full:
		var kind = Label.new()
		kind.text = "%s · %s" % [TYPE_NAME[card.type], RARITY_NAME[card.rarity]]
		kind.add_theme_font_size_override("font_size", 12)
		kind.add_theme_color_override("font_color", rim)
		kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(kind)
		var effect = Label.new()
		effect.text = card.text
		effect.add_theme_font_size_override("font_size", 12)
		effect.add_theme_color_override("font_color", sk("card_text"))
		effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		effect.max_lines_visible = 5
		effect.custom_minimum_size = Vector2(art_width, 12 * 6.4)
		column.add_child(effect)
	var stats = HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 4)
	column.add_child(stats)
	var stat_size = 12 if small else 14
	if card.type == "warrior":
		var hp = int(unit.get("hp", card.hp))
		var max_hp = int(unit.get("maxHp", card.hp))
		var attack = unit_attack(unit) if not unit.is_empty() else int(card.attack)
		chip(str(attack), stats, sk("stat_attack"), stat_size)
		chip(str(hp), stats, sk("stat_health_hurt") if hp < max_hp else sk("stat_health"), stat_size)
	else:
		chip(TYPE_NAME[card.type].to_upper(), stats, TYPE_COLOR[card.type], stat_size - 1)
	if tap.is_valid():
		var overlay = Button.new()
		overlay.flat = true
		overlay.text = ""
		overlay.tooltip_text = "%s · %s" % [card.name, card.text]
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		overlay.set_meta("card_overlay", true)
		for style_name in ["normal", "hover", "pressed", "disabled"]:
			overlay.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
		overlay.add_theme_stylebox_override("focus", box(Color(0, 0, 0, 0), sk("white"), 2, 10, 0))
		overlay.pressed.connect(tap)
		wrap.add_child(overlay)
	return wrap

func inspect_card(id: int, unit: Dictionary = {}) -> void:
	var card: Dictionary = cards[id]
	var dialog = AcceptDialog.new()
	dialog.title = card.name
	var lines = ["%d enerji · %s · %s" % [int(card.cost), TYPE_NAME[card.type], RARITY_NAME[card.rarity]]]
	if card.type == "warrior":
		lines.append("Saldırı %d · Can %d" % [unit_attack(unit) if not unit.is_empty() else int(card.attack), int(unit.get("hp", card.hp))])
	lines.append(str(card.text))
	dialog.dialog_text = "\n".join(lines)
	dialog.ok_button_text = "Tamam"
	dialog.min_size = Vector2i(mini(520, int(get_viewport_rect().size.x) - 32), 200)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered_clamped(Vector2i(mini(520, int(get_viewport_rect().size.x) - 32), 260), 0.9)


func select_actions(options: Array) -> void:
	selected = options
	render()

func action_name(action: Dictionary) -> String:
	match action.type:
		"end": return "Turu bitir"
		"mulligan": return "Bu elle başla"
		"scry": return "Deste altına at" if action.bottom else "Üstte bırak"
		"discard": return "At: " + cards[int(room.state.players[0].hand[int(action.index)])].name
		"play", "attack":
			var target = str(action.get("target", ""))
			if target == "hero:0": return "Kendine"
			if target == "hero:1": return "Rakip kahraman"
			if target.begins_with("unit:"):
				for player in room.state.players:
					for unit in player.board:
						if target == "unit:" + str(int(unit.uid)): return "Hedef: " + cards[int(unit.id)].name
			if target.begins_with("grave:"):
				for unit in room.state.players[0].grave:
					if target == "grave:" + str(int(unit.uid)):
						return "Dirilt: " + cards[int(unit.id)].name
			return "Oyna" if action.type == "play" else "Saldır"
	return action.type

func stat_bar(parent: Node, who: String, player: Dictionary, extra: String) -> void:
	var bar = PanelContainer.new()
	bar.add_theme_stylebox_override("panel", box(sk("bar"), sk("border"), 1, 10, 6))
	parent.add_child(bar)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	bar.add_child(row)
	hero_nodes[0 if who == "SEN" else 1] = bar
	var portrait = PanelContainer.new()
	portrait.custom_minimum_size = Vector2(38, 38)
	portrait.add_theme_stylebox_override("panel", box(sk("surface_hi"), GOLD, 2, 19, 0))
	row.add_child(portrait)
	var initial = label(who.substr(0, 1), portrait, 18)
	initial.add_theme_color_override("font_color", GOLD)
	initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var gem = PanelContainer.new()
	gem.custom_minimum_size = Vector2(38, 38)
	gem.add_theme_stylebox_override("panel", box(sk("hearts") if int(player.hp) > 8 else sk("hearts_low"), sk("white"), 2, 19, 0))
	row.add_child(gem)
	var hp_label = label(str(int(player.hp)), gem, 18)
	hp_label.add_theme_color_override("font_color", sk("white"))
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var full = int(player.energy)
	var crystals = label("◆".repeat(full) + "◇".repeat(maxi(0, int(player.maxEnergy) - full)), row, 14)
	crystals.autowrap_mode = TextServer.AUTOWRAP_OFF
	crystals.add_theme_color_override("font_color", Color("6cc3ff"))
	crystals.tooltip_text = "Enerji %d/%d" % [full, int(player.maxEnergy)]
	chip(extra, row, sk("disabled_fill"), 13)
	if player.traps.size() > 0:
		chip("Tuzak %d" % player.traps.size(), row, TYPE_COLOR["trap"], 13)

func lane(parent: Node, units: Array, mine_side: bool, legal: Array) -> void:
	var holder = PanelContainer.new()
	var table_style = box(sk("lane"), sk("gold_lo"), 2, 14, 4)
	table_style.shadow_color = Color(0, 0, 0, 0.45)
	table_style.shadow_size = 6
	holder.add_theme_stylebox_override("panel", table_style)
	holder.custom_minimum_size.y = 126 if not units.is_empty() else 64
	parent.add_child(holder)
	if units.is_empty():
		var empty = muted_label("Saha boş", holder, 14)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		return
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	holder.add_child(row)
	var avail = get_viewport_rect().size.x - 24.0 - 8.0
	var width = clampf((avail - 4.0 * (units.size() - 1)) / units.size(), 56.0, 84.0)
	for unit in units:
		var uid = int(unit.uid)
		var options = legal.filter(func(action): return action.type == "attack" and int(action.uid) == uid)
		var targeted = selected.any(func(action): return str(action.get("target", "")) == "unit:" + str(uid))
		var state = ""
		if mine_side:
			state = "ready" if not options.is_empty() else "tired"
		if targeted:
			state = "picked"
		var corner = "Z" if int(unit.get("skipUntil", 0)) > int(room.state.turn) else ""
		mini_card(int(unit.id), row, width, unit, func():
			if targeted:
				var hit = selected.filter(func(action): return str(action.get("target", "")) == "unit:" + str(uid))
				move(hit[0])
			elif mine_side and not options.is_empty():
				focus = {"id": int(unit.id), "unit": unit}
				select_actions(options)
			else:
				focus = {"id": int(unit.id), "unit": unit}
				selected = []
				render(), state, corner)

func render_waiting_room() -> void:
	var waiting = panel(content, SURFACE, GOLD, 1, 18, 14)
	heading("ODA KODU", waiting, 18)
	var code = label(str(room.code), waiting, 40)
	code.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	muted_label("Arkadaşın bu kodla katıldığında maç başlayacak.", waiting, 15)
	primary_button("Kodu kopyala", waiting, func(): DisplayServer.clipboard_set(str(room.code)); notice.text = "Oda kodu kopyalandı.")
	button("Lobiye dön", waiting, leave_match)

func result_text(state: Dictionary) -> String:
	if state.winner == null:
		return "BERABERE"
	return "KAZANDIN" if int(state.winner) == 0 else "KAYBETTİN"

func confirm_leave() -> void:
	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = "Maçtan ayrılmak teslim sayılır. Ayrılmak istiyor musun?"
	dialog.ok_button_text = "Teslim ol"
	dialog.cancel_button_text = "Vazgeç"
	dialog.confirmed.connect(func(): dialog.queue_free(); leave_match())
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered_clamped(Vector2i(mini(520, int(get_viewport_rect().size.x) - 32), 260), 0.9)

func render_match() -> void:
	if room.state == null:
		render_waiting_room()
		return
	var state: Dictionary = room.state
	var mine: Dictionary = state.players[0]
	var foe: Dictionary = state.players[1]
	var legal: Array = room.get("actions", [])
	var finished = state.status == "finished"
	run_effects(state)
	content.add_theme_constant_override("separation", 6)
	stat_bar(content, "RAKİP", foe, "El %d" % foe.hand.size())
	lane(content, foe.board, false, legal)
	var banner = PanelContainer.new()
	banner.add_theme_stylebox_override("panel", box(sk("banner"), GOLD if state.active == 0 and not finished else sk("border"), 1, 10, 6))
	content.add_child(banner)
	var banner_box = VBoxContainer.new()
	banner_box.add_theme_constant_override("separation", 2)
	banner.add_child(banner_box)
	if finished:
		var verdict = label(result_text(state), banner_box, 30)
		verdict.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		verdict.add_theme_color_override("font_color", GOLD if state.winner != null and int(state.winner) == 0 else INK)
		turn_clock = null
	else:
		var phase = "Mulligan" if state.status == "mulligan" else ("Kart fazı" if state.phase == "main" else "Saldırı fazı")
		var head = "Tur %d/20 · %s" % [ceili(float(state.turn) / 2), phase] if state.active == 0 else "Rakibin turu…"
		heading(head, banner_box, 16)
		turn_clock = muted_label("", banner_box, 12)
	if int(room.chapterId) > 0 and not finished:
		muted_label("Görev: " + str(data.chapters[int(room.chapterId) - 1].task), banner_box, 12)
	if state.log.size() > 0:
		var last = muted_label(str(state.log[state.log.size() - 1]), banner_box, 12)
		last.add_theme_color_override("font_color", sk("notice"))
	lane(content, mine.board, true, legal)
	stat_bar(content, "SEN", mine, "Deste %d" % mine.deck.size())
	# detail strip
	var detail = panel(content, sk("detail"), sk("border"), 1, 8, 10)
	if finished:
		muted_label("Maç kaydını kaydedip tekrar izleyebilirsin.", detail, 13)
	elif not focus.is_empty():
		var info = cards[int(focus.id)]
		var stats = ""
		if info.type == "warrior":
			var unit: Dictionary = focus.get("unit", {})
			stats = " · SAL %d CAN %d" % [unit_attack(unit) if not unit.is_empty() else int(info.attack), int(unit.get("hp", info.hp))]
		label("%s · %d enerji%s" % [info.name, int(info.cost), stats], detail, 15)
		muted_label(str(info.text) if str(info.text) != "" else ", ".join(info.keywords), detail, 13)
	else:
		muted_label("Bir karta dokun: ayrıntısı ve hamlesi burada.", detail, 13)
	if not selected.is_empty():
		var targets = HFlowContainer.new()
		targets.add_theme_constant_override("h_separation", 6)
		targets.add_theme_constant_override("v_separation", 6)
		detail.add_child(targets)
		for action in selected:
			small_button(action_name(action), targets, func(): move(action))
		small_button("İptal", targets, func(): selected = []; focus = {}; render())
	# hand
	var hand_scroll = ScrollContainer.new()
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hand_scroll.custom_minimum_size.y = 150
	content.add_child(hand_scroll)
	var hand = HBoxContainer.new()
	hand.add_theme_constant_override("separation", 6 if mine.hand.size() <= 4 else -10)
	hand_scroll.add_child(hand)
	var mulligan_open = state.status == "mulligan" and state.active == 0
	for index in mine.hand.size():
		var card_id = int(mine.hand[index])
		var options = legal.filter(func(action): return action.type == "play" and int(action.index) == index)
		var can_mulligan = mulligan_open and not mine.mulliganPinned.has(mine.hand[index])
		var card_state = "dim"
		if mulligan_indices.has(index):
			card_state = "picked"
		elif int(focus.get("hand_index", -1)) == index:
			card_state = "picked"
		elif can_mulligan or not options.is_empty():
			card_state = "ready"
		mini_card(card_id, hand, 96, {}, func():
			if can_mulligan:
				if mulligan_indices.has(index):
					mulligan_indices.erase(index)
				else:
					mulligan_indices.append(index)
				render()
			else:
				focus = {"id": card_id, "hand_index": index}
				selected = options
				render(), card_state, "✓" if mulligan_indices.has(index) else "")
	# action bar
	action_bar.visible = true
	if finished:
		primary_button("Lobiye dön", action_bar, leave_match)
		small_button("Maç kaydı", action_bar, export_replay)
		return
	if state.active == 0:
		for action in legal:
			if action.type == "mulligan":
				var text = "Bu elle başla" if mulligan_indices.is_empty() else "%d kartı değiştir" % mulligan_indices.size()
				primary_button(text, action_bar, func(): move({"type": "mulligan", "indices": mulligan_indices.duplicate()}))
			elif action.type == "end":
				primary_button("Turu bitir", action_bar, func(): move(action))
			elif action.type in ["scry", "discard"]:
				small_button(action_name(action), action_bar, func(): move(action))
	small_button("Teslim ol", action_bar, confirm_leave)

func texture_for(id: int) -> Texture2D:
	if textures.has(id):
		return textures[id]
	var custom = skin_texture("cards/%02d.png" % id)
	if custom != null:
		textures[id] = custom
		return custom
	var first = int((id - 1) / 4) * 4 + 1
	var atlas = AtlasTexture.new()
	atlas.atlas = load("res://kart-prototipi/gorseller/%02d-%02d.png" % [first, first + 3])
	var cell = (id - 1) % 4
	atlas.region = Rect2((cell % 2) * 768, int(cell / 2) * 512, 768, 512)
	textures[id] = atlas
	return atlas


func show_collection() -> void:
	view = "lobby"
	if busy:
		return
	gallery_open = true
	selected = []
	render()

func filter_chip_row(parent: Node, options: Array, current: String, on_pick: Callable) -> void:
	var row = HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	parent.add_child(row)
	for entry in options:
		var key: String = entry[0]
		var pick = small_button(entry[1], row, on_pick.bind(key))
		if key == current:
			pick.add_theme_stylebox_override("normal", box(sk("tab_active"), GOLD, 2, 9, 8))

func card_visible(id: int) -> bool:
	if collection_filter != "all" and cards[id].type != collection_filter:
		return false
	if owned_only and (account.is_empty() or int(account.profile.inventory.get(str(id), 0)) == 0):
		return false
	return true

func render_pack_reveal() -> void:
	var reveal = panel(content, sk("reveal"), GOLD, 2, 12, 12)
	heading("PAKETTEN ÇIKANLAR", reveal, 16)
	var row = HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	reveal.add_child(row)
	for reward in last_pack:
		if reward.get("id") == null:
			chip("+%d toz (kopya)" % int(reward.get("dust", 0)), row, sk("disabled_fill"), 14)
		else:
			var card = cards[int(reward.id)]
			chip(str(card.name), row, RARITY[card.rarity], 14)
	small_button("Kapat", reveal, func(): last_pack = []; render())

func render_collection() -> void:
	var offline = account.is_empty()
	if not offline:
		var wallet = panel(content, sk("hero"), GOLD, 1, 12, 12)
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		wallet.add_child(row)
		chip("● %d altın" % int(account.profile.gold), row, sk("chip_gold"), 14)
		chip("✦ %d toz" % int(account.profile.dust), row, sk("chip_dust"), 14)
		chip("Paket %d" % int(account.profile.freePacks), row, sk("stat_health"), 14)
		var free = int(account.profile.freePacks) > 0
		primary_button("Paket aç · ücretsiz" if free else "Paket aç · 300 altın", wallet, func(): mutate("collection/pack", {}, true), not free and int(account.profile.gold) < 300)
	if not last_pack.is_empty():
		render_pack_reveal()
	var owned = 0
	if not offline:
		for key in account.profile.inventory:
			if int(account.profile.inventory[key]) > 0:
				owned += 1
	heading("KOLEKSİYON · %d/40 kart" % owned, content, 18)
	filter_chip_row(content, [["all", "Tümü"], ["warrior", "Savaşçı"], ["spell", "Büyü"], ["trap", "Tuzak"]], collection_filter, func(key): collection_filter = key; render())
	if not offline:
		var only = small_button("Yalnız sahip olduklarım: " + ("açık" if owned_only else "kapalı"), content, func(): owned_only = not owned_only; render())
	var columns = 3 if compact else 5
	var grid = GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 10)
	content.add_child(grid)
	var width = floorf((get_viewport_rect().size.x - 24.0 - 6.0 * (columns - 1)) / columns) - 6.0
	width = minf(width, 150.0)
	for id in range(1, 41):
		if not card_visible(id):
			continue
		var cell = VBoxContainer.new()
		cell.add_theme_constant_override("separation", 3)
		grid.add_child(cell)
		var card: Dictionary = cards[id]
		var amount = int(account.profile.inventory.get(str(id), 0)) if not offline else 1
		mini_card(id, cell, width, {}, func(): inspect_card(id), "" if amount > 0 else "dim", "x%d" % amount if amount > 1 else "")
		if offline:
			continue
		var cap = 1 if card.rarity == "legendary" else 2
		var craft_cost = {"common": 40, "rare": 100, "legendary": 400}[card.rarity]
		var buttons = HBoxContainer.new()
		buttons.add_theme_constant_override("separation", 3)
		cell.add_child(buttons)
		var make = small_button("Üret", buttons, func(): mutate("collection/craft", {"cardId": id}, true), amount >= cap or int(account.profile.dust) < craft_cost)
		make.custom_minimum_size = Vector2(0, 40)
		make.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		make.autowrap_mode = TextServer.AUTOWRAP_OFF
		make.clip_text = true
		make.tooltip_text = "%d toz" % craft_cost
		var shred = small_button("Parçala", buttons, func(): mutate("collection/dismantle", {"cardId": id}, true), amount == 0)
		shred.custom_minimum_size = Vector2(0, 40)
		shred.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		shred.autowrap_mode = TextServer.AUTOWRAP_OFF
		shred.clip_text = true
		shred.add_theme_font_size_override("font_size", 11)
		make.add_theme_font_size_override("font_size", 12)
		if account.profile.chapterRewards.has(10) and int(account.profile.archiveLeft) > 0:
			var pick = small_button("Arşivden seç", cell, func(): mutate("collection/archive", {"cardId": id}, true), amount > 0)
			pick.custom_minimum_size = Vector2(0, 40)
			pick.add_theme_font_size_override("font_size", 12)

func builder_deck() -> Array:
	var deck: Array = []
	var ids = deck_counts.keys()
	ids.sort()
	for id in ids:
		for _copy in int(deck_counts[id]):
			deck.append(int(id))
	return deck

func render_deck_builder() -> void:
	view = "deck"
	if deck_counts.is_empty():
		for id in custom_deck:
			deck_counts[int(id)] = int(deck_counts.get(int(id), 0)) + 1
		for id in deck_counts.keys():
			deck_counts[id] = mini(int(deck_counts[id]), int(account.profile.inventory.get(str(id), 0)))
	var ui: Dictionary = {"labels": {}}
	var head = panel(content, sk("hero"), GOLD, 1, 12, 12)
	heading("DESTEN", head, 18)
	muted_label("Sahip olduğun kartlardan tam 20 kart seç.", head, 14)
	deck_total = label("", head, 22)
	filter_chip_row(content, [["all", "Tümü"], ["warrior", "Savaşçı"], ["spell", "Büyü"], ["trap", "Tuzak"]], collection_filter, func(key): collection_filter = key; render())
	var primary = primary_button("Desteyi kullan", action_bar, func():
		var deck = builder_deck()
		if deck.size() != 20:
			notice.text = "Deste tam 20 kart olmalı."
			return
		custom_deck = deck
		use_custom = true
		deck_counts = {}
		view = "lobby"
		notice.text = "Destenin kaydedildi, maçlarda kullanılacak."
		render())
	action_bar.visible = true
	small_button("Başlangıç destesi", action_bar, func():
		use_custom = false
		custom_deck = data.decks.starter.cards.duplicate()
		deck_counts = {}
		view = "lobby"
		render())
	var update = func():
		var total = builder_deck().size()
		deck_total.text = "%d/20 kart" % total
		deck_total.add_theme_color_override("font_color", sk("ok_text") if total == 20 else sk("warn_text"))
		primary.disabled = total != 20
		for id in ui.labels:
			ui.labels[id].text = str(int(deck_counts.get(id, 0)))
	for id in range(1, 41):
		var owned = int(account.profile.inventory.get(str(id), 0))
		if owned == 0 or not card_visible(id):
			continue
		var card: Dictionary = cards[id]
		var row = PanelContainer.new()
		row.add_theme_stylebox_override("panel", box(SURFACE, RARITY[card.rarity], 1, 10, 5))
		content.add_child(row)
		var line = HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		row.add_child(line)
		var art = TextureRect.new()
		art.texture = texture_for(id)
		art.custom_minimum_size = Vector2(66, 44)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.clip_contents = true
		line.add_child(art)
		var text_box = VBoxContainer.new()
		text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_box.add_theme_constant_override("separation", 0)
		line.add_child(text_box)
		var title = label("%s" % card.name, text_box, 15)
		title.autowrap_mode = TextServer.AUTOWRAP_OFF
		title.clip_text = true
		var sub = "%d enerji · %s" % [int(card.cost), TYPE_NAME[card.type]]
		if card.type == "warrior":
			sub += " · %d/%d" % [int(card.attack), int(card.hp)]
		var sub_label = muted_label(sub, text_box, 12)
		sub_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		sub_label.clip_text = true
		var minus = Button.new()
		minus.text = "−"
		minus.custom_minimum_size = Vector2(44, 44)
		line.add_child(minus)
		var count = Label.new()
		count.custom_minimum_size.x = 22
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.add_child(count)
		ui.labels[id] = count
		var plus = Button.new()
		plus.text = "+"
		plus.custom_minimum_size = Vector2(44, 44)
		line.add_child(plus)
		minus.pressed.connect(func():
			deck_counts[id] = maxi(0, int(deck_counts.get(id, 0)) - 1)
			update.call())
		plus.pressed.connect(func():
			if int(deck_counts.get(id, 0)) < owned and builder_deck().size() < 20:
				deck_counts[id] = int(deck_counts.get(id, 0)) + 1
				update.call())
	update.call()

func leave_match() -> void:
	if busy:
		return
	busy = true
	var result = await api("matches/" + room.id + "/leave", HTTPClient.METHOD_POST)
	busy = false
	if result.has("error"):
		notice.text = result.error
	else:
		room = {}
		accept_account(result)
		render()


func save_file(text: String, filename: String) -> void:
	save_text = text
	save_dialog.current_file = filename
	save_dialog.popup_centered_ratio(0.7)

func export_replay() -> void:
	if busy or room.is_empty() or room.status != "finished":
		notice.text = "Maç kaydı maç tamamlandığında açılır."
		return
	busy = true
	var result = await api("matches/" + room.id + "/replay")
	busy = false
	if result.has("error"):
		notice.text = result.error
	else:
		save_file(JSON.stringify(result, "  "), "destan-mac-kaydi.json")

func toggle_fullscreen() -> void:
	var mode = DisplayServer.window_get_mode()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if mode == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		selected = []
		focus = {}
		render()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_F11 or event.keycode == KEY_F and event.is_command_or_control_pressed():
		toggle_fullscreen()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_S and event.is_command_or_control_pressed():
		export_replay()
		get_viewport().set_input_as_handled()

const SOUNDS = {"play": [520.0, 0.14, 0.6], "hit": [200.0, 0.16, -0.7], "turn": [660.0, 0.22, 0.5], "win": [520.0, 0.6, 1.2], "lose": [330.0, 0.6, -0.9]}

func play_sound(kind: String = "play") -> void:
	if muted:
		return
	var spec: Array = SOUNDS.get(kind, SOUNDS["play"])
	var rate = 22050
	var count = int(rate * float(spec[1]))
	var sound = AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = rate
	var samples = PackedByteArray()
	samples.resize(count * 2)
	var phase = 0.0
	for index in count:
		var progress = float(index) / count
		phase += TAU * float(spec[0]) * (1.0 + float(spec[2]) * progress) / rate
		samples.encode_s16(index * 2, int(sin(phase) * 3500.0 * (1.0 - progress)))
	sound.data = samples
	audio.stream = sound
	audio.play()

# ---------- animasyon ve efektler ----------

func float_text(target: Control, text: String, color: Color) -> void:
	if not is_instance_valid(target):
		return
	var node = Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", 28)
	node.add_theme_color_override("font_color", color)
	node.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	node.add_theme_constant_override("outline_size", 8)
	node.z_index = 100
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(node)
	node.global_position = target.get_global_rect().get_center() - Vector2(16, 20)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(node, "global_position:y", node.global_position.y - 56, 0.9)
	tween.tween_property(node, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tween.chain().tween_callback(node.queue_free)

func flash(target: Control, tint: Color) -> void:
	if not is_instance_valid(target):
		return
	var base = target.modulate
	target.modulate = tint
	create_tween().tween_property(target, "modulate", base, 0.35)

func pop(target: Control, from_scale: float = 0.3, duration: float = 0.32) -> void:
	if not is_instance_valid(target):
		return
	target.pivot_offset = target.size / 2
	target.scale = Vector2(from_scale, from_scale)
	create_tween().tween_property(target, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func pulse(target: Control) -> void:
	if not is_instance_valid(target):
		return
	target.pivot_offset = target.size / 2
	var tween = create_tween()
	tween.tween_property(target, "scale", Vector2(1.22, 1.22), 0.12)
	tween.tween_property(target, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)

func ghost(rect: Rect2, text: String) -> void:
	var holder = PanelContainer.new()
	holder.add_theme_stylebox_override("panel", box(sk("card_back"), Color("c0392b"), 2, 10, 4))
	holder.size = rect.size
	holder.z_index = 90
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	holder.global_position = rect.position
	var skull = label("☠\n" + text, holder, 14)
	skull.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skull.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	holder.pivot_offset = rect.size / 2
	var tween = create_tween().set_parallel(true)
	tween.tween_property(holder, "modulate:a", 0.0, 0.55)
	tween.tween_property(holder, "scale", Vector2(0.7, 0.7), 0.55)
	tween.chain().tween_callback(holder.queue_free)

func toast(text: String, color: Color) -> void:
	var holder = PanelContainer.new()
	holder.add_theme_stylebox_override("panel", box(Color(0, 0, 0, 0.72), color, 2, 14, 14))
	holder.z_index = 120
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	var node = label(text, holder, 30)
	node.add_theme_color_override("font_color", color)
	node.autowrap_mode = TextServer.AUTOWRAP_OFF
	await get_tree().process_frame
	holder.global_position = (get_viewport_rect().size - holder.size) / 2 - Vector2(0, 40)
	holder.pivot_offset = holder.size / 2
	holder.scale = Vector2(0.6, 0.6)
	var tween = create_tween()
	tween.tween_property(holder, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.7)
	tween.tween_property(holder, "modulate:a", 0.0, 0.35)
	tween.tween_callback(holder.queue_free)

func run_effects(state: Dictionary) -> void:
	var snap = {"id": str(room.get("id", "")), "units": {}, "hero": [int(state.players[0].hp), int(state.players[1].hp)], "active": int(state.active), "turn": int(state.turn), "status": str(state.status)}
	for side in 2:
		for unit in state.players[side].board:
			snap.units[int(unit.uid)] = {"hp": int(unit.hp), "name": str(cards[int(unit.id)].name), "rect": Rect2()}
	var old: Dictionary = prev_state
	prev_state = snap
	var attack = last_attack
	last_attack = {}
	if old.is_empty() or old.id != snap.id:
		return
	await get_tree().process_frame
	await get_tree().process_frame
	for uid in snap.units:
		if unit_nodes.has(uid) and is_instance_valid(unit_nodes[uid]):
			snap.units[uid].rect = unit_nodes[uid].get_global_rect()
	var hurt = false
	var arrived = false
	for uid in snap.units:
		var node = unit_nodes.get(uid)
		if not old.units.has(uid):
			arrived = true
			pop(node)
			continue
		var delta = int(snap.units[uid].hp) - int(old.units[uid].hp)
		if delta < 0:
			hurt = true
			float_text(node, str(delta), Color("ff5a4a"))
			flash(node, Color(1.8, 0.5, 0.5))
		elif delta > 0:
			float_text(node, "+%d" % delta, Color("6bff9a"))
			flash(node, Color(0.6, 1.6, 0.8))
	for uid in old.units:
		if not snap.units.has(uid) and old.units[uid].rect.size.x > 0:
			hurt = true
			ghost(old.units[uid].rect, old.units[uid].name)
	for side in 2:
		var change = int(snap.hero[side]) - int(old.hero[side])
		if change != 0 and hero_nodes.has(side):
			hurt = hurt or change < 0
			float_text(hero_nodes[side], str(change) if change < 0 else "+%d" % change, Color("ff5a4a") if change < 0 else Color("6bff9a"))
			flash(hero_nodes[side], Color(1.8, 0.5, 0.5) if change < 0 else Color(0.6, 1.6, 0.8))
	if not attack.is_empty() and unit_nodes.has(int(attack.uid)):
		pulse(unit_nodes[int(attack.uid)])
	if snap.status == "finished" and old.status != "finished":
		var won = state.winner != null and int(state.winner) == 0
		play_sound("win" if won else "lose")
		return
	if snap.status == "playing" and snap.active == 0 and snap.turn != old.turn:
		toast("SENİN TURUN", GOLD)
		play_sound("turn")
	elif hurt:
		play_sound("hit")
	elif arrived:
		play_sound("play")

func _process(_delta: float) -> void:
	if is_instance_valid(turn_clock) and not room.is_empty() and room.get("state") != null:
		if room.deadline == null or room.status == "finished":
			turn_clock.text = "Bu maçta saat kapalı."
		else:
			var left = maxi(0, ceili((float(room.deadline) - server_offset - Time.get_unix_time_from_system() * 1000.0) / 1000.0))
			turn_clock.text = "Sunucu saati: %d sn" % left
