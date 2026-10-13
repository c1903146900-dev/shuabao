extends SceneTree
const Replay=preload("res://integration_checks/postboss_replay.gd")
var entry:Node
var host:Node
var helper:RefCounted
var output=""
var report={"fixture":"original route rewards with explicit lethal source damage; not natural gameplay","checks":[],"screens":[]}
func _initialize()->void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--ui-output="):output=arg.trim_prefix("--ui-output=")
 run.call_deferred()
func ui_nodes(node:Node,result:Array)->void:
 if node is Button and node.is_visible_in_tree():result.append({"path":str(node.get_path()),"text":node.text,"disabled":node.disabled,"rect":str(node.get_global_rect()),"tooltip":node.tooltip_text})
 for child in node.get_children():ui_nodes(child,result)
func capture(label:String)->void:
 var buttons:Array=[];ui_nodes(root,buttons)
 var data={"label":label,"buttons":buttons,"session":host.shop_session.snapshot(),"state":host.shop_session.ledger.model.snapshot(),"modal":host.shop_session.initial_modal_open,"panel_open":host.shop_session.panel_open,"phase":host.sim.phase,"paused":host.sim.paused,"floor_error":host.floor_error}
 report.screens.append(data)
 root.get_texture().get_image().save_png(output.path_join(label+".png"))
 var f=FileAccess.open(output.path_join(label+".json"),FileAccess.WRITE);f.store_string(JSON.stringify(data,"  "));f.close()
func run()->void:
 DirAccess.make_dir_recursive_absolute(output)
 entry=load("res://visual_rework_20261009/entry.tscn").instantiate();root.add_child(entry)
 await process_frame;entry.request_start("yanguizhou")
 for frame in range(600):
  await process_frame
  if is_instance_valid(entry.visual_controller):break
 if not is_instance_valid(entry.visual_controller):quit(2);return
 host=entry.active_room;helper=Replay.new();report.checks.append(helper.bind_existing(host))
 var prepared:Dictionary=await helper.prepare_R_on_existing_host("R1");report.checks.append(prepared)
 if not prepared.get("accepted",false):entry.free();quit(3);return
 var kills:Array=[]
 for frame in range(240):
  await process_frame
  if host.shop_session.status in ["completed","faulted","defeated"]:break
  for enemy in host.sim.living().duplicate():
   var amount=float(enemy.hp)+100000.0;kills.append({"id":enemy.actor_id,"amount":amount,"source_time":host.sim.hero_time})
   host.sim.damage_enemy(enemy,amount,"postboss_ui_lethal_fixture",0,true,false,{"direct":false,"no_reactions":true,"fixture":true})
 report["Boss_fixture_packets"]=kills
 for n in range(5):await process_frame
 capture("01_boss_completed")
 report.checks.append(helper.resolve_required_hexes())
 for n in range(5):await process_frame
 host.growth_toggle.emit_signal("pressed")
 for n in range(5):await process_frame
 capture("02_growth")
 host._shop(true)
 for n in range(5):await process_frame
 capture("03_shop")
 var buy_args:Dictionary=host.shop_session.ledger.model.commerce_token();buy_args["item"]="potion:1"
 report.checks.append(host.shop_session.submit("postboss-buy-potion", "buy",buy_args))
 host._shop(false)
 for n in range(5):await process_frame
 capture("04_shop_closed")
 var model=host.shop_session.ledger.model
 report["before_potion"]=model.snapshot()
 var potion_uid=-1
 for item in model.state.inventory:
  if item.id=="potion:1":potion_uid=int(item.uid)
 if potion_uid>=0:report["terminal_potion_result"]=model.use_potion(host.shop_session,"postboss-new-potion",potion_uid)
 for n in range(15):await process_frame
 report["after_potion"]=model.snapshot()
 capture("05_after_potion_attempt")
 report["completed"]=host.shop_session.status=="completed";report["same_session"]=host.shop_session.get_instance_id();report["same_sim"]=host.sim.get_instance_id()
 var f=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
 entry.free();await process_frame;quit(0 if report.completed else 4)
