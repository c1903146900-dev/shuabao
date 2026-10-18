extends "res://natural_route_r09_prepare/visible_route_r09.gd"
# Synthetic original input only. No HP, inventory, position, CD or enemy writes.
var last_direction: Vector3 = Vector3.ZERO
var next_shift_attempt: int = 0
# Input-policy hysteresis only; this never writes the actual actor position.
var escaping_boundary: bool = false
func advance_inputs() -> void:
 var previous_due: int = next_input_ms
 super.advance_inputs()
 if next_input_ms == previous_due or Time.get_ticks_msec() >= deadline_ms: return
 if host.finished or host._mainprep_required or host.sim.phase != "combat" or host.sim.paused or host.sim.hero.dead or host.shop_session.panel_open or host.initial_hud.blocks_gameplay_input(): return
 var targets: Array = _visible_enemies()
 var origin: Vector3 = host.sim.hero.position
 var current_edge: float = float(host.sim.arena_half_extent)-maxf(absf(origin.x),absf(origin.z))
 if current_edge<2.0: escaping_boundary=true
 elif current_edge>4.0: escaping_boundary=false
 var inward: Vector3 = -origin.normalized() if origin.length()>0.01 else Vector3.ZERO
 var choices: Array = []
 var directions: Array = []
 if origin.length() > 0.01: directions.append(-origin.normalized())
 if not targets.is_empty():
  var away: Vector3 = (origin-Vector3(targets[0].position)).normalized()
  directions.append_array([away,Vector3(-away.z,0,away.x),Vector3(away.z,0,-away.x)])
 for x: int in [-1,0,1]:
  for z: int in [-1,0,1]:
   if x!=0 or z!=0: directions.append(Vector3(x,0,z).normalized())
 var desired: float = clampf(float(host.sim.hero.stats.attack_range)*0.85,4.0,8.0)
 var selected: Vector3 = Vector3.ZERO
 var best: float = -INF
 var nearest_now: float = INF
 for target: Dictionary in targets: nearest_now=minf(nearest_now,origin.distance_to(target.position))
 for direction: Vector3 in directions:
  # Match original _move key thresholds before collision/visibility prediction.
  direction = Vector3(-1.0 if direction.x < -0.30 else (1.0 if direction.x > 0.30 else 0.0),0.0,-1.0 if direction.z < -0.30 else (1.0 if direction.z > 0.30 else 0.0)).normalized()
  if direction == Vector3.ZERO: continue
  var endpoint: Vector3 = origin+direction
  if not _ground_clear(origin,endpoint,float(host.sim.hero_radius)) or _visible_ground(endpoint).is_empty(): continue
  var nearest: float = desired
  if not targets.is_empty():
   nearest=INF
   for target: Dictionary in targets: nearest=minf(nearest,endpoint.distance_to(target.position))
  var edge_clearance: float = float(host.sim.arena_half_extent)-maxf(absf(endpoint.x),absf(endpoint.z))
  var score: float = -absf(nearest-desired)*2.0 + minf(edge_clearance,4.0)*0.8 + direction.dot(last_direction)*0.35
  if escaping_boundary: score += (edge_clearance-current_edge)*8.0 + direction.dot(inward)
  choices.append({"direction":direction,"edge_clearance":edge_clearance,"nearest_visible":nearest,"score":score})
  if score>best: best=score;selected=direction
 # Runs even while the original Q1 drag advances: movement is not cancelled by it.
 _move(selected)
 last_direction=selected
 _record("visible_boundary_kite",{"position":origin,"hp":host.sim.hero.hp,"visible_enemies":targets.size(),"nearest":nearest_now if is_finite(nearest_now) else -1.0,"chosen_direction":selected,"q_drag_active":not gesture.is_empty(),"escaping_boundary":escaping_boundary,"edge_clearance":current_edge,"candidates":choices}, {"accepted":true,"meaning":"original_key_edges_sent_not_movement_acceptance"})
 if selected!=Vector3.ZERO and (escaping_boundary or nearest_now<4.5) and gesture.is_empty() and host.sim.ink_input.phase=="idle" and float(host.sim.hero.cooldowns.shift)<=0.00001 and float(host.sim.hero.lock_time)<=0.00001 and Time.get_ticks_msec()>=next_shift_attempt:
  next_shift_attempt=Time.get_ticks_msec()+1200
  _release_left()
  var result: Dictionary = _key(KEY_SHIFT,true)
  _key(KEY_SHIFT,false)
  _record("original_shift_attempt",{"direction":selected,"escaping_boundary":escaping_boundary,"nearest_visible":nearest_now if is_finite(nearest_now) else -1.0,"edge_clearance":current_edge},result)

# The runner supplies the already reviewed one-click asynchronous Hex protocol.
var resolve_hex: Callable
func resolve_visible_required_hexes() -> Dictionary:
 if not resolve_hex.is_valid(): return {"accepted":false,"reason":"actual_visible_hex_callback_required"}
 return await resolve_hex.call()
