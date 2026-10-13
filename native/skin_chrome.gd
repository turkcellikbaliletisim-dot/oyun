extends "res://native/mobile.gd"
## Presentation-only completion of the mobile skin. No account or game rules.
## Keep the upstream mobile renderer intact while this focused change is reviewed.

var chrome_background: TextureRect
var chrome_connection: TextureRect
var chrome_navigation: Control
var chrome_highlights: Dictionary = {}

class NavigationArtwork extends Control:
	var artwork: Texture2D
	const SOCKETS = [146.0, 439.0, 731.0, 1024.0]
	const SOURCE_SIZE = Vector2(1170.0, 200.0)
	const SOCKET_HALF = 80.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size.y = 74.0
		resized.connect(queue_redraw)

	func _draw() -> void:
		if artwork == null or size.x <= 0.0:
			return
		var slot_width = size.x / 4.0
		var scale_factor = minf(0.30, slot_width / (SOCKET_HALF * 2.0))
		var art_height = SOURCE_SIZE.y * scale_factor
		# Stretch only the strips between sockets. Every circular socket keeps
		# identical horizontal/vertical scale in portrait and landscape.
		for index in range(4):
			var start = float(index) * SOURCE_SIZE.x / 4.0
			var stop = float(index + 1) * SOURCE_SIZE.x / 4.0
			var center = SOCKETS[index]
			var destination = float(index) * slot_width
			var half_width = SOCKET_HALF * scale_factor
			var xs = [start, center - SOCKET_HALF, center + SOCKET_HALF, stop]
			var dx = [destination, destination + slot_width / 2.0 - half_width,
				destination + slot_width / 2.0 + half_width, destination + slot_width]
			for segment in range(3):
				var target = Rect2(dx[segment], 0.0, dx[segment + 1] - dx[segment], art_height)
				var source = Rect2(xs[segment], 0.0, xs[segment + 1] - xs[segment], SOURCE_SIZE.y)
				if target.size.x > 0.0:
					draw_texture_rect_region(artwork, target, source)

func build_shell() -> void:
	super.build_shell()
	install_background_art()
	install_header_art()
	install_connection_art()
	install_navigation_art()

func render() -> void:
	super.render()
	refresh_connection_art()
	sync_navigation_visibility()

func install_header_art() -> void:
	if skin_art("header_bar.png") == null:
		return
	var layout = game_header.get_parent()
	var index = game_header.get_index()
	layout.remove_child(game_header)
	var wrapper = PanelContainer.new()
	wrapper.name = "SkinHeader"
	wrapper.custom_minimum_size.y = 50
	wrapper.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	layout.add_child(wrapper)
	layout.move_child(wrapper, index)
	var art = art_slice(wrapper, "header_bar.png", Rect2(), "h3", Vector4(120, 0, 120, 0))
	art.set_meta("skin_asset", "header_bar.png")
	wrapper.add_child(game_header)

func install_background_art() -> void:
	var texture = skin_art("backdrop.png")
	if texture == null:
		return # Keep the original SVG as an explicit missing-asset fallback.
	for child in get_children():
		if child is TextureRect and child.texture != null:
			if child.texture.resource_path == "res://native/mobile-assets/backdrop.svg":
				chrome_background = child
				chrome_background.name = "SkinBackdrop"
				chrome_background.texture = texture
				chrome_background.set_meta("skin_asset", "backdrop.png")
				return

func install_connection_art() -> void:
	chrome_connection = TextureRect.new()
	chrome_connection.name = "SkinConnectionStatus"
	chrome_connection.custom_minimum_size = Vector2(28, 28)
	chrome_connection.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chrome_connection.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chrome_connection.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chrome_connection.mouse_filter = Control.MOUSE_FILTER_PASS
	game_header.add_child(chrome_connection)
	game_header.move_child(chrome_connection, connection_indicator.get_index())
	refresh_connection_art()
	# Observe the existing connection state without adding another API coroutine.
	# The signal disconnects automatically when this Control is freed.
	get_tree().process_frame.connect(refresh_connection_if_changed)

func refresh_connection_if_changed() -> void:
	if is_instance_valid(chrome_connection) and chrome_connection.get_meta("connection_state", null) != connected:
		refresh_connection_art()

