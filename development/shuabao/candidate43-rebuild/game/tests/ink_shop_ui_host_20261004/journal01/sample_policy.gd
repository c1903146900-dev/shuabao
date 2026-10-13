extends RefCounted
## Observer-only cadence. Periodic rows <=10Hz; explicit lifecycle boundaries and
## paused source changes are separate unsampled evidence, never gameplay ticks.
const PERIOD_USEC: int=100000
var last_periodic_usec: int=-1
var last_scope: Dictionary={}
var last_paused_signature: String=""
var initialized: bool=false
var counts: Dictionary={"initial":0,"boundary":0,"paused_changed":0,"periodic":0,"paused_duplicate":0,"throttled":0}
func choose(wall_usec: int,paused: bool,scope: Dictionary,paused_signature: String) -> String:
 var reason: String=""
 if not initialized:reason="initial"
 elif scope!=last_scope:reason="boundary"
 elif paused:
  reason="paused_changed" if paused_signature!=last_paused_signature else "paused_duplicate"
 elif last_periodic_usec<0 or wall_usec-last_periodic_usec>=PERIOD_USEC:reason="periodic"
 else:reason="throttled"
 initialized=true;last_scope=scope.duplicate(true)
 if paused:last_paused_signature=paused_signature
 else:last_paused_signature=""
 if reason=="periodic":last_periodic_usec=wall_usec
 counts[reason]+=1
 return reason
static func retained(reason: String) -> bool:
 return reason in ["initial","boundary","paused_changed","periodic"]
