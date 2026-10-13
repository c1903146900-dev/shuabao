extends RefCounted
## Separate animation normalization from contact-boundary conversion.
const CYCLE: float=.50
const CONTACT: float=4.0/30.0
const HALF: float=.25
const OLD_CYCLE: float=.60
const OLD_CONTACT: float=5.0/30.0
const OLD_HALF: float=.30
static func view_phase(gait_elapsed: float) -> float:
 return fposmod(gait_elapsed,CYCLE)
static func base_phase(phase: float) -> float:
 return phase/CYCLE*OLD_CYCLE
static func gait_phase_from_base(base: float) -> float:
 return base/OLD_CYCLE*CYCLE
static func contact(phase: float,side: String) -> bool:
 return phase<=CONTACT if side=="L" else phase>=HALF and phase<=HALF+CONTACT
static func toeoff(side: String) -> float:
 return CONTACT if side=="L" else HALF+CONTACT
static func stop_phase(phase: float) -> float:
 # Preserve toe-off on both sides. This mapping is NOT used by base/carry.
 var half_index: int=0 if phase<HALF else 1
 var local: float=phase-float(half_index)*HALF
 var mapped: float=local/CONTACT*OLD_CONTACT if local<=CONTACT else OLD_CONTACT+(local-CONTACT)/(HALF-CONTACT)*(OLD_HALF-OLD_CONTACT)
 return float(half_index)*OLD_HALF+mapped
