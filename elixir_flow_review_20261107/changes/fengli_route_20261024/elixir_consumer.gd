extends RefCounted
## Narrow runtime consumer. The original kernel alone owns buying, using and expiry.
const Machine=preload("res://__clean_fengli/machine_template_reader.gd")
const ITEMS=["elixir:01","elixir:04","elixir:05"]
const VALUES_PATH="res://fengli_route_20261024/elixir_values.json"
const VALUES_SHA256="16174649a21d8e342de9ddef7fed81cee045b660306b15a269348f4e0afa5451"
var _values:Dictionary={}
var _sim:WeakRef
var _model:WeakRef
var _actor:WeakRef
var _run:Array=[]
var _battle:Array=[]
var _retired:bool=false
var _war_until:float=0.0
var _stride_until:float=0.0
var _kills:Dictionary={}
var _dashes:Dictionary={}
var _last_hunt_hit:Dictionary={}

func bind(sim:Node,model:RefCounted,definitions:Dictionary)->Dictionary:
 if _sim!=null or not is_instance_valid(sim) or model==null:return {"accepted":false,"reason":"fresh_elixir_binding_required"}
 var checked:Dictionary=Machine.open_commerce()
 if not checked.get("accepted",false):return checked
 for id:String in ITEMS:
  var expected:Dictionary=checked.definitions.items.get(id,{})
  if expected.get("kind","")!="elixir" or definitions.get("items",{}).get(id,{})!=expected:return {"accepted":false,"reason":"elixir_source_parameters_mismatch"}
 if not sim.hero.has_method("bind_elixir_runtime") or not sim.has_method("bind_route_elixir_consumer"):return {"accepted":false,"reason":"elixir_actor_consumer_missing"}
 if FileAccess.get_sha256(VALUES_PATH)!=VALUES_SHA256:return {"accepted":false,"reason":"elixir_values_identity_rejected"}
 var numeric:Variant=JSON.parse_string(FileAccess.get_file_as_string(VALUES_PATH))
 if not numeric is Dictionary or numeric.get("format","")!="fengli-elixir-values-1" or not numeric.get("parameters") is Dictionary:return {"accepted":false,"reason":"elixir_values_invalid"}
 _values=numeric.parameters.duplicate(true)
 for key in _values:
  if not _values[key] is Dictionary:return {"accepted":false,"reason":"elixir_values_invalid"}
  if not (_values[key].get("value") is float or _values[key].get("value") is int):return {"accepted":false,"reason":"elixir_values_invalid"}
  if not is_finite(float(_values[key].value)) or float(_values[key].value)<0.0:return {"accepted":false,"reason":"elixir_values_invalid"}
 for id:String in ITEMS:
  if value(id+".price")!=float(definitions.items[id].price):return {"accepted":false,"reason":"elixir_price_source_mismatch"}
 if not sim.bind_route_elixir_consumer(self):return {"accepted":false,"reason":"elixir_sim_already_bound"}
 _sim=weakref(sim);_model=weakref(model);_actor=weakref(sim.hero)
 _run=[sim.route_run_id,model.state.shop_visit.run_id]
 return {"accepted":true,"reason":""}

func ready()->bool:
 if _retired or _sim==null or _model==null or _actor==null:return false
 var sim:Node=_sim.get_ref()
 var model:RefCounted=_model.get_ref()
 if not is_instance_valid(sim) or model==null or _actor.get_ref()==null:return false
 if not is_same(sim.hero,_actor.get_ref()) or [sim.route_run_id,model.state.shop_visit.run_id]!=_run:return false
 if model._commerce_owner==null or model._commerce_owner.get_ref()==null:return false
 return model.potion_terminal_reason(model._commerce_owner.get_ref()).is_empty()

func active_item()->String:
 if not ready():return ""
 var model:RefCounted=_model.get_ref()
 var visit:Dictionary=model.state.shop_visit
 if model.state.phase!="combat" or bool(model.state.get("actor_dead",false)):return ""
 var actor:RefCounted=_actor.get_ref()
 if actor.dead or actor.hp<=0.0:return ""
 var active:Dictionary=visit.get("active_elixir",{})
 if str(visit.battle_id).is_empty() or active.get("battle_id","")!=visit.battle_id:return ""
 var item:String=str(active.get("item",""))
 return item if item in ITEMS else ""

func static_stats()->Dictionary:
 var item:String=active_item()
 match item:
  "elixir:01":return {"AD":value(item+".ad"),"lifesteal":fraction(item+".lifesteal")}
  "elixir:04":return {"penetration":value(item+".penetration"),"crit_chance":fraction(item+".crit")}
  "elixir:05":return {"attack_speed":fraction(item+".attack_speed"),"cooldown_reduction":fraction(item+".cdr")}
 return {}

func _live_item()->String:
 var item:String=active_item()
 if item.is_empty():return ""
 var sim:Node=_sim.get_ref()
 if sim.hero.dead or sim.hero.hp<=0.0 or sim.phase!="combat":return ""
 return item
