extends RefCounted
## Callable fixture for the existing full-floor/death runner, not a new launcher.
## No source seeding, original command, snapshot, progression, or modal mutation.
## Only exercise_close_reopen emits the two newly created display-only signals.

static func _rect(control: Control) -> Array:
 var rect: Rect2 = control.get_global_rect()
 return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]

static func _connections(button: Button) -> Array:
 var out: Array = []
 for row: Dictionary in button.get_signal_connection_list("pressed"):
  var callback: Callable = row.callable
  var target: Object = callback.get_object()
  out.append({"target_id":target.get_instance_id() if is_instance_valid(target) else 0, "method":str(callback.get_method()), "flags":row.flags})
 return out

static func source_guard(room: Node, entry: Node) -> Dictionary:
 var session: RefCounted = room.shop_session
 var model: RefCounted = session.ledger.model
 return {"host_id":room.get_instance_id(), "sim_id":room.sim.get_instance_id(),
  "session_id":session.get_instance_id(), "model_id":model.get_instance_id(),
  "model_state_sha256":JSON.stringify(model.state).sha256_text(),
  "model_receipts_sha256":JSON.stringify(model.receipts).sha256_text(),
  "settlement_sha256":JSON.stringify(session.settlement).sha256_text(),
  "status":session.status, "node_index":session.node_index,
  "phase":room.sim.phase, "source_time":room.sim.hero_time, "paused":room.sim.paused,
  "hex_modal":session.initial_modal_open, "shop_modal":session.panel_open,
  "return_id":entry.return_button.get_instance_id(), "return_disabled":entry.return_button.disabled,
  "return_connections":_connections(entry.return_button)}

static func sample(room: Node, entry: Node) -> Dictionary:
 var ui: RefCounted = entry._trial_ui._result_summary
 var out: Dictionary = {"source":source_guard(room, entry), "projection":ui.last_projection.duplicate(true),
  "native_OS_click_proven":false, "art_acceptance":"NOT_REVIEWED"}
 if not is_instance_valid(ui._layer): out["view_built"] = false; return out
 out["view_built"] = true
 out["layer_visible"] = ui._layer.visible
 out["layer"] = ui._layer.layer
 out["panel_visible"] = ui._layer.visible and ui._panel.is_visible_in_tree()
 out["panel_rect"] = _rect(ui._panel)
 out["title"] = ui._title.text
 out["subtitle"] = ui._subtitle.text
 out["values"] = []
 for label: Label in ui._values: out["values"].append(label.text)
 out["close_visible"] = ui._layer.visible and ui.close_button.is_visible_in_tree()
 out["open_visible"] = ui._layer.visible and ui.open_button.is_visible_in_tree()
 out["close_rect"] = _rect(ui.close_button)
 out["open_rect"] = _rect(ui.open_button)
 out["close_connections"] = _connections(ui.close_button)
 out["open_connections"] = _connections(ui.open_button)
 return out

static func check_terminal(room: Node, entry: Node, expected_outcome: String) -> Dictionary:
 var row: Dictionary = sample(room, entry)
 var failures: Array[String] = []
 var settlement: Dictionary = room.shop_session.settlement
 var projected: Dictionary = row.projection
 var status: String = "completed" if expected_outcome == "victory" else "defeated"
 if expected_outcome not in ["victory", "defeat"] or room.shop_session.status != status or settlement.get("outcome", "") != expected_outcome:
  failures.append("real_requested_terminal_not_reached")
 if str(settlement.get("run_id", "")) != str(room.shop_session.run_id): failures.append("settlement_run_mismatch")
 if room.shop_session.initial_modal_open or room.shop_session.panel_open or room.initial_hud.hex_draft.is_visible_in_tree() or room.initial_hud.hex_draft.choosing:
  failures.append("mandatory_or_original_modal_still_open")
 if not projected.get("ready", false) or not row.get("panel_visible", false): failures.append("summary_not_visible")
 for pair: Array in [["gold_balance", "gold"], ["level", "level"], ["remaining_xp", "remaining_xp"]]:
  if projected.get(pair[0]) != settlement.get(pair[1]): failures.append("summary_source_value_mismatch:" + str(pair[0]))
 if int(projected.get("completed_nodes", -1)) != room.shop_session.node_index: failures.append("summary_row_count_mismatch")
 if row.get("view_built", false):
  var ui: RefCounted = entry._trial_ui._result_summary
  var viewport: Rect2 = room.get_viewport().get_visible_rect()
  if not viewport.encloses(ui._panel.get_global_rect()) or not viewport.encloses(ui.close_button.get_global_rect()): failures.append("summary_or_close_outside_viewport")
  if row.title != ("第一层完成！" if expected_outcome == "victory" else "本局结束"): failures.append("summary_title_mismatch")
  var expected_values: Array = [str(settlement.gold), str(projected.get("credited_kills", 0)) if projected.get("kill_count_available", false) else "未记录", str(settlement.level), str(settlement.remaining_xp)]
  if row["values"] != expected_values: failures.append("actual_summary_label_mismatch")
  if int(row.layer) >= 110: failures.append("summary_above_mandatory_hex_layer")
 var model: RefCounted = room.shop_session.ledger.model
 var ids: Dictionary = {}
 var proof_missing: bool = false
 for value: Variant in model.state.reward_ids:
  var id: String = str(value)
  if not id.begins_with(str(room.shop_session.run_id) + "|"): continue
  var receipt: Dictionary = model.receipts.get("ink-reward:" + id, {})
  var request: Dictionary = receipt.get("request", {})
  var args: Dictionary = request.get("args", {})
  if not receipt.get("result", {}).get("accepted", false) or request.get("action") != "reward_minion" or args.get("event_id") != id: proof_missing = true
  ids[id] = true
 if proof_missing and projected.get("kill_count_available", false): failures.append("kill_count_invented_without_receipts")
 if not proof_missing and (not projected.get("kill_count_available", false) or int(projected.get("credited_kills", -1)) != ids.size()): failures.append("credited_kills_mismatch")
 return {"accepted":failures.is_empty(), "failures":failures, "actual":row}

