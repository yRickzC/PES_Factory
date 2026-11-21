@tool
extends ImageTexture
## Builds the shared provisional icon and held sprite from the terrain palette.

const PIXELS := [
	"................",
	"................",
	"................",
	"....oooooooo....",
	"..ooshshshssoo..",
	".ossoooowooosso.",
	".ooo...owo..ooo.",
	".......owo......",
	".......owo......",
	".......owo......",
	".......owo......",
	".......owo......",
	".......owo......",
	".......owo......",
	".......ooo......",
	"................",
]

@export var timber: Texture2D:
	set(value):
		timber = value
		_compose()
@export var stone: Texture2D:
	set(value):
		stone = value
		_compose()


func _compose() -> void:
	if timber == null or stone == null:
		return
	var wood_image := timber.get_image()
	var stone_image := stone.get_image()
	if wood_image == null or stone_image == null:
		return
	var image := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in PIXELS.size():
		for x in PIXELS[y].length():
			match PIXELS[y][x]:
				"o":
					image.set_pixel(x, y, Color("#342a38"))
				"w":
					image.set_pixel(x, y, wood_image.get_pixel(x, y).lightened(0.15))
				"s":
					image.set_pixel(x, y, stone_image.get_pixel(x, y).lightened(0.12))
				"h":
					image.set_pixel(x, y, stone_image.get_pixel(x, y).lightened(0.38))
	set_image(image)
