extends Control
## Native Godot client. The shared Node server validates all forty card effects.
signal updated

const SESSION_FILE = "user://destan-session.cfg"
const PENDING_FILE = "user://destan-pending.json"
var endpoint = "http://127.0.0.1:8080"
var cookie = ""
var account: Dictionary = {}
var room: Dictionary = {}
var data: Dictionary = {}
var cards: Dictionary = {}
var busy = false
var selected: Array = []
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
var deck_inputs: Dictionary = {}
var use_custom = false
var deck_total: Label
var muted = true
var audio: AudioStreamPlayer
var textures: Dictionary = {}
var mulligan_indices: Array = []

func _ready() -> void:
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
	build_shell()
	poll = Timer.new()
	poll.wait_time = 1.5
	poll.timeout.connect(refresh)
	add_child(poll)
	poll.start()
	audio = AudioStreamPlayer.new()
	add_child(audio)
	if not OS.get_cmdline_user_args().has("--no-connect"):
		connect_account()

func label(text: String, parent: Node, size: int = 18) -> Label:
	var node = Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(node)
	return node

func button(text: String, parent: Node, callback: Callable, disabled: bool = false) -> Button:
	var node = Button.new()
	node.text = text
	node.custom_minimum_size.y = 42
	node.disabled = disabled or busy
	node.pressed.connect(callback)
	parent.add_child(node)
	return node

func skin(file: String) -> Resource:
	var path = "res://native/skin/" + file
	return load(path) if ResourceLoader.exists(path) else null

func skin_box(file: String, edge_x: int = 100, edge_y: int = 32, pad_x: int = 24, pad_y: int = 10) -> StyleBox:
	var tex = skin(file)
	if tex == null:
		return null
	var box = StyleBoxTexture.new()
	box.texture = tex
	for side in [SIDE_LEFT, SIDE_RIGHT]:
		box.set_texture_margin(side, edge_x)
	for side in [SIDE_TOP, SIDE_BOTTOM]:
		box.set_texture_margin(side, edge_y)
	box.content_margin_left = pad_x
	box.content_margin_right = pad_x
	box.content_margin_top = pad_y
	box.content_margin_bottom = pad_y
	return box

func skin_button(node: Button, file: String, edge_x: int = 100, edge_y: int = 32) -> void:
	var box = skin_box(file, edge_x, edge_y)
	if box == null:
		return
	for state in ["normal", "hover", "pressed", "focus"]:
		node.add_theme_stylebox_override(state, box)

func divider(parent: Node) -> void:
	var tex = skin("divider.png")
	if tex == null:
		parent.add_child(HSeparator.new())
		return
	var line = TextureRect.new()
	line.texture = tex
	line.custom_minimum_size = Vector2(0, 30)
	line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	line.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)

