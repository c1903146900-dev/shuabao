extends "res://tests/ink_initial_hex_ui_20261004/fix01/host.gd"
## Thin, isolated read-only sibling. The exact fix01 source/Session/Controller,
## Q07, input, audio, safe clock, death pose and journal remain inherited.
const H02View = preload("res://tests/ink_h02_visual_20261004/revision02/ink_h02_presenter.gd")
const TextProjection = preload("res://tests/ink_initial_vortex_host_20261004/text_projection.gd")
const COMBINED_BINDING := "c997eab5df81084d7ca970c76464389e4cf47954ae8271c1b18ae3a8b27cec7a"
var h02_view: Node3D
var h02_label: Label
var h02_pending: Array = []
var h02_last_batch: Array = []
var h02_sample: Dictionary = {}
var h02_received_pull_events: int = 0
var h02_delivered_pull_events: int = 0
var h02_max_vortices: int = 0

func _combat_event(event: Dictionary) -> void:
 _queue_h02_event(event)
 super._combat_event(event)

func _queue_h02_event(event: Dictionary) -> void:
 # Detach at the original callback; never replay the historical event journal.
 if str(event.get("kind", "")) != "ink_h02_pull": return
 h02_pending.append(event.duplicate(true))
 h02_received_pull_events += 1

func _refresh(delta: float) -> void:
 super._refresh(delta)
 if not is_instance_valid(sim): return
 _present_h02(sim.ink_presenter_snapshot())
 _refresh_local_text()
 _refresh_h02_label()

func _present_h02(ink: Dictionary) -> void:
 if not is_instance_valid(h02_view):
  h02_view = H02View.new(); h02_view.name = "ReadOnlyH02Sibling"; add_child(h02_view)
 # Swapping this array consumes each newly received receipt once. The frozen
 # renderer owns exact current-sample, scope, cast, expiry and rewind rejection.
 var fresh: Array = h02_pending
 h02_pending = []
 h02_last_batch = fresh
 h02_delivered_pull_events += fresh.size()
 h02_view.present(ink, fresh)
 h02_sample = {"scope":ink.get("scope", {}).duplicate(true), "source_time":ink.get("source_time", -1.0), "revision":ink.get("revision", -1), "source_vortices":ink.get("vortices", []).size(), "fresh_pull_events":fresh.size()}
 h02_max_vortices = maxi(h02_max_vortices, int(h02_view.get_diagnostics().get("vortices", 0)))

func _refresh_session_controls(force: bool) -> void:
 super._refresh_session_controls(force)
 _refresh_local_text()

func _refresh_local_text() -> void:
 if shop_session == null or shop_session.ledger == null: return
 var state: Dictionary = shop_session.ledger.model.snapshot()
 if is_instance_valid(shop_panel) and is_instance_valid(shop_panel._title):
  shop_panel._title.text = TextProjection.shop_title(state, initial_flow_diagnostic)
 if is_instance_valid(hud) and is_instance_valid(sim) and str(sim.phase) == "preparation" and not bool(sim.hero.dead):
  # Fix only the false preparation label; combat/death/victory stay upstream.
  hud.buffs.text = TextProjection.preparation_status(bool(sim.paused))

func _refresh_h02_label() -> void:
 if not is_instance_valid(h02_label):
  var layer := CanvasLayer.new(); layer.name = "H02ReadOnlyDiagnostics"; layer.layer = 90; add_child(layer)
  var backdrop := ColorRect.new(); backdrop.position = Vector2(926, 82); backdrop.size = Vector2(332, 98)
  backdrop.color = Color("23333BDD"); backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE; layer.add_child(backdrop)
  h02_label = Label.new(); h02_label.position = Vector2(935, 87); h02_label.size = Vector2(314, 88)
  h02_label.theme = preload("res://tests/ink_style_specimen_20261004/style.gd").ui_theme()
  h02_label.add_theme_font_size_override("font_size", 13); h02_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
  layer.add_child(h02_label)
 var report: Dictionary = h02_view.get_diagnostics()
 h02_label.text = "H02 v2 · 只读表现候选\n真实潭 %d · 当前真实牵引短痕 %d\n源 %.3fs · 本次牵引回执 %d\n动态/听感/首用性能仍待验" % [int(report.get("vortices", 0)), int(report.get("pull_lines", 0)), float(h02_sample.get("source_time", 0.0)), h02_last_batch.size()]
 if str(report.get("status", "")) == "HOLD": h02_label.text += "\nHOLD: " + str(report.get("reason", ""))

func _h02_evidence() -> Dictionary:
 return {"runtime_source_binding":COMBINED_BINDING, "renderer":h02_view.get_diagnostics() if is_instance_valid(h02_view) else {"status":"not_initialized"}, "sample":h02_sample.duplicate(true), "last_fresh_pull_events":h02_last_batch.duplicate(true), "received_pull_events":h02_received_pull_events, "delivered_pull_events":h02_delivered_pull_events, "pending_pull_events":h02_pending.size(), "max_presented_vortices":h02_max_vortices, "visible_diagnostics":h02_label.text if is_instance_valid(h02_label) else "", "first_use_performance":"pending; no H02 warmup or synthetic source manipulation added", "native_dynamic_art_accepted":false, "audio_hearing_accepted":false}

func _write_json(filename: String, contents: Dictionary) -> void:
 var output: Dictionary = contents.duplicate(true)
 output["h02_readonly"] = _h02_evidence()
 if is_instance_valid(hud): output["visible_phase_text"] = hud.buffs.text
 if is_instance_valid(shop_panel) and is_instance_valid(shop_panel._title): output["visible_shop_title"] = shop_panel._title.text
 super._write_json(filename, output)

func _json_safe(value: Variant) -> Variant:
 # Original F8 serializer remains intact. Add detached diagnostics only to its
 # outer actual-frame record, never into source_snapshot or hero_and_enemies.
 if value is Dictionary and value.has("source_snapshot") and value.has("frame_post_draw_index"):
  var frame: Dictionary = value.duplicate(false)
  frame["h02_readonly"] = _h02_evidence()
  return super._json_safe(frame)
 return super._json_safe(value)
