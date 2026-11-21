@tool
extends ImageTexture
## Expands a hand-authored pixel grid. Unmapped characters stay transparent.

@export var palette: Dictionary[String, Color] = {}:
	set(value):
		palette = value
		_compose()
@export var rows: PackedStringArray:
	set(value):
		rows = value
		_compose()


func _compose() -> void:
	if rows.is_empty() or rows[0].is_empty() or palette.is_empty():
		return
	var width := rows[0].length()
	var pixels := Image.create_empty(width, rows.size(), false, Image.FORMAT_RGBA8)
	for y in rows.size():
		var row := rows[y]
		for x in mini(width, row.length()):
			var color: Color = palette.get(row[x], Color.TRANSPARENT)
			pixels.set_pixel(x, y, color)
	set_image(pixels)
