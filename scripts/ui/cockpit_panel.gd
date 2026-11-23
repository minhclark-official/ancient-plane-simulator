extends Control
## Static cockpit frame: instrument panel, window pillars, overhead strip.
## The 3D view shows through the window band (y 62..414); everything else is painted here.

const WIN_Y0 := 62.0
const WIN_Y1 := 414.0
const FONT_BOLD := preload("res://assets/fonts/IBMPlexMono-Bold.woff2")

var title := "ANCIENT AIR 001"


func _draw() -> void:
	var coal := Color("#16181c")
	var putty := Color("#b8b29b")
	# panel behind the instruments and the overhead band
	draw_rect(Rect2(0, 0, 1600, WIN_Y0), Color("#101114"))
	draw_rect(Rect2(0, WIN_Y1, 1600, 900.0 - WIN_Y1), coal)
	# overhead strip detail
	draw_rect(Rect2(0, WIN_Y0 - 6.0, 1600, 6), putty.darkened(0.4))
	draw_string(FONT_BOLD, Vector2(24, 40), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#ffb030"))
	draw_string(FONT_BOLD, Vector2(0, 40), "FLT-DECK OS 1.98   (C) 1987", HORIZONTAL_ALIGNMENT_RIGHT, 1576, 16, Color("#8e8977"))
	# window pillars (slanted)
	var pillar := Color("#1e1f23")
	draw_colored_polygon(PackedVector2Array([Vector2(250, WIN_Y0), Vector2(278, WIN_Y0), Vector2(250, WIN_Y1), Vector2(222, WIN_Y1)]), pillar)
	draw_colored_polygon(PackedVector2Array([Vector2(1322, WIN_Y0), Vector2(1350, WIN_Y0), Vector2(1378, WIN_Y1), Vector2(1350, WIN_Y1)]), pillar)
	draw_line(Vector2(0, WIN_Y1), Vector2(1600, WIN_Y1), putty.darkened(0.3), 4.0)
	# glare shield / dashboard sheen
	draw_rect(Rect2(0, WIN_Y1 + 2.0, 1600, 3), Color(1, 1, 1, 0.08))
	# MCP housing and lower panel edges
	draw_rect(Rect2(412, 414, 776, 82), Color("#2b2d31"))
	draw_rect(Rect2(412, 414, 776, 82), putty.darkened(0.5), false, 2.0)
	draw_rect(Rect2(0, 496, 1600, 4), putty.darkened(0.45))
	draw_rect(Rect2(0, 716, 1600, 6), putty.darkened(0.45))
