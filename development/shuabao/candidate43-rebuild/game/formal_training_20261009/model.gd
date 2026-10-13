extends "res://equipment_regeneration_20261009/model.gd"
## Only the original paid draw's support predicate is narrowed. The original
## command owns rollback, RNG, debit, receipts, body records and health sealing.
const TRAINING_CAPS := {"attack_speed":2.5,"cooldown_reduction":0.65,"tenacity":1.0,"crit_chance":1.0}
const TRAINING_ACTOR_KEYS := {"attack_speed":"attack_speed","cooldown_reduction":"cdr","tenacity":"tenacity","crit_chance":"crit_chance"}
var _training_draw_scope: bool = false
var _training_draw_ids: Array = []

func support(definition: Dictionary) -> Dictionary:
 var out: Dictionary = super.support(definition)
 if _training_draw_scope and definition.get("formal_training",false) and str(definition.get("id","")) not in _training_draw_ids:
  out.supported = false
  out.status = "unsupported"
  out["reason"] = "training_effective_cap_reached"
 return out

func training_eligibility_for_stats(effective_stats: Dictionary) -> Dictionary:
 # Pure eligibility over an explicit final-effective view. This is a read-only
 # inspection seam; no caller-supplied projection reaches the paid authority.
 var eligible: Array = []
 var excluded: Dictionary = {}
 if not config.body.get("formal_training_pool",false) or config.body.outcomes.size()!=12:
  return {"accepted":false,"reason":"formal_training12_required","eligible_ids":eligible,"excluded_ids":excluded,"effective_stats":effective_stats.duplicate(true)}
 for stat: String in TRAINING_CAPS:
  var value: Variant = effective_stats.get(TRAINING_ACTOR_KEYS[stat])
  if not (value is int or value is float) or not is_finite(float(value)):
   return {"accepted":false,"reason":"training_effective_stats_unavailable","eligible_ids":[],"excluded_ids":{},"effective_stats":{}}
 for id: String in config.body.outcomes:
  var outcome: Dictionary = config.body.outcomes[id]
  if not super.support(outcome).supported:
   excluded[id] = "unsupported_effect"
   continue
  var stat: String = str(outcome.runtime_stat)
  if TRAINING_CAPS.has(stat) and float(effective_stats[TRAINING_ACTOR_KEYS[stat]]) >= float(TRAINING_CAPS[stat]):
   excluded[id] = "training_effective_cap_reached"
  else:
   eligible.append(id)
 return {"accepted":eligible.size()>=3,"reason":"" if eligible.size()>=3 else "body_pool_exhausted","eligible_ids":eligible,"excluded_ids":excluded,"effective_stats":effective_stats.duplicate(true)}

func training_eligibility() -> Dictionary:
 var sim: Node = _health_sim.get_ref() if _health_sim != null else null
 # The original consumer keeps this effective view synchronized after commands.
 # Reading it includes Common caps and B02/P2. Calling Common.project_stats here
 # would write its cooldown_bonus field, so this predicate never calls it.
 if not is_instance_valid(sim) or sim.common.model == null or not is_same(sim.common.model.get_ref(),self):
  return {"accepted":false,"reason":"training_effective_source_unbound","eligible_ids":[],"excluded_ids":{},"effective_stats":{}}
 var effective: Dictionary = sim.hero.stats.duplicate(true)
 if sim.hero.has_method("critical_chance"): effective.crit_chance = sim.hero.critical_chance()
 return training_eligibility_for_stats(effective)

func _apply_commerce(envelope: Dictionary) -> String:
 if str(envelope.get("operation","")) != "pay_body": return super._apply_commerce(envelope)
 if _training_draw_scope: return "reentrant_training_draw"
 var eligibility: Dictionary = training_eligibility()
 if not eligibility.accepted: return str(eligibility.reason)
 _training_draw_ids = eligibility.eligible_ids.duplicate()
 _training_draw_scope = true
 var reason: String = super._apply_commerce(envelope)
 _training_draw_scope = false
 _training_draw_ids = []
 return reason

func training_status() -> Dictionary:
 var pending: Dictionary = {}
 var completed: int = 0
 for purchase: Dictionary in state.body:
  if str(purchase.get("selected","")).is_empty(): pending = purchase.duplicate(true)
  else: completed += 1
 var options: Array = []
 for id: String in pending.get("candidates",[]):
  if config.body.outcomes.has(id): options.append(config.body.outcomes[id].duplicate(true))
 var eligibility: Dictionary = training_eligibility()
 var reason: String = str(eligibility.reason)
 if not pending.is_empty(): reason = "body_choice_pending"
 if reason.is_empty() and not commerce_definitions.is_empty():
  var quote: Dictionary = LedgerProjection.evaluate(state,commerce_definitions,"pay_body",{"purchase_id":"formal-training-quote:"+str(state.revision)},true)
  if not quote.accepted: reason = str(quote.reason)
 elif reason.is_empty(): reason = "commerce_unbound"
 return {"price":int(config.body.cost),"completed_count":completed,"purchase_count":state.body.size(),"pending":pending,"options":options,
  "eligibility":eligibility,"can_pay":reason.is_empty(),"reason":reason,"token":commerce_token(),"free_available":false,"free_credit_authority":"not_connected",
  "permanent":true,"undoable":false,"equipment_slots_used":0,"potion_slots_used":0}

func snapshot() -> Dictionary:
 var out: Dictionary = super.snapshot()
 out["formal_training"] = training_status()
 return out
