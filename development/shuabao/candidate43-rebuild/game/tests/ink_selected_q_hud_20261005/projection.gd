extends RefCounted
## Detached read-only projection. Never calls action, input, time, or progression APIs.
const Design = preload("res://data/final_design/catalog.gd")
const SOURCE_PATH := "res://tests/ink_q3_foundation_20261004/fix02/ink_q3_sim.gd"
const SCHEMA := "ink-selected-q-hud-1"

static func capture_context(source: Node) -> Dictionary:
 if not is_instance_valid(source) or source.get_script().resource_path != SOURCE_PATH: return {}
 var mountain: Dictionary = source.ink_mountain
 return {"schema":SCHEMA, "source_instance":source.get_instance_id(), "generation":source.encounter_generation,
  "room_id":source.room_id, "hero_time":source.hero_time, "revision":source.revision,
  "candidate":str(source.hero.loadout.q), "rank":int(source.hero.ranks.q), "paused":source.paused,
  "dead":source.hero.dead, "phase":source.phase, "epsilon":source.TIME_EPS,
  "rules_match":source.source_rules_hash == source.EXPECTED_RULES_HASH,
  "controlled":source._ink_action_controlled("q"), "transaction_active":source.transaction_active,
  "lock_time":source.hero.lock_time, "dash_left":source.hero.dash_left,
  "mountain_current":not mountain.is_empty() and source.effect_is_current(mountain) and not bool(mountain.get("retired",false)),
  "terrain_id":str(mountain.get("terrain_id","")), "cast_id":int(mountain.get("cast_id",0)),
  "expires_at":float(mountain.get("expires_at",-1.0))}.duplicate(true)

static func _context_matches(full: Dictionary, context: Dictionary, candidate: String, rank: int) -> bool:
 var hero: Dictionary = full.get("hero",{})
 return context.get("schema","") == SCHEMA and int(context.get("source_instance",0)) > 0 \
  and context.get("generation",-1) == full.get("generation",-2) \
  and context.get("room_id","") == full.get("room_id","?") \
  and context.get("hero_time",-1.0) == full.get("hero_time",-2.0) \
  and context.get("revision",-1) == full.get("revision",-2) \
  and context.get("candidate","?") == candidate and context.get("rank",-1) == rank \
  and context.get("phase","") == full.get("phase","?") \
  and context.get("paused",false) == full.get("paused",true) \
  and context.get("dead",false) == hero.get("dead",true) \
  and context.get("dash_left",-1.0) == hero.get("dash_left",-2.0)

