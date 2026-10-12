extends RefCounted
## Lexical Linux scope. Local launcher argument is not a network authority or symlink sandbox.
const PACK_ARGUMENT := "--package_pck="

static func runtime_root(resource_root: String, user_arguments: PackedStringArray, packaged: bool = false) -> String:
	var declared: Array[String] = []
	for argument in user_arguments:
		if argument.begins_with(PACK_ARGUMENT):
			declared.append(argument.trim_prefix(PACK_ARGUMENT))
		elif argument.begins_with("--package_pck"):
			return ""
	if packaged:
		if declared.size() != 1:
			return ""
		var pack: String = declared[0]
		if not pack.begins_with("/") or not pack.is_absolute_path() or pack != pack.simplify_path() or pack.get_file() != "shaheyouxi_010.pck" or pack.get_base_dir().get_file() != "game":
			return ""
		return pack.get_base_dir().get_base_dir().path_join("runtime")
	if not declared.is_empty():
		return "" # A source run cannot redirect its scope through a package-only parameter.
	var source: String = resource_root.trim_suffix("/")
	if not source.begins_with("/") or not source.is_absolute_path() or source != source.simplify_path():
		return ""
	return source.get_base_dir().path_join("runtime")

static func scoped_path(resource_root: String, user_arguments: PackedStringArray, value: String, packaged: bool = false) -> String:
	var root: String = runtime_root(resource_root, user_arguments, packaged)
	var path: String = value.simplify_path()
	return path if not root.is_empty() and path.is_absolute_path() and path.begins_with(root + "/") else ""
