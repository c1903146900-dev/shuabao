extends RefCounted
## User-rule v5 runtime SOURCE CANDIDATE. No implicit fallback and no production admission.
## Source topology is separate and preserved. Every complete path is quota-checked.
const FloorRoute = preload("res://tests/ink_first_floor_flow_20261004/floor_route.gd")
const SCHEMA_VERSION := 5
const ROW_COUNT := 12
const COMPLETION_RULE := "boss_defeated_and_coordinator_completed"

static func load_definition(path: String, allow_developer_proposal: bool = false) -> Dictionary:
 if not FileAccess.file_exists(path): return deny("route_config_missing")
 var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
 if not parsed is Dictionary: return deny("route_config_invalid_json")
 var checked: Dictionary = validate(parsed, allow_developer_proposal)
 if not checked.accepted: return checked
 return {"accepted":true, "reason":"", "definition":parsed.duplicate(true), "file_sha256":FileAccess.get_sha256(path), "route_binding_id":binding_id(parsed)}

static func validate(definition: Dictionary, allow_developer_proposal: bool = false) -> Dictionary:
 if definition.get("schema_version", 0) != SCHEMA_VERSION: return deny("mixed_schema_mismatch")
 if definition.get("hero_id", "") != "yanguizhou": return deny("route_hero_mismatch")
 if definition.get("floor_id", "") != "first_floor": return deny("route_floor_mismatch")
 if not valid_id(definition.get("version", "")): return deny("route_version_missing")
 if definition.get("row_count", 0) != ROW_COUNT: return deny("first_floor_requires_12_rows")
 if definition.get("selection_rule", "") != "one_node_per_row": return deny("route_selection_rule_missing")
 if definition.get("completion_rule", "") != COMPLETION_RULE: return deny("route_completion_rule_missing")
 if definition.get("content_status", "") != "developer_proposal": return deny("developer_proposal_required")
 if not allow_developer_proposal: return deny("developer_proposal_requires_opt_in")
 if definition.has("fixture_scope"): return deny("fixture_cannot_be_relabelled")
 if not definition.get("candidate") is bool or not definition.get("release") is bool or not definition.get("production_ready") is bool:
  return deny("candidate_flags_must_be_boolean")
 if definition.get("candidate") != true or definition.get("release") != false or definition.get("production_ready") != false:
  return deny("candidate_must_remain_non_release")
 var authority = definition.get("authority")
 if not authority is Dictionary: return deny("proposal_authority_required")
 if not authority.get("topology_approved") is bool or not authority.get("node_frequency_approved") is bool:
  return deny("proposal_authority_required")
 if authority.get("topology_approved") != false or authority.get("node_frequency_approved") != true:
  return deny("proposal_authority_required")
 var rows = definition.get("rows")
 var payloads = definition.get("payloads")
 if not rows is Array or rows.size() != ROW_COUNT: return deny("first_floor_requires_12_rows")
 if not payloads is Dictionary or payloads.is_empty(): return deny("node_payloads_missing")
 var all_ids: Dictionary = {}
 var referenced: Dictionary = {}
 var row_ids: Array = []
 for index in range(ROW_COUNT):
  if not rows[index] is Dictionary: return deny("row_record_invalid")
  var row: Dictionary = rows[index]
  if not exact_keys(row, ["number", "nodes"]) or row.number != index + 1: return deny("row_order_or_shape_invalid")
  if not row.nodes is Array or row.nodes.is_empty(): return deny("row_choices_missing")
  var ids: Array = []
  for choice in row.nodes:
   if not choice is Dictionary or not exact_keys(choice, ["id", "payload_ref", "next"]): return deny("row_choice_invalid")
   if not valid_id(choice.id) or str(choice.id).begins_with("__") or all_ids.has(choice.id): return deny("node_id_invalid")
   if not valid_id(choice.payload_ref) or not payloads.has(choice.payload_ref): return deny("node_payload_binding_missing")
   if not payloads[choice.payload_ref] is Dictionary: return deny("node_payload_invalid")
   var checked: Dictionary = _validate_payload(payloads[choice.payload_ref], index == ROW_COUNT - 1)
   if not checked.accepted: return checked
   if not choice.next is Array: return deny("row_edges_missing")
   all_ids[choice.id] = index
   referenced[choice.payload_ref] = true
   ids.append(choice.id)
  row_ids.append(ids)
 if referenced.size() != payloads.size(): return deny("unreferenced_payload_not_allowed")
 # Adjacent-only edges, every node incoming (except row 1) and outgoing (except
 # row 12) prove every declared node participates in a complete 12-row path.
 for index in range(ROW_COUNT):
  var incoming: Dictionary = {}
  for choice in rows[index].nodes:
   var edges: Array = choice.next
   if index == ROW_COUNT - 1:
    if not edges.is_empty(): return deny("boss_must_be_terminal")
   elif edges.is_empty(): return deny("route_dead_end")
   var seen: Dictionary = {}
   for target in edges:
    if not target is String or seen.has(target): return deny("edge_invalid_or_duplicate")
    if index == ROW_COUNT - 1 or target not in row_ids[index + 1]: return deny("edge_must_reach_next_row")
    seen[target] = true
    incoming[target] = true
  if index < ROW_COUNT - 1:
   for id in row_ids[index + 1]:
    if not incoming.has(id): return deny("unreachable_choice")
 if rows[11].nodes.size() != 1: return deny("one_terminal_boss_required")
 if definition.get("start_nodes", []) != row_ids[0] or row_ids[0].size() < 2: return deny("all_first_row_starts_required")
 var quotas: Dictionary = _validate_path_quotas(definition)
 if not quotas.accepted: return quotas
 return {"accepted":true, "reason":"", "row_count":ROW_COUNT, "possible_node_count":all_ids.size(), "complete_path_count":quotas.path_count, "route_binding_id":binding_id(definition), "release":false}

