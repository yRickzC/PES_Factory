extends Control

const CANVAS_SIZE := Vector2(640, 360)


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, size / CANVAS_SIZE)
	draw_rect(Rect2(Vector2.ZERO, CANVAS_SIZE), Color("#dbe9c2"))
	draw_rect(Rect2(0, 132, 640, 100), Color("#c5deb1"))
	_draw_sun()

	# Stepped silhouettes keep the landscape on the same pixel grid as the game.
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 210), Vector2(48, 210), Vector2(48, 198), Vector2(92, 198),
		Vector2(92, 182), Vector2(152, 182), Vector2(152, 166), Vector2(232, 166),
		Vector2(232, 182), Vector2(280, 182), Vector2(280, 196), Vector2(352, 196),
		Vector2(352, 168), Vector2(416, 168), Vector2(416, 150), Vector2(492, 150),
		Vector2(492, 170), Vector2(576, 170), Vector2(576, 192), Vector2(640, 192),
		Vector2(640, 360), Vector2(0, 360),
	]), Color("#8db98b"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 240), Vector2(84, 240), Vector2(84, 224), Vector2(176, 224),
		Vector2(176, 204), Vector2(280, 204), Vector2(280, 220), Vector2(388, 220),
		Vector2(388, 190), Vector2(504, 190), Vector2(504, 216), Vector2(640, 216),
		Vector2(640, 360), Vector2(0, 360),
	]), Color("#56886e"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 270), Vector2(88, 270), Vector2(88, 250), Vector2(212, 250),
		Vector2(212, 234), Vector2(304, 234), Vector2(304, 254), Vector2(640, 254),
		Vector2(640, 360), Vector2(0, 360),
	]), Color("#386b58"))

	draw_colored_polygon(PackedVector2Array([
		Vector2(272, 256), Vector2(328, 256), Vector2(328, 272), Vector2(292, 272),
		Vector2(292, 288), Vector2(236, 288), Vector2(236, 308), Vector2(264, 308),
		Vector2(264, 328), Vector2(340, 328), Vector2(340, 360), Vector2(146, 360),
		Vector2(146, 328), Vector2(180, 328), Vector2(180, 304), Vector2(156, 304),
		Vector2(156, 284), Vector2(216, 284), Vector2(216, 272), Vector2(272, 272),
	]), Color("#74bca3"))
	for ripple in [Rect2(244, 279, 32, 2), Rect2(179, 295, 38, 2),
			Rect2(202, 319, 20, 2), Rect2(239, 342, 64, 2), Rect2(182, 351, 34, 2)]:
		draw_rect(ripple, Color("#a7d7b2"))

	_draw_tree(Vector2(27, 266), 1.0)
	_draw_tree(Vector2(61, 269), 0.75)
	_draw_tree(Vector2(113, 251), 0.75)
	_draw_tree(Vector2(139, 248), 1.0)
	_draw_tree(Vector2(326, 254), 0.75)
	_draw_tree(Vector2(37, 342), 1.5)
	_draw_tree(Vector2(86, 325), 1.0)
	_draw_tree(Vector2(361, 326), 1.25)
	_draw_tree(Vector2(604, 310), 1.25)


func _draw_sun() -> void:
	var light := Color("#f7dc8e")
	draw_rect(Rect2(286, 53, 44, 60), light)
	draw_rect(Rect2(278, 61, 60, 44), light)
	draw_rect(Rect2(282, 57, 52, 52), light)
	draw_rect(Rect2(258, 98, 67, 4), Color("#e7edc8"))
	draw_rect(Rect2(311, 106, 39, 3), Color("#e7edc8"))


func _draw_tree(base: Vector2, scale_factor: float) -> void:
	var shadow := Color("#27564b")
	draw_rect(Rect2(base + Vector2(-13, -3) * scale_factor, Vector2(26, 5) * scale_factor), shadow)
	draw_rect(Rect2(base + Vector2(-2, -14) * scale_factor, Vector2(4, 14) * scale_factor), Color("#ac8056"))
	draw_rect(Rect2(base + Vector2(-12, -28) * scale_factor, Vector2(24, 16) * scale_factor), shadow)
	draw_rect(Rect2(base + Vector2(-8, -34) * scale_factor, Vector2(16, 22) * scale_factor), shadow)
	draw_rect(Rect2(base + Vector2(-8, -29) * scale_factor, Vector2(14, 12) * scale_factor), Color("#609b69"))
	draw_rect(Rect2(base + Vector2(-5, -32) * scale_factor, Vector2(9, 7) * scale_factor), Color("#84b776"))
