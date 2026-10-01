@tool
extends Node
## Only called in isolated editor through the real MCP execute_editor_script tool.
func scan() -> String:
	EditorInterface.get_resource_filesystem().scan()
	return "scan requested"

func configure_imports() -> Dictionary:
	var paths := PackedStringArray()
	for name in DirAccess.get_files_at("res://assets/audio"):
		if not name.ends_with(".wav"):
			continue
		var path := "res://assets/audio/" + name
		var config := ConfigFile.new()
		if config.load(path + ".import") != OK:
			return {"error": "Missing import: " + path}
		config.set_value("params", "force/8_bit", false)
		config.set_value("params", "force/mono", true)
		config.set_value("params", "edit/normalize", false)
		config.set_value("params", "edit/trim", false)
		config.set_value("params", "edit/loop_mode", 0)
		config.set_value("params", "compress/mode", 0)
		if config.save(path + ".import") != OK:
			return {"error": "Cannot save import: " + path}
		paths.append(path)
	EditorInterface.get_resource_filesystem().reimport_files(paths)
	return {"configured_and_reimported": paths.size(), "normalize": false, "loop": false, "compression": "PCM16", "mono": true}

func inventory() -> Dictionary:
	var rows: Array = []
	for name in DirAccess.get_files_at("res://assets/audio"):
		if name.ends_with(".wav"):
			var path := "res://assets/audio/" + name
			var stream := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE) as AudioStreamWAV
			if stream == null:
				return {"error": "Could not load " + path}
			rows.append({"file": name, "length": stream.get_length(), "format": stream.format,
				"rate": stream.mix_rate, "stereo": stream.stereo, "loop_mode": stream.loop_mode})
	return {"imported": rows.size(), "files": rows}
