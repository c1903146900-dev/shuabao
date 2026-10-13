extends "res://scripts/ui/progression_controller.gd"
## Wind-only boundary messages. Shared authority and transaction flow are unchanged.
func reason_text(reason:String)->String:
 var wind_errors:Dictionary={"recast_release_too_late":"剩余重投窗口不足以完成投掷前摇；未消耗次数","ultimate_presentation":"乱星斩演出尚未结束","sequence_finished":"本轮骨钉雨已结束，剩余骨钉结算中","no_throws":"本次骨钉雨已无剩余投掷","recast_expired":"重施窗口已结束","piercing":"穿刺尚未结束","dagger_in_flight":"匕首飞行中，命中标记后可再次施放","mark_lost":"标记目标已失效","illegal_landing":"目标落点不可达；标记未消耗","illegal_return":"留影落点不可返回","e1_terrain_policy_pending":"此障碍路径规则待确认；操作未消耗","q2_terrain_policy_pending":"此障碍路径规则待确认","dashing":"冲刺中可按左键进行一次冲刺攻击"}
 return str(wind_errors[reason]) if wind_errors.has(reason) else super.reason_text(reason)
