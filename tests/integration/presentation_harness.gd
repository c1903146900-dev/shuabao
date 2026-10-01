extends "res://tests/integration/two_room_input.gd"
## Controlled mechanics-to-presentation checks; UI clicks use InputEvents.
var visual_checks := {}
func start_presentation() -> String:
 call_deferred("run_presentation")
 return "STARTED"
func test_sim(preset: Dictionary) -> void:
 simulation.free()
 for view in views.values(): view.free()
 views.clear()
 motion.clear()
 hero_clip.clear()
 audio_router.last_sequence = -1 # Only this test replaces a simulation instance.
 simulation = Sim.new()
 add_child(simulation)
 simulation.ai_enabled = false
 simulation.auto_finish = false
 simulation.configure_test_loadout(preset)
 simulation.spawn_enemy("minion",Vector3(0,0,-1),10000)
 simulation.spawn_enemy("minion",Vector3(3,0,-1),10000)
 simulation.combat_event.connect(_on_combat_event)
 _sync_views(0)
 _animate(0)
func run_presentation() -> void:
 set_physics_process(false)
 await click(live_hud.allocation)
 await click(live_hud.rows.Q.buy)
 await key(KEY_ESCAPE)
 visual_checks.real_UI_learn_sound = audio_router.counts.get("ui_confirm",0) == 1 and ledger.model.snapshot().skills.Q.rank == 1
 _perform_action("q") # Preparation phase rejection, not held attack polling.
 visual_checks.explicit_reject_sound = audio_router.counts.get("ui_reject",0) == 1
 var reject_before: int = audio_router.counts.get("ui_reject",0)
 for i in 20: _perform_action("attack","",false)
 visual_checks.held_poll_silent = audio_router.counts.get("ui_reject",0) == reject_before
 test_sim({"e":"e2","r":"r2"})
 visual_checks.manual_owner = views.fengli.external_animation and views.fengli.animation_player.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
 var result: Dictionary = simulation.request_action("e",Vector3.FORWARD)
 _animate(0)
 simulation.step(0.08)
 _sync_views(0.08)
 _animate(0.08)
 visual_checks.E2_not_overwritten = result.accepted and motion.fengli.clip == "attack" and motion.fengli.time > 0
 simulation.step(0.3)
 result = simulation.request_action("r",Vector3.FORWARD)
 simulation.step(0.08)
 _sync_views(0.08)
 _animate(0.08)
 visual_checks.R2_not_overwritten = result.accepted and motion.fengli.clip == "ultimate" and motion.fengli.time > 0
 var target: Dictionary = simulation.enemies[0]
 var v: Node = views[target.actor_id]
 var other: Node = views[simulation.enemies[1].actor_id]
 simulation.damage_enemy(target,10,"presentation_probe",9001)
 visual_checks.GLB_flash_bound = v.flash_meshes.size() > 0 and v.flash_meshes[0].material_overlay == v.flash_material
 visual_checks.flash_instance_isolated = other.flash_meshes[0].material_overlay != v.flash_material
 v.sync(target,0.2)
 visual_checks.flash_restored = v.flash_meshes[0].material_overlay == v.original_overlays[0]
 var before: Dictionary = audio_router.counts.duplicate()
 audio_router.combat(simulation.event_log.back())
 visual_checks.replayed_combat_silent = audio_router.counts == before
 simulation.step(2.0) # Let the real E2 landing invulnerability expire.
 simulation.damage_hero(5)
 visual_checks.actual_hurt_sound = audio_router.counts.get("hurt",0) == 1
 test_sim({"r":"r1"})
 simulation.request_action("r",Vector3.FORWARD)
 simulation.step(0.5)
 _sync_views(0.5)
 _animate(0.5)
 var length: float = views.fengli.animation_player.get_animation("ultimate").length
 visual_checks.R1_uses_presenter_time = motion.fengli.clip == "ultimate" and absf(motion.fengli.time/length-0.5/1.1)<0.02
 var pose: float = motion.fengli.time
 simulation.end_encounter("victory")
 _animate(0.5)
 visual_checks.frozen_pose = motion.fengli.time == pose
 live_hud.close_panels()
 _present()
 await click(mute_button)
 visual_checks.GUI_mute = audio_router.sfx.muted and audio_router.sfx.snapshot().active == 0
 visual_checks.muted_suppresses_player = not audio_router.sfx.play_event("hit")
 await click(mute_button)
 audio_router.sfx.stop_all()
 for id in audio_router.sfx.IDS: audio_router.sfx.play_event(id)
 visual_checks.voice_cap = audio_router.sfx.snapshot().active == 8
 audio_router.sfx.set_muted(true)
 var failed := []
 for name in visual_checks:
  if not visual_checks[name]: failed.append(name)
 set_meta("presentation_report",{"checks":visual_checks,"failures":failed,"audio":audio_router.snapshot(),"controlled_fixture":true,"listened":false})
func presentation_report() -> String:
 return JSON.stringify(get_meta("presentation_report",{}))

func show_hit_probe(flash: bool) -> String:
 live_hud.close_panels()
 _present()
 camera.size = 12
 effects.map(func(e): e.node.hide())
 var target: Dictionary = simulation.enemies[0]
 var v: Node = views[target.actor_id]
 v.flash_left = 0.12 if flash else 0.0
 v._apply_flash()
 return "visible flash probe" if flash else "visible baseline"
