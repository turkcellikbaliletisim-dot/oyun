extends "res://native/skin_chrome.gd"
## Landscape presentation only: rules, network and legal actions stay upstream.
## Reserve independent rails instead of painting controls over the battlefield.
var match_regions: Dictionary = {}
var landscape_commands: ScrollContainer
var landscape_hand: ScrollContainer
var match_turn_banner: Control

func landscape_match_enabled() -> bool:
	var viewport = get_viewport_rect().size
	return viewport.x > viewport.y and content_width() >= 600.0

func match_available_size() -> Vector2:
	var available = get_viewport_rect().size.y
	available -= shell_margin.get_theme_constant("margin_top") + shell_margin.get_theme_constant("margin_bottom")
	var layout = scroll.get_parent()
	var visible_count = 1
	for child in layout.get_children():
		if child != scroll and child is Control and child.is_visible_in_tree():
			available -= child.get_combined_minimum_size().y
			visible_count += 1
	available -= layout.get_theme_constant("separation") * (visible_count - 1)
	return Vector2(content_width(), maxf(1.0, available))

static func landscape_regions(dimensions: Vector2) -> Dictionary:
	var width = dimensions.x
	var height = dimensions.y
	var left = 66.0
	var right = clampf(width * 0.18, 132.0, 154.0)
	var gap = 12.0
	var center_x = left + gap
	var center_width = width - center_x - right - gap
	var hand_height = clampf(height * 0.32, 98.0, 126.0)
	var hand_y = height - hand_height
	var lane_height = (hand_y - 24.0) / 2.0
	return {
		"bounds": Rect2(Vector2.ZERO, dimensions),
		"foe": Rect2(center_x, 8.0, center_width, lane_height),
		"own": Rect2(center_x, 16.0 + lane_height, center_width, lane_height),
		"hand": Rect2(center_x, hand_y, center_width, hand_height),
		"rail": Rect2(width - right, 0.0, right, height),
		"left": Rect2(0.0, 0.0, left, height),
	}

func render_match() -> void:
	if not landscape_match_enabled() or room.get("state") == null:
		match_regions = {}
		super.render_match()
		return
	var dimensions = match_available_size()
	var state: Dictionary = room.state
	var legal: Array = room.get("actions", [])
	var mine: Dictionary = state.players[0]
	var foe: Dictionary = state.players[1]
	match_regions = landscape_regions(dimensions)
	arena = Control.new()
	arena.name = "LandscapeMatch"
	arena.custom_minimum_size = Vector2(0, dimensions.y)
	arena.size = dimensions
	arena.clip_contents = true
	content.add_child(arena)
	var table_art = skin_art("background_land.png")
	if table_art != null:
		table_bg = Control.new()
		table_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		table_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(table_bg)
		move_child(table_bg, 1)
		picture(table_art, table_bg)
		var dim = ColorRect.new()
		dim.color = Color(0, 0, 0, 0.34)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		table_bg.add_child(dim)
	atmosphere(dimensions.x, dimensions.y)
	for entry in [["foe", foe.board, false, "lane_enemy.png"], ["own", mine.board, true, "lane.png"]]:
		var region: Rect2 = match_regions[entry[0]]
		var strip = Control.new()
		strip.name = "EnemyLane" if not entry[2] else "PlayerLane"
		strip.position = region.position
		strip.size = region.size
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		arena.add_child(strip)
		var surface = art_slice(strip, entry[3], Rect2(), "h3", Vector4(246, 0, 246, 0))
		if surface != null:
			surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			surface.modulate.a = 0.92
		if entry[1].is_empty():
			var hint = label("RAKİP SAHASI" if not entry[2] else "SENİN SAHAN", strip, 11)
			hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			hint.modulate.a = 0.5
			hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var count = maxi(5, entry[1].size())
		var card_width = minf(78.0, minf((region.size.y - 10.0) / 1.34, (region.size.x - 24.0 - 6.0 * (count - 1)) / count))
		battlefield_lane(entry[1], entry[2], legal, region.grow(-5.0), card_width)
		var hero_size = minf(54.0, region.size.y - 12.0)
		hero(arena, 0 if entry[2] else 1, mine if entry[2] else foe, Vector2(5.0, region.get_center().y - hero_size / 2.0), hero_size)
	landscape_left_summary(mine, foe)
	landscape_render_hand(mine, state, legal)
	landscape_render_commands(state, mine, legal)
	if state.status == "finished":
		render_result(state, dimensions.x, dimensions.y)
	run_effects(state)

