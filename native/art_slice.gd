class_name ArtSlice
extends Control
## Görsel paketindeki PNG'leri tam çözünürlükle, esnetmeden çizer.
## mode: "full" = bölgeyi tüm alana, "h3" = yatay üç parça (uçlar orantılı, orta esner),
## "p9" = dokuz parça (kenarlar cap_scale ile ölçeklenir).

var texture: Texture2D
var region := Rect2()
var caps := Vector4.ZERO
var mode := "full"
var cap_scale := 1.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	resized.connect(queue_redraw)

func setup(tex: Texture2D, reg: Rect2, mode_name: String = "full", cap_sizes: Vector4 = Vector4.ZERO, scale_value: float = 1.0) -> ArtSlice:
	texture = tex
	region = reg if reg.size != Vector2.ZERO else Rect2(Vector2.ZERO, tex.get_size())
	mode = mode_name
	caps = cap_sizes
	cap_scale = scale_value
	queue_redraw()
	return self

func _draw() -> void:
	if texture == null or size.x <= 0 or size.y <= 0:
		return
	if mode == "full":
		draw_texture_rect_region(texture, Rect2(Vector2.ZERO, size), region)
		return
	var k = size.y / region.size.y if mode == "h3" else cap_scale
	var l = caps.x * k
	var t = caps.y * k
	var r = caps.z * k
	var b = caps.w * k
	if l + r > size.x:
		var f = size.x / (l + r)
		l *= f
		r *= f
	if t + b > size.y:
		var f = size.y / (t + b)
		t *= f
		b *= f
	var xs = [0.0, l, size.x - r, size.x]
	var ys = [0.0, t, size.y - b, size.y]
	var sxs = [region.position.x, region.position.x + caps.x, region.end.x - caps.z, region.end.x]
	var sys = [region.position.y, region.position.y + caps.y, region.end.y - caps.w, region.end.y]
	for row in 3:
		for col in 3:
			var dest = Rect2(xs[col], ys[row], xs[col + 1] - xs[col], ys[row + 1] - ys[row])
			var src = Rect2(sxs[col], sys[row], sxs[col + 1] - sxs[col], sys[row + 1] - sys[row])
			if dest.size.x > 0 and dest.size.y > 0 and src.size.x > 0 and src.size.y > 0:
				draw_texture_rect_region(texture, dest, src)