static func _validate_payload(payload: Dictionary, final_row: bool) -> Dictionary:
 var node_type = payload.get("node_type", "")
 var kind = payload.get("kind", "")
 if node_type == "service":
  if final_row: return deny("final_row_requires_boss")
  if kind not in ["rest", "training"]: return deny("service_type_invalid")
  # Exact allowlists reject even zero-valued roster / XP / gold / reward keys.
  if not exact_keys(payload, ["node_type", "kind", "service"]): return deny("service_cannot_have_combat_or_reward_payload")
  var service = payload.service
  if not service is Dictionary or not exact_keys(service, ["type", "area_id", "completion_rule", "optional_actions"]): return deny("service_payload_invalid")
  if service.type != kind or not valid_id(service.area_id): return deny("service_identity_invalid")
  if not service.optional_actions is bool or service.completion_rule != "explicit_owner_exit" or service.optional_actions != true: return deny("service_completion_rule_invalid")
  return {"accepted":true, "reason":""}
 if node_type != "combat": return deny("node_type_invalid")
 if not exact_keys(payload, ["node_type", "kind", "roster"]): return deny("combat_payload_invalid")
 if final_row and kind != "boss": return deny("final_row_requires_boss")
 if not final_row and kind not in ["ordinary", "elite"]: return deny("early_boss_or_invalid_combat")
 # Call the retained EXACT FloorRoute validator. This local technical probe is
 # never returned as playable route content and NEVER manufactures service rooms.
 var node := {"id":"probe_combat", "kind":kind, "training_after":false, "roster":payload.roster}
 var nodes: Array = [node]
 if not final_row:
  nodes.append({"id":"probe_terminal", "kind":"boss", "training_after":false, "roster":[{"kind":"boss", "position":[0, 0, -10]}]})
 var probe := {"schema_version":1, "hero_id":"yanguizhou", "floor_id":"first_floor", "version":"mixed-v3-roster-validation-only", "content_status":"technical_fixture", "completion_rule":COMPLETION_RULE, "nodes":nodes}
 var result: Dictionary = FloorRoute.validate(probe, true)
 if not result.accepted: return deny("combat_roster:" + str(result.reason))
 # Tighten the outer candidate without weakening any retained roster guard.
 for entry in payload.roster:
  if not exact_keys(entry, ["kind", "position"]): return deny("combat_roster_extra_fields")
 return {"accepted":true, "reason":""}