func _current_scope()->Array:
 var item:String=_live_item()
 if item.is_empty():return []
 var sim:Node=_sim.get_ref()
 var model:RefCounted=_model.get_ref()
 return [model.state.shop_visit.battle_id,sim.encounter_generation,model.state.shop_visit.active_elixir.effect_id,item]
func _sync_battle()->void:
 var scope:Array=_current_scope()
 if scope!=_battle:clear_battle();_battle=scope

func advance()->void:
 _sync_battle()
 var item:String=_live_item()
 if item.is_empty():return
 var sim:Node=_sim.get_ref()
 # Actor clock advances only in the original unpaused fixed step.
 if float(sim.hero_time)>=_war_until:_war_until=0.0
 if float(sim.hero_time)>=_stride_until:_stride_until=0.0

func value(key:String)->float:
 return float(_values.get(key,{}).get("value",0.0))
func fraction(key:String)->float:
 return value(key)*0.01
func war_fraction()->float:
 if _live_item()!="elixir:01":return 0.0
 return fraction("elixir:01.on_kill_as") if _battle==_current_scope() and float(_sim.get_ref().hero_time)<_war_until else 0.0
func movement_fraction()->float:
 if _live_item()!="elixir:05":return 0.0
 return fraction("elixir:05.move")+(fraction("elixir:05.after_shift_move") if _battle==_current_scope() and float(_sim.get_ref().hero_time)<_stride_until else 0.0)

func killed(enemy:Dictionary,cast_id:int)->void:
 _sync_battle()
 if _live_item()!="elixir:01":return
 var sim:Node=_sim.get_ref()
 if sim.paused or sim.transaction_active or not enemy.get("dead",false) or not is_same(enemy,sim.enemy_by_id(str(enemy.get("actor_id","")))) or not sim.cast_is_current(cast_id):return
 var key:String=str(enemy.actor_id)
 if _kills.has(key):return
 _kills[key]=true
 _war_until=float(sim.hero_time)+value("elixir:01.on_kill_duration")
 advance()

func dash_completed(dash_id:int)->void:
 _sync_battle()
 if _live_item()!="elixir:05":return
 var sim:Node=_sim.get_ref()
 if sim.paused or sim.transaction_active or dash_id<=0 or dash_id!=sim.dash_serial or sim.hero.dash_left>sim.TIME_EPS or _dashes.has(dash_id):return
 _dashes[dash_id]=true
 _stride_until=float(sim.hero_time)+value("elixir:05.after_shift_duration")
 advance()

func final_multiplier(enemy:Dictionary)->float:
 if _live_item()!="elixir:04":return 1.0
 return 1.0+fraction("elixir:04.boss_damage_bonus") if str(enemy.get("kind","")) in ["elite","boss"] else 1.0

func record_damage(enemy:Dictionary,event:Dictionary,actual:float)->void:
 if _live_item()!="elixir:04" or actual<=0.0 or str(enemy.get("kind","")) not in ["elite","boss"]:return
 var sim:Node=_sim.get_ref()
 if not is_same(enemy,sim.enemy_by_id(str(enemy.actor_id))) or not event.has("hero_final_multiplier") or event.get("snapshot_final",false) or event.get("replay",false):return
 _last_hunt_hit={"target":enemy.actor_id,"enemy_kind":enemy.kind,"cast_id":event.get("cast_id",0),"generation":sim.encounter_generation,"battle_id":_model.get_ref().state.shop_visit.battle_id,"source":event.get("source",""),"actual":actual,"nominal_after_final":event.amount,"hero_final_multiplier":event.hero_final_multiplier,"elixir_multiplier":1.0+fraction("elixir:04.boss_damage_bonus")}

func clear_battle()->void:
 _last_hunt_hit.clear()
 _battle.clear();_war_until=0.0;_stride_until=0.0;_kills.clear();_dashes.clear()

func retire()->void:
 clear_battle();_retired=true

func snapshot()->Dictionary:
 var active:Dictionary={}
 var now:float=0.0
 if ready():
  active=_model.get_ref().state.shop_visit.active_elixir.duplicate(true)
  now=float(_sim.get_ref().hero_time)
 return {"supported_items":ITEMS.duplicate() if ready() else [],"active":active,"battle_active":not active_item().is_empty(),"war_seconds":maxf(0.0,_war_until-now) if _live_item()=="elixir:01" and _battle==_current_scope() else 0.0,"stride_seconds":maxf(0.0,_stride_until-now) if _live_item()=="elixir:05" and _battle==_current_scope() else 0.0,"last_hunt_hit":_last_hunt_hit.duplicate(true) if _live_item()=="elixir:04" else {},"move_fraction":movement_fraction(),"attack_speed_fraction":war_fraction(),"clock":"source_actor_combat_seconds"}
