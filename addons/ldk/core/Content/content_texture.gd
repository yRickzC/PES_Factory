@tool
class_name ContentTexture
extends Resource
## Reference to a texture that can be resolved when a View first uses it.

var path: String

var _texture: Texture2D
var _attempted := false


func resolve() -> Texture2D:
	if not _attempted:
		_attempted = true
		if ResourceLoader.exists(path, "Texture2D"):
			_texture = ResourceLoader.load(path, "Texture2D") as Texture2D
	return _texture