func refresh_connection_art() -> void:
	if not is_instance_valid(chrome_connection):
		return
	var file = "icon_net_ok.png" if connected else "icon_net_bad.png"
	var description = "Çevrimdışı mod · Cihazda oynanıyor" if (connected and offline_mode) else ("Sunucuya bağlı" if connected else "Bağlantı bekleniyor")
	var texture = skin_art(file)
	chrome_connection.texture = texture
	chrome_connection.tooltip_text = description
	chrome_connection.set_meta("skin_asset", file)
	chrome_connection.set_meta("connection_state", connected)
	chrome_connection.visible = texture != null
	# Preserve a text fallback for missing art and an explanation for the icon.
	connection_indicator.visible = texture == null
	connection_indicator.text = "Çevrimdışı" if (connected and offline_mode) else ("Bağlı" if connected else "Bekliyor")
	connection_indicator.tooltip_text = description

func install_navigation_art() -> void:
	var texture = skin_art("nav_bar.png")
	if texture == null:
		return
	var layout = nav_bar.get_parent()
	var position_in_layout = nav_bar.get_index()
	layout.remove_child(nav_bar)
	var wrapper = NavigationArtwork.new()
	wrapper.name = "SkinNavigation"
	wrapper.artwork = texture
	wrapper.set_meta("skin_asset", "nav_bar.png")
	wrapper.set_meta("socket_count", 4)
	layout.add_child(wrapper)
	layout.move_child(wrapper, position_in_layout)
	wrapper.add_child(nav_bar)
	nav_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chrome_navigation = wrapper
	nav_bar.visibility_changed.connect(sync_navigation_visibility)
	var halo_source = skin_art("nav_active.png")
	var halo_texture: Texture2D = halo_source
	if halo_source != null:
		var image = halo_source.get_image()
		if image != null and image.get_used_rect().has_area():
			var centered = AtlasTexture.new()
			centered.atlas = halo_source
			centered.region = Rect2(image.get_used_rect())
			halo_texture = centered
	for key in nav_buttons:
		var nav: Button = nav_buttons[key]
		nav.custom_minimum_size = Vector2(44, 74)
		for state in ["normal", "hover", "pressed", "disabled"]:
			nav.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		var focus_style = StyleBoxFlat.new()
		focus_style.bg_color = Color.TRANSPARENT
		focus_style.border_color = GOLD
		focus_style.set_border_width_all(2)
		focus_style.set_corner_radius_all(6)
		nav.add_theme_stylebox_override("focus", focus_style)
		for child in nav.get_children():
			if child is VBoxContainer:
				child.alignment = BoxContainer.ALIGNMENT_BEGIN
				child.offset_top = 16.0
				child.add_theme_constant_override("separation", 4)
		if halo_texture != null:
			var halo = TextureRect.new()
			halo.name = "SkinActiveHalo"
			halo.texture = halo_texture
			halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			halo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
			halo.set_meta("skin_asset", "nav_active.png")
			nav.add_child(halo)
			nav.move_child(halo, 0)
			halo.anchor_left = 0.5
			halo.anchor_right = 0.5
			halo.offset_left = -26.0
			halo.offset_right = 26.0
			halo.offset_top = 6.0
			halo.offset_bottom = 58.0
			chrome_highlights[key] = halo
	sync_navigation_visibility()
	update_nav()

func sync_navigation_visibility() -> void:
	if is_instance_valid(chrome_navigation) and is_instance_valid(nav_bar):
		if chrome_navigation.visible != nav_bar.visible:
			chrome_navigation.visible = nav_bar.visible

func update_nav() -> void:
	if not is_instance_valid(chrome_navigation):
		super.update_nav()
		return
	var active = "collection" if gallery_open else "deck" if view == "deck" else "story" if view == "story" else "play"
	for key in nav_buttons:
		var selected_tab = key == active
		nav_buttons[key].set_meta("selected_tab", selected_tab)
		if chrome_highlights.has(key):
			chrome_highlights[key].visible = selected_tab
		for child in nav_buttons[key].get_children():
			if child is VBoxContainer:
				for item in child.get_children():
					if item is Label:
						item.add_theme_color_override("font_color", GOLD if selected_tab else INK)