func landscape_left_summary(mine: Dictionary, foe: Dictionary) -> void:
	var rect: Rect2 = match_regions.hand
	var stats = VBoxContainer.new()
	stats.position = Vector2(2, rect.position.y + 4)
	stats.custom_minimum_size = Vector2(62, 0)
	stats.add_theme_constant_override("separation", 3)
	arena.add_child(stats)
	for caption in ["RAKİP ELİ %d" % foe.hand.size(), "DESTE %d" % mine.deck.size(), "TUZAK %d/%d" % [mine.traps.size(), foe.traps.size()]]:
		var text = label(caption, stats, 9)
		text.autowrap_mode = TextServer.AUTOWRAP_OFF
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE

func landscape_render_hand(mine: Dictionary, state: Dictionary, legal: Array) -> void:
	var rect: Rect2 = match_regions.hand
	landscape_hand = ScrollContainer.new()
	landscape_hand.name = "LandscapeHand"
	landscape_hand.position = rect.position
	landscape_hand.size = rect.size
	landscape_hand.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	landscape_hand.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	arena.add_child(landscape_hand)
	var margin = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 4)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	landscape_hand.add_child(margin)
	var hand = HBoxContainer.new()
	hand.alignment = BoxContainer.ALIGNMENT_CENTER
	hand.add_theme_constant_override("separation", 9)
	margin.add_child(hand)
	var card_width = minf(80.0, (rect.size.y - 12.0) / 1.34)
	var mulligan = state.status == "mulligan" and state.active == 0
	for index in mine.hand.size():
		var id = int(mine.hand[index])
		var options = legal.filter(func(action): return action.type == "play" and int(action.index) == index)
		var change = mulligan and not mine.mulliganPinned.has(id)
		var picked = mulligan_indices.has(index) or int(focus.get("hand_index", -1)) == index
		var card = mini_card(id, hand, card_width, {}, func():
			if change:
				if mulligan_indices.has(index):
					mulligan_indices.erase(index)
				else:
					mulligan_indices.append(index)
			else:
				focus = {"id": id, "hand_index": index}
				selected = options
			render(), "picked" if picked else "ready" if change or not options.is_empty() else "dim", "✓" if mulligan_indices.has(index) else "")
		card.set_meta("hand_index", index)
		if not options.is_empty():
			install_drag(card, options)

func landscape_button(caption: String, parent: Node, callback: Callable, prominent: bool = false) -> Button:
	var node = Button.new()
	node.text = caption
	node.custom_minimum_size = Vector2(0, 44)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.add_theme_font_size_override("font_size", 13)
	node.clip_text = true
	node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	parent.add_child(node)
	node.pressed.connect(callback)
	# Fit the painted portion, not the PNG's transparent padding. Uniform-height
	# end caps retain their detail while the text plate spans the command rail.
	var file = "end_turn_ready.png" if prominent else "button_dark.png"
	var texture = skin_art(file)
	var region = END_TURN_REGION if prominent else BUTTON_REGION
	var padding = StyleBoxEmpty.new()
	padding.content_margin_left = 12
	padding.content_margin_right = 12
	padding.content_margin_top = 8
	padding.content_margin_bottom = 8
	for key in ["normal", "hover", "pressed", "disabled"]:
		node.add_theme_stylebox_override(key, padding if texture != null else box(Color("342819"), GOLD, 1, 8, 8))
	if texture != null:
		var artwork = ArtSlice.new().setup(texture, region, "h3", Vector4(88, 0, 88, 0))
		artwork.show_behind_parent = true
		artwork.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		node.add_child(artwork)
		artwork.set_meta("decor", true)
		node.mouse_entered.connect(func(): artwork.modulate = Color(1.12, 1.1, 1.0))
		node.mouse_exited.connect(func(): artwork.modulate = Color.WHITE)
		node.button_down.connect(func(): artwork.modulate = Color(0.8, 0.8, 0.8))
		node.button_up.connect(func(): artwork.modulate = Color.WHITE)
	var focus_style = box(Color.TRANSPARENT, GOLD, 2, 6, 0)
	node.add_theme_stylebox_override("focus", focus_style)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		node.add_theme_color_override(key, Color("231503") if prominent else INK)
	return node