static func find_choice(definition: Dictionary, row_number: int, node_id: String) -> Dictionary:
 if row_number < 1 or row_number > ROW_COUNT: return {}
 for choice in definition.rows[row_number - 1].nodes:
  if choice.id == node_id: return choice.duplicate(true)
 return {}

static func materialize_node(definition: Dictionary, row_number: int, node_id: String) -> Dictionary:
 var choice: Dictionary = find_choice(definition, row_number, node_id)
 if choice.is_empty(): return {}
 return {"row_number":row_number, "node_id":node_id, "payload_ref":choice.payload_ref, "next":choice.next.duplicate(), "payload":definition.payloads[choice.payload_ref].duplicate(true)}

static func validate_path(definition: Dictionary, path: Array, allow_developer_proposal: bool = false) -> Dictionary:
 var checked: Dictionary = validate(definition, allow_developer_proposal)
 if not checked.accepted: return checked
 if path.size() != ROW_COUNT: return deny("complete_path_requires_12_nodes")
 var previous: Dictionary = {}
 for index in range(ROW_COUNT):
  if not path[index] is String: return deny("path_node_invalid")
  var choice: Dictionary = find_choice(definition, index + 1, path[index])
  if choice.is_empty(): return deny("path_node_not_in_row")
  if index > 0 and choice.id not in previous.next: return deny("path_edge_missing")
  previous = choice
 return {"accepted":true, "reason":"", "release":false}

static func binding_id(value: Dictionary) -> String:
 return JSON.stringify(value, "", true, true).sha256_text()

static func exact_keys(value: Dictionary, keys: Array) -> bool:
 if value.size() != keys.size(): return false
 for key in keys:
  if not value.has(key): return false
 return true

static func valid_id(value) -> bool:
 return value is String and not value.is_empty() and value == value.strip_edges() and not value.contains("/") and not value.contains("|")

static func whole_number(value, minimum: int = 0) -> bool:
 return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= minimum

static func deny(reason: String) -> Dictionary:
 return {"accepted":false, "reason":reason, "changed":false}

static func _validate_path_quotas(definition: Dictionary) -> Dictionary:
 var expected: Dictionary = {"boss":{"min":1,"max":1,"terminal_row":12},"elite":{"min":1,"max":2},"rest":{"min":2,"max":3},"training":{"min":1,"max":2},"ordinary":"all_remaining_rows"}
 var supplied: Dictionary = definition.get("path_constraints", {})
 if not exact_keys(supplied,expected.keys()) or supplied.get("ordinary","") != "all_remaining_rows": return deny("immutable_user_quotas")
 for key: String in ["boss","elite","rest","training"]:
  if not supplied[key] is Dictionary or not exact_keys(supplied[key],expected[key].keys()): return deny("immutable_user_quotas")
  for field: String in expected[key]:
   if not whole_number(supplied[key][field]) or int(supplied[key][field]) != int(expected[key][field]): return deny("immutable_user_quotas")
 var frontier: Array = []
 for start: String in definition.start_nodes:
  frontier.append({"id":start,"row":1,"counts":{"ordinary":0,"elite":0,"rest":0,"training":0,"boss":0}})
 var path_count := 0
 while not frontier.is_empty():
  var entry: Dictionary = frontier.pop_back()
  var node: Dictionary = find_choice(definition,int(entry.row),str(entry.id))
  var counts: Dictionary = entry.counts.duplicate(true)
  var kind: String = str(definition.payloads[node.payload_ref].kind)
  counts[kind] = int(counts[kind]) + 1
  if int(entry.row) == ROW_COUNT:
   for quota: String in ["boss","elite","rest","training"]:
    if int(counts[quota]) < int(expected[quota].min) or int(counts[quota]) > int(expected[quota].max): return deny("path_quota_" + quota)
   path_count += 1
  else:
   for target: String in node.next: frontier.append({"id":target,"row":int(entry.row)+1,"counts":counts})
 return {"accepted":true,"reason":"","path_count":path_count}
