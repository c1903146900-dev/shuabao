extends RefCounted
const P3Gate=preload("res://yan_p3_reimplementation_20261018b/gate.gd")
const LEGACY_CANDIDATES=["Q1", "Q2", "Q3", "E1", "E2", "E3", "P1", "P2", "R1", "R2"]
## Explicit successor of immutable live02. The old validator remains unchanged
## and intentionally rejects changed resources; no validation is disabled.
const Catalog=preload("res://tests/ink_river_hexes_20261006/ordinary01/catalog.gd")
const Prior=preload("res://tests/ink_q3_input_growth_20261004/live_binding.gd")
const Frozen=preload("res://tests/ink_first_floor_boss_20261008/live02/live_binding.gd")
const SIM_PATH="res://tests/ink_river_hexes_20261006/ordinary01/sim.gd"
const BINDING_PATH="res://visual_rework_20261009/binding/source_binding.json"
const PARENT_PATH="res://tests/ink_first_floor_boss_20261008/live02/source_binding.json"
const PARENT_SHA="783f9670e8bd01ec7c0d720d25f6a444c38d48726d591e6d9aa6f16601838680"
const VISUAL_PATH="res://visual_rework_20261009/binding/visual_binding.json"
const REPLACEMENTS=["res://tests/ink_first_floor_user_route_20261005/native_host01/navigation_host.gd","res://tests/ink_river_hexes_20261006/ordinary01/sim.gd","res://tests/ink_river_hexes_20261006/frontdoor01/floor_session.gd","res://tests/ink_river_hexes_20261006/frontdoor01/navigation_install.gd","res://tests/ink_river_hexes_20261006/frontdoor01/host.gd","res://tests/ink_q1_foundation_20261004/revision02/scripts/ink_sim.gd","res://tests/ink_q2_foundation_20261005/fix01/ink_q2_sim.gd","res://tests/ink_q3_foundation_20261004/fix02/ink_q3_sim.gd","res://tests/ink_e1_ordinary_20261005/candidate01/rain_layer.gd","res://tests/ink_e2_boundary_20261006/ordinary01/e2_base.gd","res://tests/ink_e3_ordinary_20261006/ordinary01/e3_base.gd","res://scripts/combat/hero_combat_core.gd","res://tests/ink_q3_gesture_runtime_20261004/fix01/hero_view.gd","res://scripts/combat/common_hex_bridge.gd","res://scripts/combat/enemy_director.gd","res://tests/ink_enemy_navigation_fix01_20261005/enemy_director.gd","res://tests/ink_q1_h02_20261004/ink_h02_sim.gd","res://tests/ink_q3_foundation_20261004/ink_q3_enemy_director.gd","res://tests/ink_r1_ordinary_20261005/candidate01/enemy_director.gd","res://tests/ink_ultimate_presentation_20261006/r1_consumer01/timed_director.gd"]
static func _deny(reason:String)->Dictionary:return {"accepted":false,"reason":reason}
static func _safe(path:String)->bool:return path.begins_with("res://") and not ".." in path.trim_prefix("res://").split("/")
static func _verify_map(mapped:Dictionary)->Dictionary:
 return P3Gate.verify_legacy_map(mapped)
