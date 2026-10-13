extends "res://scripts/combat/common_hex_bridge.gd"
## Each accepted room begins with no live hit transaction from its predecessor.
## Only this isolated adapter uses the guard; shared production is unchanged.
func begin_room()->void:
 _inside_hit=0
 super.begin_room()
