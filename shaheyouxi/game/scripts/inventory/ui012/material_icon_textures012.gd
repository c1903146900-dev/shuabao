extends RefCounted
## Fixed presentation-only lookup. No path, item, count or authority is inferred.
## PNG sources remain their original native bytes; texture import is a separate gate.
const WOOD_TEXTURE = preload("res://assets/ui/materials/tubiao_mucai.png")
const STONE_TEXTURE = preload("res://assets/ui/materials/tubiao_shitou.png")

static func texture_for_content(content_id: String) -> Texture2D:
	match content_id:
		"mucai":
			return WOOD_TEXTURE
		"shitou":
			return STONE_TEXTURE
	return null
