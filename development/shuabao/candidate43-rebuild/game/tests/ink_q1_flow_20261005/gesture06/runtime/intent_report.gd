extends RefCounted
## Explicit consumer readback. The old q1_flow proof remains BASE provenance.
static func capture(actor: Node3D) -> Dictionary:
 var aliases: Dictionary={}
 var exact: bool=actor.intent_ready and actor.proof.status!="HOLD"
 for alias: String in actor.INTENT_ALIASES:
  var expected: String="q1_intent_rotation_only/"+str(actor.INTENT_ALIASES[alias])
  var actual: String=str(actor.clip_names.get(alias,""))
  var animation: Animation=actor.player.get_animation(StringName(actual)) if actor.player.has_animation(StringName(actual)) else null
  var window: Dictionary=actor.key_window(animation) if animation!=null else {}
  var authority: Dictionary=actor.proof.get("q1_intent",{}).get("clips",{}).get(alias,{})
  var matched: bool=actual==expected and animation!=null and window==actor.key_windows.get(alias,{}) and authority.get("source_clip","")==actor.INTENT_ALIASES[alias]
  exact=exact and matched
  aliases[alias]={"actual_player_library_name":actual,"expected_intent_library_name":expected,"source_clip":authority.get("source_clip",""),"actual_imported_window":window,"private_animation_instance_id":animation.get_instance_id() if animation!=null else -1,"exact_intent_consumer":matched}
 return {"schema":"Q1-intent-exact-consumer-1","accepted":exact,"intent_asset_sha256":actor.intent_binding.get("asset_sha256",""),"base_flow_asset_sha256":actor.flow_binding.get("asset_sha256",""),"visible_mesh_asset_sha256":actor.proof.get("asset_sha256",""),"intent_binding_path":actor.INTENT_BINDING,"intent_aliases":aliases,"active_upper_alias":actor.active_upper,"actual_presented_sample_time":actor.sample_report.get("upper_time",-1.0),"proof":actor.proof.get("q1_intent",{}),"source_written":false,"art_accepted":false}
