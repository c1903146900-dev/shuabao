extends RefCounted
## Explicit successor source binding. Frozen exact-Sim checks stay untouched.
## Q and P use their original renderer; this file owns only read-only projection.
const PriorProjection = preload("res://tests/ink_selected_q_hud_20261005/projection.gd")
const PriorHUD = preload("res://tests/ink_selected_q_hud_20261005/fix01/hud_patch.gd")
const PriorPCard = preload("res://tests/ink_p1_ordinary_20261006/candidate01/ordinary01/p_hud.gd")
const Design = preload("res://data/final_design/catalog.gd")
const Binding = preload("res://tests/ink_e3_ordinary_20261006/ordinary01/live_binding.gd")

static func capture_context(source: Node) -> Dictionary:
 if not is_instance_valid(source) or source.get_script().resource_path != Binding.SIM_PATH: return {}
 var mountain: Dictionary = source.ink_mountain
 return {"schema":PriorProjection.SCHEMA,"source_instance":source.get_instance_id(),"generation":source.encounter_generation,"room_id":source.room_id,"hero_time":source.hero_time,"revision":source.revision,"candidate":str(source.hero.loadout.q),"rank":int(source.hero.ranks.q),"paused":source.paused,"dead":source.hero.dead,"phase":source.phase,"epsilon":source.TIME_EPS,"rules_match":source.source_rules_hash==source.EXPECTED_RULES_HASH,"controlled":source._ink_action_controlled("q"),"transaction_active":source.transaction_active,"lock_time":source.hero.lock_time,"dash_left":source.hero.dash_left,"mountain_current":not mountain.is_empty() and source.effect_is_current(mountain) and not bool(mountain.get("retired",false)),"terrain_id":str(mountain.get("terrain_id","")),"cast_id":int(mountain.get("cast_id",0)),"expires_at":float(mountain.get("expires_at",-1.0))}

static func _apply_q(hud: Control, source: Node) -> Dictionary:
 var context: Dictionary = capture_context(source)
 var shown: Dictionary = PriorHUD.apply_to(hud,source.snapshot(),source.ink_presenter_snapshot(),context)
 hud.footer.text = str(hud.INPUT_HELP).replace("Q预备→左键拖线/松开释放","Q→左键放孤烟；再Q→左键放落日") if source.hero.loadout.q == "q2" and int(source.hero.ranks.q) > 0 else str(hud.INPUT_HELP)
 if source.hero.loadout.q != "q2" or int(source.hero.ranks.q) <= 0: return shown
 var rank: int = int(source.hero.ranks.q)
 var pending: Dictionary = source.ink_q2_pending
 var live: bool = not pending.is_empty() and source.effect_is_current(pending) and source.hero_time < float(pending.expires_at)-source.TIME_EPS
 var remaining: float = maxf(0.0,float(pending.get("expires_at",source.hero_time))-source.hero_time) if live else 0.0
 var cooldown: float = float(source.hero.cooldowns.q)
 var detail: String = Design.description("yanguizhou","q2",rank)
 detail += "\n\nQ → 左键放孤烟；再 Q → 左键放落日。首标窗口5秒，放置首标不开始冷却；窗口到期消标，或合法完成二段时开始冷却。右键/Esc/失焦仅取消瞄准，不删除已放孤烟。\n河生成时已在河内的敌人立即受伤；后来首次触碰立即受伤，每河每敌一次。同一己方BASIC/Shift弹体跨所有河合计只增强一次。\n首标剩余 %.3f 秒；技能冷却 %.3f 秒（源英雄时间；暂停冻结）\nQ2临时功能显示，美术/音频未实现；原Q2证据属于父版本，本E3/E2/P1/R1/E1组合原生未验。H03/H04未开放" % [remaining,cooldown]
 shown = {"candidate":"q2","name":"长河落日","rank":rank,"rank_text":"%d级"%rank,"learned":true,"icon":"unlearned","cooldown":cooldown,"cooldown_text":"续 %.1fs"%remaining if live else "CD %.1fs"%cooldown,"q3_live":false,"recast_ready":live and source._q2_input_reason().is_empty(),"q2_marker_live":live,"marker_remaining":remaining,"tooltip":detail,"temporary_art":true,"q2_audio_implemented":false}
 var patch: Control = hud.get_node_or_null(NodePath(PriorHUD.PATCH_NAME))
 if patch != null:
  patch.projected = shown.duplicate(true); patch.tooltip_text = detail; patch.queue_redraw()
 hud.q_label.text = "长河落日"; hud.q_rank_label.text = shown.rank_text; hud.q_cooldown.text = shown.cooldown_text
 hud.source_model["q_rank"] = shown.rank_text; hud.source_model["q_learned"] = true; hud.source_model["q_cooldown"] = shown.cooldown_text; hud.source_model["selected_q"] = shown.duplicate(true)
 return shown

