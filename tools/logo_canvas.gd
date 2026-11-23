extends Control
## Draws the albionOS wordmark exactly like makeLogo() in the HTML (before the halftone pass).
const FONT := preload("res://assets/fonts/IBMPlexMono-Bold.woff2")


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 460), Color.BLACK)
	draw_set_transform(Vector2(208, 372), 0.0, Vector2(0.7, 1.5))
	draw_string(FONT, Vector2.ZERO, "albion", HORIZONTAL_ALIGNMENT_LEFT, -1, 224, Color.WHITE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_rect(Rect2(790, 276, 52, 24), Color.WHITE)
	draw_set_transform(Vector2(864, 372), 0.0, Vector2(0.7, 1.5))
	draw_string(FONT, Vector2.ZERO, "os", HORIZONTAL_ALIGNMENT_LEFT, -1, 224, Color.WHITE)
