extends Control
# Menülerde canlı kahraman: 4 karelik saldırı şeridinden nefes alan bekleme + ara ara saldırı.

var sheet: Texture2D = null
var still: Texture2D = null
var flip: bool = false
var attack_every: float = 2.6
var phase: float = 0.0
var ring: Color = Color(0, 0, 0, 0)
var t: float = 0.0
var frames: Array = []

func setup(sheet_tex: Texture2D, still_tex: Texture2D, every: float = 2.6, phase_in: float = 0.0) -> void:
	sheet = sheet_tex
	still = still_tex
	attack_every = every
	phase = phase_in
	t = phase_in
	frames = []
	if sheet != null:
		var w = sheet.get_width() / 4.0
		for i in range(4):
			var at = AtlasTexture.new()
			at.atlas = sheet
			at.region = Rect2(w * i, 0, w, sheet.get_height())
			frames.append(at)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	t += delta
	queue_redraw()

func current() -> Texture2D:
	if frames.is_empty():
		return still
	var cyc = fmod(t, attack_every)
	if attack_every > 0.0 and cyc < 0.48:
		return frames[clampi(int(cyc / 0.12), 0, 3)]
	return frames[0]

func _draw() -> void:
	var tex = current()
	if tex == null:
		return
	var ts = tex.get_size()
	var breathe = sin(t * 2.3) * 0.025
	var avail = size * Vector2(1.0, 0.94)
	var sc = minf(avail.x / ts.x, avail.y / ts.y)
	var s = ts * sc * Vector2(1.0 - breathe * 0.5, 1.0 + breathe)
	var pos = Vector2((size.x - s.x) / 2.0, size.y - s.y - size.y * 0.04)
	if ring.a > 0.0:
		draw_set_transform(Vector2(size.x / 2.0, size.y * 0.95), 0.0, Vector2(1.0, 0.32))
		draw_circle(Vector2.ZERO, size.x * 0.34, Color(0, 0, 0, 0.35))
		draw_arc(Vector2.ZERO, size.x * 0.36, 0, TAU, 32, ring, 3.0, true)
		draw_set_transform(Vector2.ZERO)
	if flip:
		draw_set_transform(Vector2(size.x, 0), 0.0, Vector2(-1, 1))
	draw_texture_rect(tex, Rect2(pos, s), false)
	if flip:
		draw_set_transform(Vector2.ZERO)