func build_shell() -> void:
	var palette = Theme.new()
	palette.default_font_size = 18
	palette.set_color("font_color", "Label", Color("e8dfc5"))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style = StyleBoxFlat.new()
		style.bg_color = Color("203d45") if state in ["hover", "pressed"] else Color("14272e")
		style.border_color = Color("d7b668") if state != "disabled" else Color("34434a")
		style.set_border_width_all(2 if state == "focus" else 1)
		style.set_corner_radius_all(7)
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		var textured = skin_box("button_gold.png" if state in ["hover", "pressed", "focus"] else "button_dark.png")
		palette.set_stylebox(state, "Button", textured if textured != null else style)
	# input_field.png: 9-slice [33, 22, 33, 22] (manifest_v2.json)
	for state in ["normal", "focus", "read_only"]:
		var field = skin_box("input_field.png", 33, 22, 18, 8)
		if field != null:
			palette.set_stylebox(state, "LineEdit", field)
	var grabber = skin_box("scrollbar.png", 20, 20, 0, 0)
	if grabber != null:
		for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
			palette.set_stylebox(state, "VScrollBar", grabber)
	# tooltip_panel.png: ipucu paneli (600x300); kenar degerleri manifestte yok, 60/40 secildi
	var tip = skin_box("tooltip_panel.png", 60, 40, 16, 10)
	if tip != null:
		palette.set_stylebox("panel", "TooltipPanel", tip)
		palette.set_color("font_color", "TooltipLabel", Color("f1dfb2"))
	palette.set_color("font_color", "LineEdit", Color("f1dfb2"))
	palette.set_color("font_color", "Button", Color("f1dfb2"))
	palette.set_color("font_disabled_color", "Button", Color("829093"))
	theme = palette
	var backdrop = skin("background.png")
	if backdrop != null:
		var bg = TextureRect.new()
		bg.texture = backdrop
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(bg)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var layout = VBoxContainer.new()
	margin.add_child(layout)
	var heading = HBoxContainer.new()
	layout.add_child(heading)
	var title = label("DESTAN DİYARLARI", heading, 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button("40 kart", heading, show_collection)
	button("Ses aç/kapat", heading, func(): muted = not muted; notice.text = "Ses kapalı" if muted else "Ses açık")
	button("Tam ekran", heading, toggle_fullscreen)
	account_line = label("Mac: ⌘S maç kaydı · ⌘F tam ekran · Esc seçimi iptal", layout, 15)
	var network = HBoxContainer.new()
	layout.add_child(network)
	address = LineEdit.new()
	address.text = endpoint
	address.placeholder_text = "Sunucu adresi"
	address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	network.add_child(address)
	button("Bağlan", network, connect_account)
	# toast_banner.png: bildirim seridi, 9-slice [65, 43, 65, 43] (manifest_v2.json)
	var toast = skin_box("toast_banner.png", 65, 43, 40, 14)
	var notice_parent: Node = layout
	if toast != null:
		var toast_panel = PanelContainer.new()
		toast_panel.add_theme_stylebox_override("panel", toast)
		layout.add_child(toast_panel)
		notice_parent = toast_panel
	notice = label("Sunucu için depo kökünde: npm run online", notice_parent, 16)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	save_dialog = FileDialog.new()
	save_dialog.use_native_dialog = true
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

func clear_content() -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()

func persist_session() -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("account", "endpoint", endpoint)
	cfg.set_value("account", "cookie", cookie)
	cfg.save(SESSION_FILE)

func api(path: String, method: int = HTTPClient.METHOD_GET, body: Dictionary = {}) -> Dictionary:
	var request_node = HTTPRequest.new()
	request_node.timeout = 12
	add_child(request_node)
	var headers = PackedStringArray(["Content-Type: application/json", "Origin: " + endpoint])
	if not cookie.is_empty():
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
		return {"error": "Sunucuya ulaşılamadı. Node sunucusunu ve adresi kontrol et.", "network": true}
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
		return
	if next != endpoint:
		cookie = ""
		account = {}
		room = {}
		pending = {}
		recovery_key = ""
	endpoint = next
	busy = true
	var result = await api("session", HTTPClient.METHOD_POST)
	busy = false
	if result.has("error"):
		notice.text = result.error
		updated.emit()
		return
	accept_account(result)
	notice.text = "Bağlandı · ⌘S maç kaydı · ⌘F tam ekran · Esc seçimi iptal"
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
				render()
	else:
		busy = false
	updated.emit()

func clear_pending() -> void:
	pending = {}
	if FileAccess.file_exists(PENDING_FILE):
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
			notice.text = "Paket: " + JSON.stringify(result.rewards)
	elif result.has("state"):
		room = result
		server_offset = float(result.serverNow) - Time.get_unix_time_from_system() * 1000.0
	elif result.has("profile"):
		accept_account(result)
	selected = []
	mulligan_indices = []
	var cue = "click"
	if result.has("rewards"):
		cue = "pack_open"
	elif result.has("state") and result.get("status") == "finished":
		cue = "victory" if result.state.get("winner") == 0 else "defeat"
	play_sound(cue)
	render()
	updated.emit()

func move(action: Dictionary) -> void:
	if room.is_empty() or not pending.is_empty():
		return
	await mutate("matches/" + room.id + "/actions", {"version": room.version, "action": action}, true)

func render() -> void:
	clear_content()
	if gallery_open:
		render_collection()
	elif room.is_empty():
		render_lobby()
	else:
		render_match()

func render_lobby() -> void:
	var logo = skin("logo.png")
	if logo != null:
		var mark = TextureRect.new()
		mark.texture = logo
		mark.custom_minimum_size = Vector2(0, 150)
		mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(mark)
	label("ANADOLU'DA YOLCULUK", content, 26)
	if account.is_empty():
		label("Node sunucusunu başlat ve Bağlan'a bas.", content)
		return
	label("Başlangıç destesi: 20 sahip olduğun kart. Hikâye desteleri ödünç verilir.", content)
	var actions = HFlowContainer.new()
	content.add_child(actions)
	button("Bot ile oyna", actions, func(): mutate("solo", {"chapterId": 0, "deck": custom_deck if use_custom else data.decks.starter.cards}))
	chapter_select = OptionButton.new()
	for chapter in data.chapters:
		chapter_select.add_item("%d. %s" % [chapter.id, chapter.title], int(chapter.id))
		chapter_select.set_item_disabled(chapter_select.item_count - 1, chapter.id > 1 and not account.profile.chapterRewards.has(chapter.id - 1))
	actions.add_child(chapter_select)
	button("Hikâyeye başla", actions, func(): mutate("solo", {"chapterId": chapter_select.get_selected_id()}))
	button("Arkadaş odası oluştur", actions, func(): mutate("rooms", {"deck": custom_deck if use_custom else data.decks.starter.cards}))
	room_code = LineEdit.new()
	room_code.placeholder_text = "8 karakter oda kodu"
	room_code.max_length = 8
	room_code.custom_minimum_size.x = 200
	actions.add_child(room_code)
	button("Odaya katıl", actions, func(): mutate("join", {"code": room_code.text.strip_edges().to_upper(), "deck": custom_deck if use_custom else data.decks.starter.cards}))
	button("Lig ara", actions, func(): mutate("queue", {"deck": custom_deck if use_custom else data.decks.starter.cards}), not account.profile.chapterRewards.has(10) or account.queued)
	if account.queued:
		button("Lig aramasını iptal et", actions, func(): mutate("queue/cancel", {}))
	button("Deste oluştur", actions, render_deck_builder)
	divider(content)
	label("HESABI KORU", content, 23)
	label("Kurtarma anahtarı hesaba erişim verir. Güvenli bir yere kaydet; yalnız ilk oluşturulduğunda indirilir.", content, 16)
	if not recovery_key.is_empty():
		button("Kurtarma anahtarını dosyaya kaydet", content, func(): save_file(recovery_key + "\n", "destan-kurtarma-anahtari.txt"))
	recover_input = LineEdit.new()
	recover_input.secret = true
	recover_input.placeholder_text = "Mevcut hesabın kurtarma anahtarı"
	content.add_child(recover_input)
	button("Hesabı kurtar", content, recover_account)
	if not account.history.is_empty():
		divider(content)
		label("SON MAÇLAR", content, 23)
		for match_entry in account.history:
			button("%s · %s" % [match_entry.kind, match_entry.result], content, func(): open_match(match_entry.id))

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

func texture_for(id: int) -> AtlasTexture:
	if textures.has(id):
		return textures[id]
	var first = int((id - 1) / 4) * 4 + 1
	var atlas = AtlasTexture.new()
	atlas.atlas = load("res://kart-prototipi/gorseller/%02d-%02d.png" % [first, first + 3])
	var cell = (id - 1) % 4
	atlas.region = Rect2((cell % 2) * 768, int(cell / 2) * 512, 768, 512)
	textures[id] = atlas
	return atlas

func card_widget(id: int, parent: Node, callback: Callable, playable: bool = false, unit: Dictionary = {}) -> void:
	var card: Dictionary = cards[id]
	var panel = VBoxContainer.new()
	panel.custom_minimum_size = Vector2(188, 0)
	parent.add_child(panel)
	var art = TextureRect.new()
	art.texture = texture_for(id)
	art.custom_minimum_size = Vector2(188, 125)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	panel.add_child(art)
	var activate = button("%s · %d enerji" % [card.name, card.cost], panel, callback, not playable)
	activate.tooltip_text = card.text
	activate.add_theme_font_size_override("font_size", 14)
	activate.clip_text = true
	if card.type == "warrior":
		var attack = int(unit.get("attack", card.attack)) + int(unit.get("tempAttack", 0))
		if id == 21 and not unit.is_empty() and not room.is_empty():
			for player in room.state.players:
				if player.board.any(func(member): return int(member.uid) == int(unit.uid)):
					attack += player.board.size() - 1
		label("SAL %d · CAN %d" % [maxi(0, attack), unit.get("hp", card.hp)], panel, 15)
	button("İncele", panel, func(): inspect_card(id, unit))

func inspect_card(id: int, unit: Dictionary = {}) -> void:
	var dialog = AcceptDialog.new()
	dialog.title = cards[id].name
	dialog.dialog_text = "%s enerji · %s · %s\n%s\n%s" % [cards[id].cost, cards[id].type, cards[id].rarity, cards[id].text, "Can: " + str(unit.hp) if not unit.is_empty() else ""]
	dialog.min_size = Vector2i(520, 220)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()

func select_actions(options: Array) -> void:
	selected = options
	render()

func action_name(action: Dictionary) -> String:
	match action.type:
		"end": return "Turu bitir"
		"mulligan": return "Bu elle başla"
		"scry": return "Deste altına koy" if action.bottom else "Üstte bırak"
		"discard": return "At: " + cards[int(room.state.players[0].hand[int(action.index)])].name
		"play", "attack":
			var target = str(action.get("target", ""))
			if target == "hero:0": return "Kendini hedefle"
			if target == "hero:1": return "Rakibi hedefle"
			if target.begins_with("unit:"):
				for player in room.state.players:
					for unit in player.board:
						if target == "unit:" + str(int(unit.uid)): return "Hedef: " + cards[int(unit.id)].name
			if target.begins_with("grave:"):
				for unit in room.state.players[0].grave:
					if target == "grave:" + str(int(unit.uid)):
						return "Dirilt: " + cards[int(unit.id)].name
			return "Oyna"
	return action.type

func render_match() -> void:
	if room.state == null:
		label("ODA KODU: " + str(room.code), content, 30)
		label("Arkadaşın bu kodla katıldığında maç başlayacak.", content)
		button("Lobiye dön", content, leave_match)
		return
	var state: Dictionary = room.state
	var mine: Dictionary = state.players[0]
	var foe: Dictionary = state.players[1]
	if int(room.chapterId) > 0:
		label(data.chapters[int(room.chapterId) - 1].task, content, 19)
	label("RAKİP · CAN %d · ENERJİ %d/%d · EL %d · GİZLİ TUZAK %d" % [foe.hp, foe.energy, foe.maxEnergy, foe.hand.size(), foe.traps.size()], content, 22)
	var foe_board = HFlowContainer.new()
	content.add_child(foe_board)
	for unit in foe.board:
		card_widget(int(unit.id), foe_board, func(): inspect_card(int(unit.id), unit), true, unit)
	label("SEN · CAN %d · ENERJİ %d/%d · DESTE %d · TUR %d/20 · %s" % [mine.hp, mine.energy, mine.maxEnergy, mine.deck.size(), ceili(float(state.turn) / 2), "Kart fazı" if state.phase == "main" else "Saldırı fazı"], content, 22)
	var own_board = HFlowContainer.new()
	content.add_child(own_board)
	var legal: Array = room.get("actions", [])
	turn_clock = label("", content, 16)
	for unit in mine.board:
		var options = legal.filter(func(action): return action.type == "attack" and int(action.uid) == int(unit.uid))
		card_widget(int(unit.id), own_board, func(): select_actions(options), not options.is_empty(), unit)
	if state.status == "finished":
		label("BERABERE" if state.winner == null else "KAZANDIN" if state.winner == 0 else "MAÇ TAMAMLANDI", content, 28)
		button("Maç kaydını indir (⌘S)", content, export_replay)
	elif state.active != 0:
		label("Rakibin turu…", content)
	else:
		var decisions = HFlowContainer.new()
		content.add_child(decisions)
		for action in legal:
			if action.type in ["mulligan", "scry", "discard", "end"]:
				if action.type == "mulligan":
					label("Değiştirilecek kartları seç. Görev kartı korunur.", content, 16)
					button("Bu elle başla" if mulligan_indices.is_empty() else "%d kartı değiştir" % mulligan_indices.size(), decisions, func(): move({"type": "mulligan", "indices": mulligan_indices.duplicate()}))
				else:
					var turn_button = button(action_name(action), decisions, func(): move(action))
					if action.type == "end":
						turn_button.custom_minimum_size = Vector2(200, 64)
						skin_button(turn_button, "end_turn_ready.png", 90, 60)
		if not selected.is_empty():
			var target_head = HBoxContainer.new()
			content.add_child(target_head)
			var ring = skin("target_ring.png")
			if ring != null:
				var ring_icon = TextureRect.new()
				ring_icon.texture = ring
				ring_icon.custom_minimum_size = Vector2(40, 40)
				ring_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				ring_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				target_head.add_child(ring_icon)
			label("HEDEF SEÇ", target_head, 21)
			var targets = HFlowContainer.new()
			content.add_child(targets)
			for action in selected:
				button(action_name(action), targets, func(): move(action))
			button("İptal (Esc)", targets, func(): selected = []; render())
	label("ELİN · Kartı seç, hedefini belirle. Ayrıntılar için İncele.", content, 18)
	var hand = HFlowContainer.new()
	content.add_child(hand)
	for index in mine.hand.size():
		var options = legal.filter(func(action): return action.type == "play" and int(action.index) == index)
		var can_mulligan = state.status == "mulligan" and state.active == 0 and not mine.mulliganPinned.has(mine.hand[index])
		card_widget(int(mine.hand[index]), hand, func():
			if can_mulligan:
				if mulligan_indices.has(index):
					mulligan_indices.erase(index)
				else:
					mulligan_indices.append(index)
				render()
			elif options.size() == 1 and not options[0].has("target"):
				move(options[0])
			else:
				select_actions(options), can_mulligan or not options.is_empty())
		if mulligan_indices.has(index):
			label("✓ Değiştirilecek: " + cards[int(mine.hand[index])].name, content, 15)
	label("Tuzakların: " + ", ".join(mine.traps.map(func(trap): return cards[int(trap.id)].name)), content, 15)
	divider(content)
	var leave_button = button("Lobiye dön / teslim ol", content, func():
		if state.status == "finished":
			leave_match()
		else:
			var dialog = ConfirmationDialog.new()
			dialog.dialog_text = "Maçtan ayrılmak teslim sayılır. Ayrılmak istiyor musun?"
			dialog.confirmed.connect(func(): dialog.queue_free(); leave_match())
			dialog.canceled.connect(dialog.queue_free)
			add_child(dialog)
			dialog.popup_centered())
	skin_button(leave_button, "button_red.png")
	label("\n".join(state.log.slice(maxi(0, state.log.size() - 8))), content, 14)

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

func show_collection() -> void:
	if busy:
		return
	gallery_open = true
	selected = []
	render()

func render_collection() -> void:
	button("Oyuna dön", content, func(): gallery_open = false; render())
	label("40 KARTLIK KOLEKSİYON", content, 28)
	if not account.is_empty():
		label("%d altın · %d toz · %d ücretsiz paket" % [account.profile.gold, account.profile.dust, account.profile.freePacks], content)
		button("Paket aç · ücretsiz veya 300 altın", content, func(): mutate("collection/pack", {}, true), account.profile.freePacks == 0 and account.profile.gold < 300)
	var grid = HFlowContainer.new()
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 24)
	content.add_child(grid)
	for id in range(1, 41):
		var cell = VBoxContainer.new()
		grid.add_child(cell)
		card_widget(id, cell, func(): inspect_card(id), true)
		if not account.is_empty():
			var card: Dictionary = cards[id]
			var amount = int(account.profile.inventory.get(str(id), 0))
			var cap = 1 if card.rarity == "legendary" else 2
			var craft_cost = {"common": 40, "rare": 100, "legendary": 400}[card.rarity]
			label("Sahiplik: %d/%d" % [amount, cap], cell, 15)
			button("Üret · %s toz" % craft_cost, cell, func(): mutate("collection/craft", {"cardId": id}, true), amount >= cap or account.profile.dust < craft_cost)
			button("Parçala", cell, func(): mutate("collection/dismantle", {"cardId": id}, true), amount == 0)
			if account.profile.chapterRewards.has(10) and account.profile.archiveLeft > 0:
				button("Arşivden seç", cell, func(): mutate("collection/archive", {"cardId": id}, true), amount > 0)

