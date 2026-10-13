extends RefCounted
## Lossless output storage only. No Sim, input, timer, animation or gameplay owner.
const DYNAMIC_ACTOR_FIELDS := ["source_clock_diagnostics", "direction_schema_diagnostics"]
var root_dir := ""
var errors: Array = []
var blob_writes := 0
var blob_bytes := 0
var reference_uses := 0
var _by_variant_digest: Dictionary = {}
var _files: Dictionary = {}
var _current_proof: Dictionary = {}
var _current_ref: Dictionary = {}
var _read_cache: Dictionary = {}

func configure(directory: String) -> void:
 root_dir = directory

func _safe(value: Variant) -> Variant:
 # Exact same conversion contract as the retained host _json_safe.
 if value is Vector3: return [value.x,value.y,value.z] if value.is_finite() else "nonfinite_Vector3"
 if value is Vector2: return [value.x,value.y]
 if value is Dictionary:
  var result: Dictionary = {}
  for key in value: result[str(key)] = _safe(value[key])
  return result
 if value is Array:
  var result: Array = []
  for item in value: result.append(_safe(item))
  return result
 return value

func _variant_digest(value: Variant) -> String:
 var context := HashingContext.new()
 context.start(HashingContext.HASH_SHA256); context.update(var_to_bytes(value))
 return context.finish().hex_encode()

func _actor_shape(value: Dictionary) -> bool:
 return value.has("raw_import_clips") and value.has("filter_evidence") and value.has("clips") and value.has("asset_sha256")

func _intent_shape(value: Dictionary) -> bool:
 return value.has("new_rotation_clips_only") and value.has("mesh_asset_unchanged") and value.has("clips") and value.has("asset_sha256")

func _static_actor(value: Dictionary) -> Dictionary:
 var result: Dictionary = value.duplicate(false)
 for key: String in DYNAMIC_ACTOR_FIELDS: result.erase(key)
 return result

func prime_actor(proof: Dictionary) -> void:
 _current_proof = proof
 _current_ref = _store(_static_actor(proof)) if _actor_shape(proof) else {}

func _store(value: Dictionary) -> Dictionary:
 var binary_hash: String = _variant_digest(value)
 if _by_variant_digest.has(binary_hash): return _by_variant_digest[binary_hash]
 var text: String = JSON.stringify(_safe(value),"",true,false)
 var digest: String = text.sha256_text()
 var relative: String = "diagnostic_proofs/"+digest+".json"
 var absolute: String = ProjectSettings.globalize_path(root_dir.path_join(relative))
 if root_dir.is_empty(): errors.append("proof_root_required"); return {}
 if FileAccess.file_exists(absolute):
  if FileAccess.get_sha256(absolute) != digest: errors.append("existing_proof_hash_mismatch:"+relative); return {}
 else:
  if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK: errors.append("proof_directory_failed"); return {}
  var pending: String = absolute+".pending"
  var file: FileAccess = FileAccess.open(pending,FileAccess.WRITE)
  if file == null: errors.append("proof_write_failed"); return {}
  file.store_string(text); file.flush(); file.close()
  if FileAccess.get_sha256(pending) != digest: errors.append("proof_write_hash_mismatch"); return {}
  if DirAccess.rename_absolute(pending,absolute) != OK: errors.append("proof_publish_failed"); return {}
  blob_writes += 1; blob_bytes += text.to_utf8_buffer().size()
 var reference: Dictionary = {"file":relative,"sha256":digest,"pointer":[]}
 _by_variant_digest[binary_hash] = reference
 _files[digest] = {"file":relative,"sha256":digest,"bytes":FileAccess.get_file_as_bytes(absolute).size()}
 return reference

func pack(value: Variant) -> Variant:
 if value is Dictionary:
  if _actor_shape(value):
   var reference: Dictionary = _current_ref if not _current_ref.is_empty() and value == _current_proof else _store(_static_actor(value))
   var overlay: Dictionary = {}
   for key: String in DYNAMIC_ACTOR_FIELDS:
    if value.has(key): overlay[key] = pack(value[key])
   reference_uses += 1
   return {"$proof_ref":reference.duplicate(true),"$proof_overlay":overlay}
  if _intent_shape(value):
   var reference: Dictionary = {}
   if not _current_ref.is_empty() and value == _current_proof.get("q1_intent",{}):
    reference = _current_ref.duplicate(true); reference.pointer = ["q1_intent"]
   else: reference = _store(value)
   reference_uses += 1
   return {"$proof_ref":reference.duplicate(true)}
  var result: Dictionary = {}
  for key in value: result[str(key)] = pack(value[key])
  return result
 if value is Array:
  var result: Array = []
  for item in value: result.append(pack(item))
  return result
 return _safe(value)

func statistics() -> Dictionary:
 return {"schema":"lossless-proof-reference-1","proof_root":ProjectSettings.globalize_path(root_dir),"blob_writes":blob_writes,"blob_bytes":blob_bytes,"reference_uses":reference_uses,"proofs":_files.values().duplicate(true),"errors":errors.duplicate(),"dynamic_actor_fields_kept_inline":DYNAMIC_ACTOR_FIELDS,"frame_jsonl_and_sampling_unchanged":true}

func read_report(path: String) -> Variant:
 _read_cache.clear()
 var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
 var restored: Variant = resolve(decoded)
 if restored is Dictionary: restored.erase("_diagnostic_storage")
 _read_cache.clear()
 return restored

func resolve(value: Variant) -> Variant:
 if value is Dictionary:
  if value.has("$proof_ref"):
   var reference: Dictionary = value["$proof_ref"]
   var digest: String = str(reference.get("sha256",""))
   var relative: String = str(reference.get("file",""))
   if not _valid_digest(digest) or relative!="diagnostic_proofs/"+digest+".json": errors.append("invalid_proof_reference"); return null
   var absolute: String = ProjectSettings.globalize_path(root_dir.path_join(relative))
   if not FileAccess.file_exists(absolute) or FileAccess.get_sha256(absolute)!=digest: errors.append("unresolved_or_corrupt_proof"); return null
   if not _read_cache.has(digest): _read_cache[digest] = JSON.parse_string(FileAccess.get_file_as_string(absolute))
   var target: Variant = _read_cache[digest]
   for key in reference.get("pointer",[]):
    if not target is Dictionary or not target.has(key): errors.append("bad_proof_pointer"); return null
    target = target[key]
   if not target is Dictionary: errors.append("proof_dictionary_required"); return null
   var result: Dictionary = target.duplicate(false)
   for key in value.get("$proof_overlay",{}): result[key] = resolve(value["$proof_overlay"][key])
   return result
  var result: Dictionary = {}
  for key in value: result[key] = resolve(value[key])
  return result
 if value is Array:
  var result: Array = []
  for item in value: result.append(resolve(item))
  return result
 return value

func _valid_digest(value: String) -> bool:
 if value.length()!=64: return false
 for character: String in value:
  if character not in "0123456789abcdef": return false
 return true
