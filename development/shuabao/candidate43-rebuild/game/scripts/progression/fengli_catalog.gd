extends RefCounted
## Source-final Wind progression profile. Readiness is a consumer declaration, not a new design.
const FinalDesign=preload("res://data/final_design/catalog.gd")
const Tuning=preload("res://data/combat/fengli_tuning.gd")
const RUNTIME_CANDIDATES=["Q1","Q2","Q3","E1","E2","E3","R1","R2","P1","P2","P3"]
const RUNTIME_HEXES=["H01","H02","H03","H04","H05","H06","H07","H08","H09","H10","H11","H12","H13","H14","H15","H16","H17","H18","H19"]
static func build()->Dictionary:
 var result:Dictionary=FinalDesign.build_progression("fengli")
 result.runtime_candidates=RUNTIME_CANDIDATES.duplicate()
 result.runtime_hexes=RUNTIME_HEXES.duplicate()
 # Effective named rules come from FinalDesign; never append obsolete local guards.
 result.runtime_validation={"native_play":"pending","balance":"initial_values_pending_live_balance","pending_rules":Tuning.runtime().pending_world_rules}
 for candidate in result.skill_descriptions:
  var note:String=""
  if candidate not in RUNTIME_CANDIDATES:note="当前状态：候选尚未实装，不可学习。"
  if not note.is_empty():
   for index in result.skill_descriptions[candidate].size():result.skill_descriptions[candidate][index]+="\n\n"+note
 return result
