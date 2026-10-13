extends RefCounted
## Pure presentation target calculation. No wave lifetime, timers or source writes.
const START:=.24
const END:=.43
static func evaluate(cast_yaw: float,move_yaw: float,age: float,walking: bool,dash: bool,context: bool,already_started: bool,previous_yaw: float) -> Dictionary:
 var weight: float=smoothstep(START,END,age)
 var eligible: bool=context and not dash
 var started: bool=context and (already_started or (eligible and walking and age>START))
 var applied: bool=eligible and started
 # Once walking has returned root ownership, a stop holds the displayed heading.
 # The still-playing upper or its fade must not retake root ownership.
 var target: float=lerp_angle(cast_yaw,move_yaw,weight) if walking else previous_yaw
 return {"applied":applied,"started":started,"moving":walking,"dash_excluded":dash,"source_age":age,"return_weight":weight if applied else 0.0,"target_yaw":target,"cast_yaw":cast_yaw,"movement_yaw":move_yaw,"start":START,"end":END,"wave_lifetime_used":false,"upper_clip_cut":false,"source_written":false,"art_accepted":false}