func render_deck_builder() -> void:
	clear_content()
	deck_inputs = {}
	label("DESTEN · 20 sahip olduğun kart seç", content, 26)
	deck_total = label("20/20 kart", content)
	for id in range(1, 41):
		var row = HBoxContainer.new()
		content.add_child(row)
		var name_label = label(cards[id].name, row)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var input = SpinBox.new()
		input.min_value = 0
		input.max_value = int(account.profile.inventory.get(str(id), 0))
		input.value = mini(int(input.max_value), custom_deck.count(id))
		input.value_changed.connect(func(_value): deck_total.text = "%s/20 kart" % builder_deck().size())
		row.add_child(input)
		deck_inputs[id] = input
	button("Bu desteyi kullan", content, func():
		var deck = builder_deck()
		if deck.size() != 20:
			notice.text = "Deste tam 20 kart olmalı."
			return
		custom_deck = deck
		use_custom = true
		render())
	button("Başlangıç destesine dön", content, func(): use_custom = false; render())

func builder_deck() -> Array:
	var deck: Array = []
	for id in deck_inputs:
		for _copy in int(deck_inputs[id].value):
			deck.append(id)
	return deck

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
		render()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_F11 or event.keycode == KEY_F and event.is_command_or_control_pressed():
		toggle_fullscreen()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_S and event.is_command_or_control_pressed():
		export_replay()
		get_viewport().set_input_as_handled()

func play_sound(sound_name: String = "click") -> void:
	if muted:
		return
	var clip = skin("audio/%s.ogg" % sound_name)
	if clip != null:
		audio.stream = clip
		audio.play()
		return
	var sound = AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = 22050
	var samples = PackedByteArray()
	samples.resize(4410)
	for index in 2205:
		var sample = int(sin(float(index) * TAU * 660.0 / 22050.0) * 3000.0 * (1.0 - float(index) / 2205.0))
		samples.encode_s16(index * 2, sample)
	sound.data = samples
	audio.stream = sound
	audio.play()

func _process(_delta: float) -> void:
	if is_instance_valid(turn_clock) and not room.is_empty() and room.get("state") != null:
		if room.deadline == null or room.status == "finished":
			turn_clock.text = "Bu maçta saat kapalı."
		else:
			var left = maxi(0, ceili((float(room.deadline) - server_offset - Time.get_unix_time_from_system() * 1000.0) / 1000.0))
			turn_clock.text = "Sunucu saati: %d sn" % left