static func check_pending_hex_yields(room: Node, entry: Node) -> Dictionary:
 var row: Dictionary = sample(room, entry)
 var actual_hex: bool = room.shop_session.initial_modal_open or room.initial_hud.hex_draft.is_visible_in_tree() or room.initial_hud.hex_draft.choosing
 return {"accepted":actual_hex and not row.get("panel_visible", false) and not row.get("open_visible", false), "actual_hex_modal":actual_hex, "actual":row}

# Invoke around the runner's original chooser/shop/Hex actions. This helper
# observes them; it never triggers, closes or bypasses an original modal.
static func check_yields_to_original(room: Node, entry: Node, reason: String) -> Dictionary:
 var row: Dictionary = sample(room, entry)
 var actual: bool = false
 match reason:
  "chooser": actual = int(entry.screen) == 0 and room.process_mode == Node.PROCESS_MODE_DISABLED
  "hex": actual = room.shop_session.initial_modal_open or room.initial_hud.hex_draft.is_visible_in_tree() or room.initial_hud.hex_draft.choosing
  "shop": actual = room.shop_session.panel_open
  "diagnostics": actual = room.diagnostic
  "growth": actual = room.initial_hud.growth_panel.is_visible_in_tree()
 return {"accepted":actual and not row.get("panel_visible", false) and not row.get("open_visible", false), "requested_context":reason, "context_observed":actual, "actual":row}

# Call only on a real postdraw terminal, under the caller's existing independent
# watchdog. Does not open/close a shop or Hex, choose a hero, or start another run.
static func exercise_close_reopen(room: Node, entry: Node) -> Dictionary:
 var before: Dictionary = source_guard(room, entry)
 var ui: RefCounted = entry._trial_ui._result_summary
 if not is_instance_valid(ui.close_button) or not ui.close_button.is_visible_in_tree() or ui.close_button.disabled:
  return {"accepted":false, "reason":"visible_display_close_required"}
 ui.close_button.pressed.emit()
 await RenderingServer.frame_post_draw
 if not is_instance_valid(room) or not is_instance_valid(entry) or entry.active_room != room: return {"accepted":false, "reason":"owner_changed_after_close"}
 var closed: Dictionary = sample(room, entry)
 if source_guard(room, entry) != before or closed.get("panel_visible", true) or not closed.get("open_visible", false):
  return {"accepted":false, "reason":"display_close_failed_or_source_changed", "actual":closed}
 if ui.open_button.disabled or not room.get_viewport().get_visible_rect().encloses(ui.open_button.get_global_rect()):
  return {"accepted":false, "reason":"display_reopen_unreachable"}
 ui.open_button.pressed.emit()
 await RenderingServer.frame_post_draw
 if not is_instance_valid(room) or not is_instance_valid(entry) or entry.active_room != room: return {"accepted":false, "reason":"owner_changed_after_reopen"}
 var reopened: Dictionary = sample(room, entry)
 return {"accepted":source_guard(room, entry) == before and reopened.get("panel_visible", false), "closed":closed, "reopened":reopened, "input_kind":"SYNTHETIC_DISPLAY_BUTTON_SIGNALS_ONLY"}
