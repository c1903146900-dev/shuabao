extends "res://tests/ink_r1_ordinary_20261005/candidate01/enemy_director.gd"
## Only two bounded hostile-delivery methods need the event-time scope before
## their immunity/status query. No-presentation calls retain exact delegation.
## Mountain interception is preserved from ink_q3_enemy_director.gd.

func step_projectiles(sim, dt: float) -> void:
	if not sim.presentation_timing_needed():
		super.step_projectiles(sim, dt)
		return
	if _frozen(sim):
		return
	var scope: Dictionary = sim._ink_scope()
	# Retain the existing Q3 pre-filter before any original hostile delivery.
	if not sim.ink_mountain.is_empty():
		for projectile: Dictionary in sim.projectiles.duplicate():
			if projectile.get("team", "enemy") != "enemy":
				continue
			var previous: Vector3 = projectile.position
			var travel_dt: float = minf(dt, maxf(0.0, float(projectile.left)))
			var next: Vector3
			var lob: bool = projectile.get("type", "bolt") == "lob"
			if lob:
				var progress: float = clampf(1.0 - (float(projectile.left) - dt) / float(projectile.duration), 0.0, 1.0)
				next = Vector3(projectile.origin).lerp(projectile.target_point, progress)
			else:
				next = previous + Vector3(projectile.direction) * float(projectile.speed) * travel_dt
			var hit: Dictionary = sim._q3_terrain_contact(previous, next, float(projectile.get("radius", 0.14)), {}, travel_dt / maxf(EPS, dt))
			if hit.is_empty():
				continue
			if not lob:
				var clipped: Vector3 = _clip_motion(sim, previous, next, float(projectile.get("radius", 0.14)))
				if previous.distance_squared_to(clipped) + EPS < previous.distance_squared_to(hit.position):
					continue
				var point: Vector2 = Vector2(previous.x - sim.hero.position.x, previous.z - sim.hero.position.z)
				var motion: Vector2 = Vector2(next.x - previous.x, next.z - previous.z)
				var hero_hit: float = sim.Geometry._circle_entry(point, motion, Vector2.ZERO, HERO_RADIUS + float(projectile.get("radius", 0.14)))
				if hero_hit <= float(hit.fraction) + EPS:
					continue
			sim.projectiles.erase(projectile)
			var receipt: Dictionary = hit.duplicate(true)
			receipt.merge({"source_event_id": str(hit.terrain_id) + ":blocked:" + str(projectile.id), "projectile_id": projectile.id, "projectile_type": projectile.get("type", "bolt"), "projectile_owner": projectile.owner, "projectile_team": projectile.get("team", "enemy"), "source": "q3", "origin": previous, "attempted_destination": next, "blocked_before_landing": lob}, true)
			sim.emit_event("ink_q3_projectile_blocked", receipt)
			if not sim._ink_scope_current(scope) or _frozen(sim):
				return
	for projectile: Dictionary in sim.projectiles.duplicate():
		if projectile.get("team", "enemy") != "enemy":
			continue
		var travel_dt: float = minf(dt, maxf(0.0, float(projectile.left)))
		projectile.left -= dt
		if projectile.get("type", "bolt") == "lob":
			var progress: float = clampf(1.0 - projectile.left / projectile.duration, 0.0, 1.0)
			projectile.position = Vector3(projectile.origin).lerp(projectile.target_point, progress)
			projectile.height = sin(progress * PI) * 3.2
			if projectile.left <= EPS:
				_land_zone(sim, projectile)
				if not sim._ink_scope_current(scope):
					return
				sim.projectiles.erase(projectile)
			continue
		var previous: Vector3 = projectile.position
		var next: Vector3 = previous + projectile.direction * projectile.speed * travel_dt
		var clipped: Vector3 = _clip_motion(sim, previous, next, projectile.get("radius", 0.14))
		var radius: float = HERO_RADIUS + float(projectile.get("radius", 0.14))
		if _segment_distance(sim.hero.position, previous, clipped) <= radius:
			# Original collision uses the clipped swept segment. Convert its first
			# circle entry to elapsed WORLD time, then use the current time slice.
			var relative: Vector3 = previous - sim.hero.position
			var motion: Vector3 = clipped - previous
			var fraction: float = sim.Geometry._circle_entry(Vector2(relative.x, relative.z), Vector2(motion.x, motion.z), Vector2.ZERO, radius)
			var elapsed: float = previous.distance_to(clipped) * clampf(fraction, 0.0, 1.0) / maxf(EPS, float(projectile.speed)) if is_finite(fraction) else travel_dt
			if fraction == 1.0 and clipped == next:
				elapsed = travel_dt
			var context: Dictionary = sim.presentation_push_contact(elapsed, "enemy_projectile")
			var immune: bool = sim.hero_damage_immune()
			var control_immune: bool = sim.hero_control_immune()
			if not immune and not control_immune and projectile.get("type", "") == "hex_bolt":
				sim.hero.cast_state.exposed = {"left": 2.4, "duration": 2.4, "multiplier": 1.20, "source": projectile.owner, "label": "易伤 +20%"}
				sim.emit_event("hero_status_applied", {"status": "exposed", "duration": 2.4, "multiplier": 1.20, "source": projectile.owner, "position": sim.hero.position})
			if not sim._ink_scope_current(scope) or _frozen(sim):
				sim.presentation_pop_contact(context)
				return
			sim.damage_hero(projectile.damage, projectile.direction, 0)
			sim.presentation_pop_contact(context)
			if not sim._ink_scope_current(scope):
				return
			sim.projectiles.erase(projectile)
			sim.emit_event("projectile_hit", {"position": sim.hero.position, "type": projectile.get("type", "bolt"), "dodged": immune})
		elif clipped.distance_squared_to(next) > 0.00001 or projectile.left <= EPS:
			sim.projectiles.erase(projectile)
		else:
			projectile.position = next
		if not sim._ink_scope_current(scope) or _frozen(sim):
			return

func step_hostile_zones(sim, dt: float) -> void:
	if not sim.presentation_timing_needed():
		super.step_hostile_zones(sim, dt)
		return
	if _frozen(sim):
		return
	var scope: Dictionary = sim._ink_scope()
	for zone: Dictionary in sim.zones.duplicate():
		if zone.get("team", "") != "enemy":
			continue
		var due: float = clampf(float(zone.tick_left), 0.0, dt)
		zone.left -= dt
		zone.tick_left -= dt
		if zone.tick_left <= EPS:
			zone.tick_left += zone.tick_interval
			if sim.hero.position.distance_to(zone.position) <= zone.radius:
				var context: Dictionary = sim.presentation_push_contact(due, "enemy_zone")
				sim.damage_hero(zone.damage, Vector3.ZERO, 0)
				sim.presentation_pop_contact(context)
				if not sim._ink_scope_current(scope):
					return
				sim.emit_event("enemy_zone_tick", {"position": zone.position, "owner": zone.owner, "radius": zone.radius})
		if zone.left <= EPS:
			sim.zones.erase(zone)
		if not sim._ink_scope_current(scope) or _frozen(sim):
			return
