extends RefCounted
## Convert physical display cutouts into Godot canvas coordinates.
static func safe_margins(viewport: Vector2, screen: Vector2, safe: Rect2) -> Vector4:
	if screen.x <= 0 or screen.y <= 0 or safe.size.x <= 0 or safe.size.y <= 0:
		return Vector4(12, 12, 12, 12)
	var scale = viewport / screen
	return Vector4(maxf(12, ceilf(safe.position.x * scale.x)), maxf(12, ceilf(safe.position.y * scale.y)), maxf(12, ceilf((screen.x - safe.end.x) * scale.x)), maxf(12, ceilf((screen.y - safe.end.y) * scale.y)))
