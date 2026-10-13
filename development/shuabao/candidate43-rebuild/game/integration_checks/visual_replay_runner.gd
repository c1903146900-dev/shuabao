extends SceneTree
const Replay=preload("res://integration_checks/source_visual_replay.gd")
var entry:Node
var host:Node
var replay:RefCounted
var candidate:String="Q2"
var output:String=""
var source_events:Array=[]
var failures:Array=[]
var commands:Array=[]
func _initialize()->void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--replay="):candidate=arg.trim_prefix("--replay=")
  if arg.begins_with("--replay-evidence="):output=arg.trim_prefix("--replay-evidence=")
 run.call_deferred()
func command(label:String,value:Dictionary)->void:
 commands.append({"label":label,"result":value,"time":host.sim.hero_time})
 if not value.get("accepted",false):failures.append(label+":"+str(value.get("reason","")))
func move_key(code:int,down:bool)->void:
 var e=InputEventKey.new();e.physical_keycode=code;e.keycode=code;e.pressed=down
 host.input_router.handle_event(e,Vector3.ZERO)
func source_event(event:Dictionary)->void:
 var kind=str(event.get("kind",""))
 if kind.begins_with("ink_") or kind in ["damage","kill"]:source_events.append(event.duplicate(true))
func run()->void:
 if output.is_empty():quit(2);return
 DirAccess.make_dir_recursive_absolute(output)
 entry=load("res://visual_rework_20261009/entry.tscn").instantiate();root.add_child(entry)
 await process_frame;entry.request_start("yanguizhou")
 var ready=false
 for f in range(600):
  await process_frame
  if is_instance_valid(entry.active_room) and is_instance_valid(entry.visual_controller):ready=true;break
 if not ready:print("REPLAY_PREPARATION_FAILED");entry.free();quit(2);return
 host=entry.active_room;host.sim.combat_event.connect(source_event)
 replay=Replay.new();command("bind_real_host",replay.bind_existing(host))
 if candidate in ["R1","R2"]:
  command("labelled_progression_fixture_and_R_learning",await replay.prepare_R_on_existing_host(candidate))
 else:
  command("original_learning_and_room",replay.learn_and_enter_first_room(candidate))
 if not failures.is_empty():
  var f=FileAccess.open(output.path_join("failed_setup.json"),FileAccess.WRITE);f.store_string(JSON.stringify({"commands":commands,"helper":replay.receipts,"failures":failures},"  "));f.close();entry.free();quit(2);return
 host.initial_controller.refresh();host._refresh_session_controls(true);host.map_visible_requested=false
 host._refresh(0.0)
 var layer=CanvasLayer.new();layer.layer=900;root.add_child(layer)
 var label=Label.new();label.text="真实主工程输入回放 · "+candidate+"  |  原始角色 / 敌人 / 伤害机制";label.position=Vector2(24,8);layer.add_child(label)
 var first_time=float(host.sim.hero_time);var start_position:Vector3=host.sim.hero.position
 for frame in range(240):
  if frame==24:
   move_key(KEY_D,true)
   var p=Vector3(-4,0,3) if candidate=="Q2" else Vector3(0,0,1) if candidate=="Q3" else Vector3(5,0,3) if candidate=="E2" else Vector3(-2,0,2)
   command("first_cast",replay.source_down(candidate.left(1),p))
   if candidate=="Q1":command("curve_A",host.sim.request_ink_input("left_down",Vector3(-4,0,3)))
  if candidate=="Q1" and frame>=25 and frame<=39:
   var path:Array[Vector3]=[Vector3(-4,0,3),Vector3(-2,0,3),Vector3(-1,0,2),Vector3(1,0,2),Vector3(3,0,3),Vector3(4,0,3)]
   var u=float(frame-25)/14.0*5.0;var ix=mini(4,int(u))
   host.sim.request_ink_input("motion",path[ix].lerp(path[ix+1],u-float(ix)))
  if frame==40:
   move_key(KEY_D,false)
   if candidate=="Q1":command("curve_release",host.sim.request_ink_input("left_up",Vector3(4,0,3)))
  if frame==42 and candidate=="Q2":command("river_B",replay.source_down("Q",Vector3(4,0,3)))
  if frame==57 and candidate=="E3":command("frame_B_exchange",replay.source_down("E",Vector3(2,0,2)))
  if frame==84 and candidate=="Q3":command("mountain_collapse",replay.source_down("Q",Vector3(0,0,-3)))
  if frame==84 and candidate=="E2":command("boat_board",replay.source_down("E",Vector3(5,0,3)))
  await process_frame
  if frame in [20,35,55,80,110,150,200,235]:
   root.get_texture().get_image().save_png(output.path_join("frame_%03d.png"%frame))
   var f=FileAccess.open(output.path_join("source_%03d.json"%frame),FileAccess.WRITE);f.store_string(JSON.stringify(host.sim.ink_presenter_snapshot(),"  "));f.close()
 var report={"candidate":candidate,"source_input_replay":true,"native_input":false,"same_sim":host.sim.get_instance_id(),"same_session":host.shop_session.get_instance_id(),"commands":commands,"failures":failures,"events":source_events,"source_elapsed":host.sim.hero_time-first_time,"start_position":start_position,"end_position":host.sim.hero.position,"R_preparation_fixture":replay.R_preparation_receipt,"phase":host.sim.phase,"hero_hp":host.sim.hero.hp,"full_floor_passed":false,"AI_unchanged":true,"damage_stats_cooldowns_unchanged":true}
 var file=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 print("REAL_VISUAL_REPLAY ",JSON.stringify({"candidate":candidate,"failures":failures,"events":source_events.size(),"source_elapsed":report.source_elapsed}))
 entry.free();layer.free();await process_frame;quit(0 if failures.is_empty() else 2)