func landscape_render_commands(state: Dictionary, mine: Dictionary, legal: Array) -> void:
	var rect: Rect2 = match_regions.rail
	var rail = Panel.new()
	rail.name = "LandscapeCommandRail"
	rail.position = rect.position
	rail.size = rect.size
	rail.add_theme_stylebox_override("panel", box(Color(0.04, 0.07, 0.09, 0.88), Color("675333"), 1, 10, 0))
	arena.add_child(rail)
	var turn = label("TUR %d" % ceili(float(state.turn) / 2), rail, 12)
	turn.position = Vector2(10, 6)
	turn.autowrap_mode = TextServer.AUTOWRAP_OFF
	turn_clock = label("", rail, 11)
	turn_clock.position = Vector2(10, 25)
	turn_clock.autowrap_mode = TextServer.AUTOWRAP_OFF
	var back = Button.new()
	back.name = "LandscapeExit"
	back.position = Vector2(rect.size.x - 48, 2)
	back.custom_minimum_size = Vector2(44, 44)
	back.icon = skin_art("icon_back.png")
	back.expand_icon = true
	back.tooltip_text = "Maçtan çık"
	for key in ["normal", "hover", "pressed"]:
		back.add_theme_stylebox_override(key, StyleBoxEmpty.new())
	back.pressed.connect(confirm_leave)
	rail.add_child(back)
	var primary = VBoxContainer.new()
	primary.position = Vector2(6, 50)
	primary.size = Vector2(rect.size.x - 12, 44)
	rail.add_child(primary)
	if state.status != "finished":
		if state.active == 0 and state.status == "mulligan":
			landscape_button("Başla", primary, func(): move({"type": "mulligan", "indices": mulligan_indices.duplicate()}), true)
		elif state.active == 0:
			for action in legal:
				if action.type == "end":
					var end = landscape_button("Turu bitir", primary, func(): move(action), true)
					end.name = "LandscapeEndTurn"
		else:
			var waiting = label("Rakibin turu", primary, 12)
			waiting.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	landscape_commands = ScrollContainer.new()
	landscape_commands.name = "LandscapeChoices"
	landscape_commands.position = Vector2(8, 101)
	landscape_commands.size = Vector2(rect.size.x - 16, maxf(32, rect.size.y - 154))
	landscape_commands.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rail.add_child(landscape_commands)
	var details = VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 5)
	landscape_commands.add_child(details)
	for action in legal:
		if action.type in ["scry", "discard"]:
			landscape_button(action_name(action), details, func(): move(action))
	if not focus.is_empty():
		var info: Dictionary = cards[int(focus.id)]
		label(info.name, details, 13)
		var description = muted_label(info.text, details, 12)
		description.custom_minimum_size.x = rect.size.x - 20
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var inspect = landscape_button("Kartı büyüt", details, func(): inspect_card(int(info.id)))
		inspect.tooltip_text = "Kartın tam metnini aç"
		for action in selected:
			var target = str(action.get("target", ""))
			if not target.begins_with("unit:") and not target.begins_with("hero:"):
				landscape_button(action_name(action), details, func(): move(action))
		if not selected.is_empty():
			var cancel = landscape_button("İptal", details, func(): selected = []; focus = {}; render())
			cancel.icon = skin_art("icon_close.png")
			cancel.expand_icon = true
			cancel.add_theme_constant_override("icon_max_width", 18)
	elif state.status != "finished":
		muted_label("Kart seç veya sahaya sürükle.", details, 11)
	var energy_row = HBoxContainer.new()
	energy_row.add_theme_constant_override("separation", 0)
	energy_row.position = Vector2(8, rect.size.y - 43)
	rail.add_child(energy_row)
	var maximum = maxi(1, int(mine.maxEnergy))
	var crystal_size = minf(18, (rect.size.x - 16) / maximum)
	for index in maximum:
		var crystal = art_slice(energy_row, "icon_energy_full.png" if index < int(mine.energy) else "icon_energy_empty.png")
		if crystal != null:
			crystal.custom_minimum_size = Vector2(crystal_size, crystal_size)
	var energy = label("%d/%d ENERJİ" % [int(mine.energy), int(mine.maxEnergy)], rail, 12)
	energy.position = Vector2(8, rect.size.y - 22)
	energy.autowrap_mode = TextServer.AUTOWRAP_OFF
	energy.add_theme_color_override("font_color", Color("8aceff"))