static func apply_to(hud: Control, source: Node) -> Dictionary:
 if not is_instance_valid(source) or source.get_script().resource_path != Binding.SIM_PATH:
  return {"accepted":false,"reason":"exact_e3_ordinary_sim_required"}
 var shown: Dictionary = _apply_q(hud,source)
 if source._e1_form_current():
  shown["recast_ready"] = false; shown["ready"] = false
  shown["reason"] = "rain_form_forbids_action"
  shown["tooltip"] = str(shown.get("tooltip","")) + "\n烟雨期间禁止新Q；已有山体/河流和计时保留"
  var patch: Control = hud.get_node_or_null(NodePath(PriorHUD.PATCH_NAME))
  if patch != null:
   patch.projected = shown.duplicate(true); patch.tooltip_text = str(shown.tooltip); patch.queue_redraw()
  hud.source_model["selected_q"] = shown.duplicate(true)
 if source.hero.loadout.e == "e1" and int(source.hero.ranks.e) > 0:
  var q_help: String = "Q→左键孤烟；再Q→左键落日" if source.hero.loadout.q == "q2" else ("Q→左键起山/倒山" if source.hero.loadout.q == "q3" else "Q→左键拖线/松开" if source.hero.loadout.q == "q1" else "Q未学习")
  hud.footer.text = "WASD · " + q_help + " · E按住入形/松开聚形 · Space暂停"
 return shown

static func _q_help(source: Node) -> String:
 if int(source.hero.ranks.q) <= 0: return "Q未学习"
 return "Q→左键孤烟；再Q→左键落日" if source.hero.loadout.q == "q2" else ("Q→左键起山/倒山" if source.hero.loadout.q == "q3" else "Q→左键拖线/松开" if source.hero.loadout.q == "q1" else "Q未学习")

static func input_help(source: Node) -> String:
 var e_help: String = "E未学习"
 if int(source.hero.ranks.e) > 0:
  e_help = "E放A；松开后5秒内再E放B" if source.hero.loadout.e == "e3" else ("E朝鼠标发舟；松开后再E登舟" if source.hero.loadout.e == "e2" else "E按住入形/松开聚形")
 return "WASD · " + _q_help(source) + " · " + e_help + " · R→左键 · Space暂停"

static func p_model_from(source: Node) -> Dictionary:
 if not is_instance_valid(source) or source.get_script().resource_path != Binding.SIM_PATH: return {"accepted":false,"reason":"exact_e3_ordinary_sim_required"}
 var rank: int = int(source.hero.ranks.passive)
 var learned: bool = source.hero.loadout.passive == "p1" and rank > 0
 var detail: String = "P1 计白当黑 · "+("%d阶" % rank if learned else "未学习")
 detail += "\n"+Design.description("yanguizhou","p1",rank if learned else 1)
 detail += "\n被动，无主动施放与独立冷却。各段正常伤害先结算；整次Q/E结束后只命中过一敌才一次补增伤、返当时剩余冷却，不提前击杀。每条完整Q2河独立计算；E3按实际交换伤害批次完成结算，放A与A到期不触发奖励；R1/BASIC不计入。"
 detail += "\n补算只对实际损失生命的伤害按原Q/E面积系数参与已有吸血；不再触发一次命中、暴击或减伤。每阶1SP，上限4阶。P2/P3与未接强化未开放；临时文字卡，无美术/音频验收。"
 return {"accepted":true,"candidate":"p1","rank":rank,"learned":learned,"label":"%d/4" % rank if learned else "未学","tooltip":detail,"passive_only":true,"has_active_input":false,"source_time":source.hero_time,"generation":source.encounter_generation,"room_id":source.room_id,"temporary_visual":true}

static func apply_p_to(hud: Control, source: Node) -> Dictionary:
 var shown: Dictionary = p_model_from(source)
 var patch: Control = hud.get_node_or_null(NodePath(PriorPCard.PATCH_NAME))
 if not shown.accepted:
  if patch != null: patch.hide()
  return shown
 if patch == null:
  patch = PriorPCard.new()
  patch.name = PriorPCard.PATCH_NAME
  patch.position = PriorPCard.CARD_RECT.position; patch.size = PriorPCard.CARD_RECT.size
  patch.mouse_filter = Control.MOUSE_FILTER_STOP; patch.focus_mode = Control.FOCUS_NONE
  hud.add_child(patch)
  if is_instance_valid(hud.shop_group): hud.move_child(patch,hud.shop_group.get_index())
 patch.show(); patch.projected = shown.duplicate(true)
 patch.tooltip_text = str(shown.tooltip); patch.queue_redraw()
 hud.source_model["selected_p"] = shown.duplicate(true)
 return shown
