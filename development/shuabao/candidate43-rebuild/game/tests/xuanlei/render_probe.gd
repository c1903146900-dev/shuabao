extends Node
## GUI-only controlled rendering probe, NOT natural-play balance. Runs an isolated max-level build.
var room: Node
var count := 8
var duration := 12.0
var elapsed := 0.0
var samples: Array = []
var drawcalls: Array = []
var report := {}
var node_start := 0
var resource_start := 0
var running := false
var cooldown := 0.0
var previous_usec := 0
var process_samples: Array = []
var physics_samples: Array = []
func begin(host: Node, amount: int, seconds := 12.0) -> Dictionary:
 room=host
 count=amount
 duration=seconds
 var spec={"level":18,"skills":{"P":{"candidate":"P1","rank":3},"Q":{"candidate":"Q3","rank":5},"E":{"candidate":"E2","rank":5},"R":{"candidate":"R2","rank":3}},"items":["duelist_edge","rapid_blade","bastion_shell","sanguine_edge","living_shell","thrust_spike"],"hexes":[]}
 var result: Dictionary=room._enter_test_loadout(spec)
 if not result.accepted:return result
 room.pressure_count=count
 room.manual_step=true
 room.live_hud.close_panels()
 if count>0: room.start_room()
 room.simulation.auto_finish=false
 room.simulation.hero.invulnerable_left=9999
 for enemy in room.simulation.enemies:
  enemy.hp=1000000.0
  enemy.max_hp=1000000.0
 node_start=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
 resource_start=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
 previous_usec=Time.get_ticks_usec()
 running=true
 return {"accepted":true,"scope":"GUI rendering probe; immortal enemies/hero; isolated 18-point six-item ledger","count":count}
func _physics_process(dt: float) -> void:
 if not running or count<=0:return
 var sim=room.simulation
 var toward: Vector3=Vector3(cos(elapsed*0.4),0,sin(elapsed*0.4))
 sim.hero.move_intent=toward*0.65
 var aim: Vector3=sim.enemies[0].position if not sim.enemies.is_empty() else Vector3.ZERO
 sim.hero.facing=sim.hero.position.direction_to(aim)
 sim.request_action("attack",aim)
 cooldown-=dt
 if cooldown<=0:
  sim.request_action("q",aim)
  sim.request_action("e",aim)
  sim.request_action("r",aim)
  cooldown=0.4
 sim.step(dt)
func _process(dt: float) -> void:
 if not running:return
 var now:=Time.get_ticks_usec()
 var wall_dt:=float(now-previous_usec)/1000000.0
 previous_usec=now
 elapsed+=wall_dt
 if elapsed>3:
  samples.append(wall_dt*1000)
  process_samples.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
  physics_samples.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
  drawcalls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
 if elapsed>=duration+3:
  running=false
  samples.sort()
  drawcalls.sort()
  process_samples.sort()
  physics_samples.sort()
  var total:=0.0
  for value in samples:total+=value
  report={"count":count,"warmup_seconds":3,"sample_seconds":elapsed-3,"frames":samples.size(),"mean_ms":total/maxi(1,samples.size()),"median_process_ms":process_samples[process_samples.size()/2],"median_physics_ms":physics_samples[physics_samples.size()/2],"timing_source":"monotonic wall clock; engine dt can clamp during overload","p50_ms":samples[samples.size()/2],"p95_ms":samples[mini(samples.size()-1,int(samples.size()*0.95))],"max_ms":samples.back(),"median_drawcalls":drawcalls[drawcalls.size()/2],"nodes_start":node_start,"nodes_end":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"resources_start":resource_start,"resources_end":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"memory_static_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"active_effects":room.effects.size(),"scope":"Actual Godot GUI/software renderer; controlled immortal stress fixture, not natural playthrough"}
  DirAccess.make_dir_recursive_absolute("res://.local/render-probes")
  var file:=FileAccess.open("res://.local/render-probes/%d.json" % count,FileAccess.WRITE)
  if file:file.store_string(JSON.stringify(report,"  "))
  room.manual_step=false
  room.simulation.phase="victory"
  room.ledger.end_encounter()
  room._enter_test_loadout({"return_normal":true})
  print("XUANLEI_RENDER_PROBE ",JSON.stringify(report))
  queue_free()
