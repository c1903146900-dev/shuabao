extends RefCounted
const ITEM_ID := "elixir:05"
const BUFF_KEY := "elixir_swift_after_shift"
static func inspect(buff: Dictionary, scope: Dictionary, now: float) -> Dictionary:
 var out: Dictionary={"active":false,"move_fraction":0.0}
 if scope.is_empty() or buff.get("scope")!=scope or not is_finite(now) or now<0.0:return out
 var deadline: Variant=buff.get("expires_at")
 var fraction: Variant=buff.get("move_fraction")
 if not (deadline is int or deadline is float) or not (fraction is int or fraction is float):return out
 if not is_finite(float(deadline)) or not is_finite(float(fraction)) or float(fraction)<0.0 or float(fraction)>1.0 or now>=float(deadline):return out
 out.active=true;out.move_fraction=float(fraction);return out
static func propose(scope: Dictionary, now: float, duration: float, fraction: float) -> Dictionary:
 if scope.is_empty() or not is_finite(now) or now<0.0 or not is_finite(duration) or duration<=0.0 or not is_finite(fraction) or fraction<0.0 or fraction>1.0 or not is_finite(now+duration):return {}
 return {"scope":scope.duplicate(true),"last_shift_end_at":now,"expires_at":now+duration,"move_fraction":fraction}
