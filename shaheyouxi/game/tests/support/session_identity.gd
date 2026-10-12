extends RefCounted
## Reads an explicitly prepared private test-session identity. Never generates
## a fallback identity, changes a saved profile, or prints credential values.
const ENVIRONMENT := "SANDBOX_TEST_SESSION_IDENTITY"
const KIND := "isolated_test_session_identity_v1"

static func read_resume_secret() -> String:
	var path: String = OS.get_environment(ENVIRONMENT)
	if not path.is_absolute_path() or path != path.simplify_path(): return ""
	var project_root: String = ProjectSettings.globalize_path("res://").simplify_path().trim_suffix("/")
	if path == project_root or path.begins_with(project_root + "/"): return ""
	if OS.get_name() not in ["Linux", "macOS", "FreeBSD", "NetBSD", "OpenBSD"]: return ""
	if not _no_links(path) or not FileAccess.file_exists(path): return ""
	if int(FileAccess.get_unix_permissions(path)) != 384: return "" # 0600
	if int(FileAccess.get_unix_permissions(path.get_base_dir())) != 448: return "" # 0700
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null: return ""
	if file.get_length() > 1024:
		file.close()
		return ""
	var text: String = file.get_as_text()
	file.close()
	var value: Variant = JSON.parse_string(text)
	if not value is Dictionary or value.size() != 3: return ""
	if value.get("kind") != KIND or not _hex32(value.get("session_id")): return ""
	var secret: Variant = value.get("resume_secret")
	if not secret is String or not secret.begins_with("resume_") or not _hex32(secret.substr(7)): return ""
	return secret

static func _hex32(value: Variant) -> bool:
	if not value is String or value.length() != 32: return false
	for index in range(value.length()):
		if not "0123456789abcdef".contains(value.substr(index, 1)): return false
	return true

static func _no_links(path: String) -> bool:
	var cursor: String = path
	while true:
		var parent: String = cursor.get_base_dir()
		if parent == cursor: return true
		var directory: DirAccess = DirAccess.open(parent)
		if directory == null or directory.is_link(cursor.get_file()): return false
		cursor = parent
	return false