func banner_toast(text: String, color: Color) -> void:
	if not room.is_empty() and room.get("status") == "finished":
		return
	if is_instance_valid(match_turn_banner):
		match_turn_banner.queue_free()
	var holder = Control.new()
	holder.name = "ResponsiveTurnBanner"
	holder.z_index = 120
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	match_turn_banner = holder
	var banner_width = minf(300, get_viewport_rect().size.x - 32)
	# Bildirim rakip sahasının üzerinde durur; oyuncunun kartlarını örtmez.
	var banner_y = 0.0 if get_viewport_rect().size.x > get_viewport_rect().size.y else get_viewport_rect().size.y * 0.397
	holder.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	holder.offset_left = -banner_width / 2.0
	holder.offset_right = banner_width / 2.0
	holder.offset_top = banner_y
	holder.offset_bottom = banner_y + 66
	var banner = art_slice(holder, "toast_banner.png", Rect2(48, 10, 1104, 240))
	if banner != null:
		banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var title = Label.new()
	title.text = text
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if portrait_font != null:
		title.add_theme_font_override("font", portrait_font)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", color)
	outlined(title, Color(0.15, 0.07, 0.02, 0.95), 3)
	holder.add_child(title)
	var tween = holder.create_tween()
	tween.tween_interval(0.8)
	tween.tween_property(holder, "modulate:a", 0.0, 0.35)
	tween.tween_callback(holder.queue_free)

func render_result(state: Dictionary, width: float, height: float) -> void:
	if is_instance_valid(match_turn_banner):
		match_turn_banner.queue_free()
		match_turn_banner = null
	if not landscape_match_enabled():
		super.render_result(state, width, height)
		return
	var veil = ColorRect.new()
	veil.name = "LandscapeResultVeil"
	veil.color = Color(0, 0, 0, 0.68)
	veil.size = Vector2(width, height)
	arena.add_child(veil)
	var result = PanelContainer.new()
	result.name = "LandscapeResult"
	var result_width = minf(440, width - 32)
	var result_height = minf(232, height - 16)
	result.position = Vector2((width - result_width) / 2, (height - result_height) / 2)
	result.size = Vector2(result_width, result_height)
	result.add_theme_stylebox_override("panel", box(Color("14242b"), GOLD, 1, 12, 12))
	arena.add_child(result)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	result.add_child(row)
	var crest = TextureRect.new()
	crest.texture = skin_art("result_victory.png" if state.winner == 0 else "result_defeat.png")
	crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crest.custom_minimum_size.x = 124
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(crest)
	var column = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	row.add_child(column)
	var title = label("ZAFER" if state.winner == 0 else "BERABERE" if state.winner == null else "YENİDEN DENE", column, 19)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	landscape_button("DEVAM ET", column, leave_match, true)
	landscape_button("Maç kaydı", column, export_replay)
