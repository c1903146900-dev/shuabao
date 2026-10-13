extends RefCounted
## Compact actual consumer identity. Static track proof lives in actor.proof.
static func capture(actor: Node3D) -> Dictionary:
 var aliases: Dictionary={}
 var exact: bool=actor.carry_ready and actor.proof.status!="HOLD"
 for alias: String in actor.CARRY_ALIASES:
  var expected: String="q1_carry_rotation_only/"+str(actor.CARRY_ALIASES[alias])
  var actual: String=str(actor.clip_names.get(alias,""))
  var animation: Animation=actor.player.get_animation(StringName(actual)) if actor.player!=null and actor.player.has_animation(StringName(actual)) else null
  var window: Dictionary=actor.key_window(animation) if animation!=null else {}
  var authority: Dictionary=actor.proof.get("q1_carry",{}).get("clips",{}).get(alias,{})
  var matched: bool=actual==expected and animation!=null and window==actor.key_windows.get(alias,{}) and authority.get("source_clip","")==actor.CARRY_ALIASES[alias]
  exact=exact and matched
  aliases[alias]={"actual_player_library_name":actual,"source_clip":authority.get("source_clip",""),"actual_imported_window":window,"private_animation_instance_id":animation.get_instance_id() if animation!=null else -1,"exact_carry_consumer":matched}
 return {"schema":"Q1-carry-exact-consumer-1","ready":actor.carry_ready,"accepted":exact,"carry_asset_sha256":actor.carry_binding.get("asset_sha256",""),"intent_ancestor_asset_sha256":actor.intent_binding.get("asset_sha256",""),"visible_mesh_asset_sha256":actor.proof.get("asset_sha256",""),"binding_path":actor.CARRY_BINDING,"aliases":aliases,"base_samples":actor.carry_base_samples.duplicate(true),"active_upper_alias":actor.active_upper,"actual_presented_sample_time":actor.sample_report.get("upper_time",-1.0),"complete_release_seconds":.60,"source_written":false,"art_accepted":false}
