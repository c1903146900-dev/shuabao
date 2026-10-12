extends RefCounted
## Optional test-supervisor corroboration. This never establishes child ownership.
static func _start_ticks(pid: int) -> String:
	var stream := FileAccess.open("/proc/%d/stat" % pid, FileAccess.READ)
	if stream == null:
		return ""
	# procfs reports zero file length; read the line rather than get_as_text().
	var line: String = stream.get_line()
	stream.close()
	var closing: int = line.rfind(") ")
	if closing < 0:
		return ""
	var fields: PackedStringArray = line.substr(closing + 2).split(" ", false)
	if fields.size() < 20 or not fields[19].is_valid_int():
		return ""
	return fields[19]

static func _publish(path: String, value: Dictionary) -> bool:
	if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):
		return false
	# Atomic one-time directory claim also rejects duplicate invocation.
	var claim: String = path + ".claim"
	if DirAccess.make_dir_absolute(claim) != OK:
		return false
	var temporary: String = claim.path_join("value.json")
	var stream := FileAccess.open(temporary, FileAccess.WRITE)
	if stream == null:
		return false
	stream.store_string(JSON.stringify(value, "", true, true))
	stream.flush()
	var result: Error = stream.get_error()
	stream.close()
	if result != OK or FileAccess.file_exists(path):
		return false
	return DirAccess.rename_absolute(temporary, path) == OK

static func prepare(arguments: PackedStringArray) -> Dictionary:
	var path: String = OS.get_environment("SANDBOX_ORDINARY_PLAN")
	if path.is_empty():
		return {"ok": true, "disabled": true}
	if not path.is_absolute_path():
		return {"ok": false}
	var stream := FileAccess.open(path, FileAccess.READ)
	if stream == null or stream.get_length() <= 0 or stream.get_length() > 1048576:
		return {"ok": false}
	var plan: Variant = JSON.parse_string(stream.get_as_text())
	stream.close()
	if typeof(plan) != TYPE_DICTIONARY or plan.get("schema") != 1 or typeof(plan.get("nonce")) != TYPE_STRING:
		return {"ok": false}
	var parent: int = OS.get_process_id()
	var ticks: String = _start_ticks(parent)
	if ticks.is_empty():
		return {"ok": false}
	var command: Array[String] = [OS.get_executable_path()]
	for argument: String in arguments:
		command.append(argument)
	var declaration: Dictionary = {"schema": 1, "nonce": plan["nonce"], "parent_pid": parent, "parent_start_ticks": ticks, "command": command}
	var declaration_path: String = path.get_base_dir().path_join("declaration.json")
	if not _publish(declaration_path, declaration):
		return {"ok": false}
	return {"ok": true, "disabled": false, "directory": path.get_base_dir(), "nonce": plan["nonce"], "parent_pid": parent, "parent_start_ticks": ticks, "declaration_sha256": FileAccess.get_sha256(declaration_path)}

static func receipt(prepared: Dictionary, child_pid: int) -> bool:
	if prepared.get("disabled", false):
		return true
	var ticks: String = _start_ticks(child_pid)
	if ticks.is_empty():
		return false
	var value: Dictionary = {"schema": 1, "nonce": prepared["nonce"], "parent_pid": prepared["parent_pid"], "parent_start_ticks": prepared["parent_start_ticks"], "child_pid": child_pid, "child_start_ticks": ticks, "declaration_sha256": prepared["declaration_sha256"]}
	return _publish(str(prepared["directory"]).path_join("receipt.json"), value)