static func model_from(full: Dictionary, ink: Dictionary, context: Dictionary = {}) -> Dictionary:
 var hero: Dictionary = full.get("hero",{})
 var loadout: Dictionary = hero.get("loadout",{})
 var ranks: Dictionary = hero.get("ranks",{})
 var cooldowns: Dictionary = hero.get("cooldowns",{})
 var known: bool = loadout.has("q") and ranks.has("q")
 var candidate: String = str(loadout.get("q",""))
 var rank: int = int(ranks.get("q",0))
 var supported: bool = candidate in ["q1","q3"]
 var learned: bool = known and supported and rank > 0
 var name: String = str(Design.skill("yanguizhou",candidate).get("name",candidate.to_upper())) if supported else ("Q未学习" if known and rank == 0 else "Q待同步")
 var rank_text: String = "%d级" % rank if learned else ("未学" if known and rank == 0 else ("未接" if known and not supported else "待核"))
 var cooldown: float = float(cooldowns.get("q",-1.0))
 var cooldown_known: bool = cooldowns.has("q") and is_finite(cooldown) and cooldown >= 0.0
 var current: bool = _context_matches(full,context,candidate,rank)
 var epsilon: float = float(context.get("epsilon",0.0))
 var mountain: Dictionary = ink.get("mountain",{})
 var scope: Dictionary = ink.get("scope",{})
 var same_ink: bool = scope.get("generation",-1) == full.get("generation",-2) and scope.get("room_id","") == full.get("room_id","?") and ink.get("source_time",-1.0) == full.get("hero_time",-2.0)
 var live: bool = learned and candidate == "q3" and current and same_ink and bool(context.get("mountain_current",false)) \
  and not mountain.is_empty() and not str(mountain.get("terrain_id","")).is_empty() \
  and mountain.get("terrain_id","") == context.get("terrain_id","?") and int(mountain.get("cast_id",0)) > 0 \
  and mountain.get("cast_id",0) == context.get("cast_id",-1) \
  and mountain.get("generation",-1) == full.get("generation",-2) and mountain.get("room_id","") == full.get("room_id","?") \
  and mountain.get("expires_at",-1.0) == context.get("expires_at",-2.0) \
  and is_finite(float(mountain.get("expires_at",NAN))) \
  and float(full.get("hero_time",INF)) < float(mountain.get("expires_at",-1.0)) - epsilon
 var reason: String = ""
 if not learned: reason = "unlearned" if known and rank == 0 else "unsupported_or_unknown"
 elif not current: reason = "context_unavailable"
 elif bool(hero.get("dead",false)): reason = "not_alive"
 elif bool(full.get("paused",false)): reason = "paused"
 elif str(full.get("phase","")) != "combat": reason = "safe_or_finished"
 elif not bool(context.get("rules_match",false)): reason = "source_binding_mismatch"
 elif bool(context.get("transaction_active",false)): reason = "transaction_in_progress"
 elif bool(context.get("controlled",false)): reason = "controlled"
 elif float(context.get("lock_time",0.0)) > epsilon: reason = "action_locked"
 elif candidate == "q3" and float(context.get("dash_left",0.0)) > epsilon: reason = "dashing"
 elif candidate == "q3" and not mountain.is_empty() and not live: reason = "mountain_unverified"
 elif not live and not cooldown_known: reason = "cooldown_unknown"
 elif not live and cooldown > epsilon: reason = "cooldown"
 var recast_ready: bool = live and reason.is_empty()
 var cooldown_text: String = "CD %.1fs" % cooldown if learned and cooldown_known else "CD —"
 var labels: Dictionary = {"":"倒山可用" if live else "就绪", "unlearned":"未学习", "unsupported_or_unknown":"尚未接入/待同步", "context_unavailable":"状态待同步", "not_alive":"已倒下", "paused":"已暂停", "safe_or_finished":"非战斗区域", "source_binding_mismatch":"来源不匹配", "transaction_in_progress":"结算中", "controlled":"受控中", "action_locked":"动作中", "dashing":"闪避中", "mountain_unverified":"山体状态待同步", "cooldown_unknown":"冷却待同步", "cooldown":"冷却中"}
 var detail: String = "Q · %s · %s\n%s" % [name,rank_text,str(labels.get(reason,reason))]
 if learned and cooldown_known:
  detail += "\n%s冷却 %.3f 秒（源状态）" % ["起山" if candidate == "q3" else "技能",cooldown]
 if live:
  detail += "\n当前山体仍存在；倒山可绕过起山冷却\n山体剩余 %.3f 秒（源英雄时间）" % maxf(0.0,float(mountain.expires_at)-float(full.hero_time))
 if learned:
  detail += "\n" + ("Q预备 → 左键按下起山/倒山；右键或Esc取消瞄准" if candidate == "q3" else "Q预备 → 左键拖线 → 松开释放；右键或Esc取消绘线")
  detail += "\n\n" + Design.description("yanguizhou",candidate,rank)
 else: detail += "\n请在学习面板选择Q1飞流三千或Q3溪山行旅"
 return {"schema":SCHEMA,"candidate":candidate,"name":name,"rank":rank,"rank_text":rank_text,
  "learned":learned,"icon":candidate if supported else "unlearned", "cooldown":cooldown,
  "cooldown_known":cooldown_known,"cooldown_text":cooldown_text,"q3_live":live,"recast_ready":recast_ready,
  "ready":learned and reason.is_empty(),"reason":reason,"status":str(labels.get(reason,reason)),"tooltip":detail,
  "rank_source":"hero.loadout.q + hero.ranks.q","cooldown_source":"hero.cooldowns.q",
  "recast_source":"exact source effect_is_current + scope + hero_time + expires_at; no wall clock"}
