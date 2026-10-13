extends "res://tests/ink_shop_runtime_stats_20261004/hp_undo_fix01/ink_health_model.gd"
## New explicit allocation policy, not a repair of the old display-slot comment.
## Preserve one eligible personal effect for slot3 until its one refresh is spent.
const InitialConsumer=preload("res://tests/ink_initial_hex_runtime_20261004/ink_initial_stat_consumer.gd")
var _reserve_personal_refresh: bool=false
func _init(definitions: Dictionary={},actor_id: String="local",seed_value: int=1):
 super(definitions,actor_id,seed_value)
 _health_consumer=InitialConsumer.new()
func _apply(action: String,args: Dictionary)->String:
 var previous: bool=_reserve_personal_refresh
 _reserve_personal_refresh=false
 if action=="hex_open":_reserve_personal_refresh=true
 elif action=="hex_refresh":
  var offer: Dictionary=state.offers.get(str(args.get("milestone",0)),{})
  _reserve_personal_refresh=not offer.is_empty() and not bool(offer.refresh_used[3])
 var result: String=super._apply(action,args)
 _reserve_personal_refresh=previous
 return result
func _eligible_hexes(hero_only: bool,excluded: Array)->Array:
 var keys: Dictionary={}
 for id in excluded+state.selected_hex:
  if config.hexes.has(id):keys[config.hexes[id].effect_key]=true
 for offer in state.offers.values():
  if not offer.selected.is_empty():continue
  for id in offer.slots+offer.excluded:
   if config.hexes.has(id):keys[config.hexes[id].effect_key]=true
 var candidates: Array=[]
 var candidate_keys: Dictionary={}
 for id in config.hexes:
  var entry: Dictionary=config.hexes[id]
  if not support(entry).supported or keys.has(entry.effect_key):continue
  if entry.hero not in ["",state.hero_id] or (hero_only and entry.hero!=state.hero_id):continue
  if candidate_keys.has(entry.effect_key):continue
  candidate_keys[entry.effect_key]=true
  candidates.append(id)
 return candidates
func _draw(hero_only: bool,excluded: Array)->String:
 var candidates: Array=_eligible_hexes(hero_only,excluded)
 if not hero_only and _reserve_personal_refresh:
  var personal: Array=candidates.filter(func(id):return config.hexes[id].hero==state.hero_id)
  if personal.size()==1:candidates.erase(personal[0])
 var pool: Array=[]
 var total: int=0
 for id in candidates:
  var entry: Dictionary=config.hexes[id]
  var weight: int=maxi(1,int(entry.weight)/(1+int(state.seen_hex.get(id,0))))
  if not _dependency_met(entry):weight=maxi(1,int(weight*config.policies.hex_unlearned_weight_multiplier))
  total+=weight;pool.append([id,total])
 if pool.is_empty():return ""
 state.rng=(int(state.rng)*48271)%2147483647
 for pair in pool:
  if int(state.rng)%total<int(pair[1]):
   state.seen_hex[pair[0]]=int(state.seen_hex.get(pair[0],0))+1
   return str(pair[0])
 return ""
func initial_pool_readiness()->Dictionary:
 var eligible: Array=_eligible_hexes(false,[])
 var personal: int=eligible.filter(func(id):return config.hexes[id].hero==state.hero_id).size()
 var ready: bool=eligible.size()>=8 and personal>=2
 return {"accepted":ready,"reason":"" if ready else "mandatory_hex_refresh_pool_not_ready","eligible":eligible.size(),"personal":personal,"common":eligible.size()-personal,"guarantee":"all_four_single_refreshes_any_order","scope":"Lv1_single_offer"}
