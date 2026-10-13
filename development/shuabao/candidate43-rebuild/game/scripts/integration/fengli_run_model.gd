extends "res://scripts/integration/run_model.gd"
## Fail closed only for explicitly unavailable Wind candidates; all economics stay shared.
func _apply(action:String,args:Dictionary)->String:
 if action=="learn" and str(args.get("candidate","")) not in config.get("runtime_candidates",[]):return "candidate_not_implemented"
 return super._apply(action,args)