static func read_capabilities(sim:Node,include_source_adapter_hooks:bool=false)->Dictionary:
 var gameplay:Dictionary=P3Gate.verify()
 if not gameplay.accepted:return gameplay
 if not is_instance_valid(sim) or sim.get_script().resource_path!=SIM_PATH:return _deny("exact_ordinary_sim_required")
 if sim.clock.get_script().resource_path!=Frozen.CLOCK_PATH or sim.enemy_director.get_script().resource_path!=Frozen.DIRECTOR_PATH:return _deny("current_clock_director_required")
 if FileAccess.get_sha256(PARENT_PATH)!=PARENT_SHA:return _deny("frozen_live02_parent_changed")
 if FileAccess.get_sha256(Frozen.PARENT_PATH)!=Frozen.PARENT_SHA:return _deny("frozen_boss_live01_parent_changed")
 var parent:Variant=JSON.parse_string(FileAccess.get_file_as_string(PARENT_PATH))
 var grandparent:Variant=JSON.parse_string(FileAccess.get_file_as_string(Frozen.PARENT_PATH))
 var binding:Variant=JSON.parse_string(FileAccess.get_file_as_string(BINDING_PATH))
 if not parent is Dictionary or not grandparent is Dictionary or not binding is Dictionary:return _deny("successor_binding_missing")
 if parent.get("schema","")!="first-floor-boss-live02" or binding.get("schema","")!="ink-q1-free-curve-visual-successor-1":return _deny("successor_schema_invalid")
 if parent.runtime_map.size()!=1078:return _deny("original_1078_pins_required")
 # Recheck live02's exact inherited substitutions, not just its filename.
 var old_changes:Dictionary=parent.get("ancestor_pin_replacements",{})
 if old_changes.size()!=Frozen.REPLACEMENTS.size():return _deny("parent_exact_replacements_required")
 for path:String in Frozen.REPLACEMENTS:
  if not old_changes.has(path) or not grandparent.runtime_map.has(path):return _deny("parent_replacement_missing:"+path)
 for path:String in grandparent.runtime_map:
  var expected:String=str(grandparent.runtime_map[path])
  if old_changes.has(path):
   var change:Dictionary=old_changes[path]
   if path not in Frozen.REPLACEMENTS or change.get("before","")!=expected or change.get("after","")!=parent.runtime_map.get(path,""):return _deny("parent_replacement_not_exact:"+path)
   expected=str(change.after)
  if parent.runtime_map.get(path,"")!=expected:return _deny("parent_ancestor_pin_changed:"+path)
 if parent.runtime_map.get(Frozen.PARENT_PATH,"")!=Frozen.PARENT_SHA:return _deny("grandparent_pin_missing")
 for item:Dictionary in [parent,binding]:
  if item.get("runtime_candidates",[])!=LEGACY_CANDIDATES or item.get("supported_hex_hooks",[])!=Catalog.FIRST_SLICE_HEX_HOOKS:return _deny("capability_scope_changed")
 if binding.get("parent_path","")!=PARENT_PATH or binding.get("parent_sha256","")!=PARENT_SHA:return _deny("successor_parent_mismatch")
 var changes:Dictionary=binding.get("ancestor_pin_replacements",{})
 var mapped:Dictionary=binding.get("runtime_map",{})
 if changes.size()!=REPLACEMENTS.size():return _deny("exact_nineteen_successor_replacements_required")
 for path:String in REPLACEMENTS:
  if not changes.has(path) or not parent.runtime_map.has(path):return _deny("replacement_not_in_parent:"+path)
 for path:String in parent.runtime_map:
  var expected:String=str(parent.runtime_map[path])
  if changes.has(path):
   var change:Dictionary=changes[path]
   var preimage:String=str(change.get("preimage",""))
   if path not in REPLACEMENTS or change.get("before","")!=expected or change.get("after","")!=mapped.get(path,""):return _deny("replacement_not_exact:"+path)
   if not preimage.begins_with("res://visual_rework_20261009/binding/preimages/") or mapped.get(preimage,"")!=expected:return _deny("replacement_preimage_unpinned:"+path)
   expected=str(change.after)
  if mapped.get(path,"")!=expected:return _deny("ancestor_pin_changed:"+path)
 if mapped.get(PARENT_PATH,"")!=PARENT_SHA:return _deny("parent_pin_missing")
 for mandatory:String in ["res://equipment_prism_20261011/adapter.gd","res://equipment_prism_20261011/model.gd","res://equipment_prism_20261011/passive10.gd","res://equipment_prism_20261011/decision09.json","res://visual_rework_20261009/binding/equipment48_plan.json","res://visual_rework_20261009/binding/c02_source_transition.json","res://visual_rework_20261009/binding/c02_visual_transition.json","res://visual_rework_20261009/binding/g01_navigation_plan.json","res://visual_rework_20261009/binding/g01_navigation_transition.json","res://visual_rework_20261009/binding/g01_evolved_name_plan.json","res://visual_rework_20261009/binding/g01_sync_plan.json","res://visual_rework_20261009/binding/g01_sync_visual_transition.json","res://equipment_scholar_20261011/adapter.gd","res://equipment_scholar_20261011/model.gd","res://equipment_scholar_20261011/task01.gd","res://equipment_scholar_20261011/decision08.json","res://visual_rework_20261009/binding/g01_visual_source_transition.json","res://visual_rework_20261009/binding/equipment47_plan.json","res://visual_rework_20261009/binding/growth_readability_card_plan.json","res://visual_rework_20261009/binding/growth_readability_size_plan.json","res://visual_rework_20261009/readable_layout.gd","res://visual_rework_20261009/binding/growth_readability_plan.json","res://elixir_swift_20261010/runtime.gd","res://elixir_swift_20261010/model.gd","res://elixir_swift_20261010/common_bridge.gd","res://elixir_swift_20261010/session.gd","res://elixir_swift_20261010/panel.gd","res://elixir_swift_20261010/user_decisions.json","res://elixir_swift_20261010/decision07.json","res://visual_rework_20261009/binding/swift05_projection_transition.json","res://visual_rework_20261009/binding/elixir05_plan.json","res://equipment_overload_20261010/adapter.gd","res://equipment_overload_20261010/passive11.gd","res://equipment_overload_20261010/model.gd","res://equipment_overload_20261010/common_bridge.gd","res://equipment_overload_20261010/user_decisions.json","res://visual_rework_20261009/binding/equipment46_plan.json","res://equipment_colossus_20261010/adapter.gd","res://equipment_colossus_20261010/passive26.gd","res://equipment_colossus_20261010/model.gd","res://equipment_colossus_20261010/common_bridge.gd","res://equipment_colossus_20261010/user_decisions.json","res://visual_rework_20261009/binding/equipment45_plan.json","res://equipment_rage_20261010/adapter.gd","res://equipment_rage_20261010/model.gd","res://equipment_rage_20261010/distance_selection.gd","res://equipment_rage_20261010/regen_selection.gd","res://visual_rework_20261009/binding/equipment44_plan.json","res://elixir_war_20261009/model.gd","res://elixir_war_20261009/session.gd","res://elixir_war_20261009/panel.gd","res://elixir_war_20261009/common_bridge.gd","res://elixir_war_20261009/runtime.gd","res://visual_rework_20261009/binding/elixir01_plan.json","res://elixir_hunter_20261009/model.gd","res://elixir_hunter_20261009/panel.gd", "res://elixir_hunter_20261009/session.gd","res://visual_rework_20261009/binding/elixir04_plan.json","res://visual_rework_20261009/binding/postboss_model.gd","res://visual_rework_20261009/binding/postboss_plan.json","res://equipment_expansion_20261009/adapter.gd","res://equipment_expansion_20261009/passive18.gd","res://equipment_expansion_20261009/model.gd","res://visual_rework_20261009/binding/equipment33_plan.json","res://equipment_distance_20261009/adapter.gd","res://equipment_distance_20261009/passives.gd","res://equipment_distance_20261009/model.gd","res://visual_rework_20261009/binding/equipment35_plan.json","res://equipment_kill_20261009/adapter.gd","res://equipment_kill_20261009/passive13.gd","res://equipment_kill_20261009/model.gd","res://visual_rework_20261009/binding/equipment36_plan.json","res://equipment_elite_damage_20261009/adapter.gd","res://equipment_elite_damage_20261009/passive18.gd","res://equipment_elite_damage_20261009/model.gd","res://visual_rework_20261009/binding/equipment37_plan.json","res://equipment_basic_cycle_20261009/adapter.gd","res://equipment_basic_cycle_20261009/passive08.gd","res://equipment_basic_cycle_20261009/model.gd","res://equipment_basic_cycle_20261009/source_adapter.gd","res://visual_rework_20261009/binding/equipment38_plan.json","res://equipment_training_20261009/adapter.gd","res://equipment_training_20261009/task02.gd","res://equipment_training_20261009/model.gd","res://visual_rework_20261009/binding/equipment39_plan.json","res://equipment_pursuit_20261009/adapter.gd","res://equipment_pursuit_20261009/model.gd","res://equipment_pursuit_20261009/source_adapter.gd","res://equipment_pursuit_20261009/passive28.gd","res://equipment_pursuit_20261009/runtime28.gd","res://equipment_pursuit_20261009/common_bridge.gd","res://visual_rework_20261009/binding/equipment40_plan.json","res://equipment_lifeline_20261009/adapter.gd","res://equipment_lifeline_20261009/source_adapter.gd","res://equipment_lifeline_20261009/passive20.gd","res://equipment_lifeline_20261009/model.gd","res://visual_rework_20261009/binding/equipment41_plan.json","res://equipment_blood_trial_20261009/adapter.gd","res://equipment_blood_trial_20261009/task03.gd","res://equipment_blood_trial_20261009/model.gd","res://visual_rework_20261009/binding/equipment42_plan.json","res://equipment_regeneration_20261009/adapter.gd","res://equipment_regeneration_20261009/passive24.gd","res://equipment_regeneration_20261009/model.gd","res://equipment_regeneration_20261009/common_bridge.gd","res://visual_rework_20261009/binding/equipment43_plan.json","res://formal_training_20261009/adapter.gd","res://formal_training_20261009/model.gd","res://formal_training_20261009/session.gd","res://formal_training_20261009/panel.gd","res://visual_rework_20261009/binding/training12_plan.json","res://visual_rework_20261009/binding/beacon_visibility_plan.json","res://visual_rework_20261009/input/q1_free_curve_sampler.gd","res://visual_rework_20261009/binding/bridge.gd","res://visual_rework_20261009/binding/live_binding.gd",VISUAL_PATH]:
  if not mapped.has(mandatory):return _deny("successor_dependency_unpinned:"+mandatory)
 var checked:Dictionary=_verify_map(mapped)
 if not checked.accepted:return checked
 var visual:Variant=JSON.parse_string(FileAccess.get_file_as_string(VISUAL_PATH))
 if not visual is Dictionary or visual.get("schema","")!="ink-visual-dependencies-1" or visual.get("runtime_map",{}).is_empty():return _deny("visual_dependencies_unsealed")
 checked=_verify_map(visual.runtime_map)
 if not checked.accepted:return checked
 var hooks:Array=Catalog.FIRST_SLICE_HEX_HOOKS.duplicate()
 if include_source_adapter_hooks:hooks.append_array(Prior.ADAPTER_HOOKS)
 return {"accepted":true,"reason":"","capabilities":{"schema_version":1,"hero_id":"yanguizhou","source_binding_id":FileAccess.get_sha256(BINDING_PATH),"runtime_candidates":Catalog.FIRST_SLICE_ALLOWED_CANDIDATES.duplicate(),"supported_hooks":hooks,"ordinary_entry_ready":false,"scope":"explicit free-curve input successor; same single ordinary Sim/Session/clock; sealed presentation; art and native acceptance separate"}}
