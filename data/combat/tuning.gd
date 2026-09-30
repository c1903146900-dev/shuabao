extends RefCounted
## v0.1: test_initial unless explicitly listed as confirmed below. Units: metres, seconds.
const VERSION = "fengli-whitebox-0.1"
const CONFIRMED = {
 "q1_ad": 1.2, "q1_cd": 5.0, "q1_refund": 0.30, "q1_stack_gain": 0.30, "q1_max_stacks": 4,
 "e3_duration": 7.0, "e3_bonus": 0.30, "e3_true": 0.25, "e3_dash_factor": 0.50,
 "e3_kill_extension": 1.5, "e3_cd": 32.0, "r1_ad": 1.5, "r1_execute": 0.05,
 "r1_cd": 130.0, "p3_thresholds": [10, 7, 5], "cdr_cap": 0.65, "as_cap": 2.5
}
const INITIAL = {
 "hero_hp": 240.0, "hero_ad": 32.0, "hero_speed": 6.0, "hero_as": 1.7,
 "attack_ad": 1.0, "attack_range": 2.8, "attack_width": 2.6, "attack_startup": 0.10,
 "dash_distance": 4.2, "dash_duration": 0.16, "dash_cd": 3.2,
 "q1_length": 4.2, "q1_width": 1.8, "kill_grace": 0.2,
 "r1_radius": 10.0, "r1_show_duration": 1.1, "world_slow": 0.20,
 "crit_multiplier": 1.75, "area_leech": 0.4, "dot_leech": 0.25,
 "arena_half_extent": 13.5, "player_radius": 0.42,
 "minion_hp": 64.0, "elite_hp": 230.0, "boss_hp": 900.0,
 "minion_damage": 18.0, "elite_damage": 32.0, "boss_damage": 46.0,
 "minion_warning": 0.85, "elite_warning": 1.0, "boss_warning": 1.35,
 "minion_range": 1.8, "elite_range": 2.8, "boss_range": 4.2
}
# Explicit provisional policies, not assertions that the original design settled these.
const POLICIES = {
 "q1_stacks": "additive_from_base_once_per_cast",
 "q1_refund": "once_per_cast_30_percent_full_effective_cd",
 "q1_kill": "lethal_packet_from_this_cast_only_within_world_time_grace",
 "e3_p3_kill": "solo_lethal_credit_only_no_assists",
 "e3_true": "25_percent_post_crit_pre_defence_attack_ordinary_no_lifesteal",
 "e3_shift": "multiplicative_with_cdr_new_dashes_only_existing_cd_unchanged",
 "dash": "movement_then_aim_direction_no_invulnerability_no_damage_no_cancel",
 "post_room": "freeze_all_model_state_pending_design_confirmation_on_cross_room",
 "r1_circle": "player_position_at_cast_includes_boss_strict_below_5_percent"
}
# Numeric-only test ranks; rank 1 confirmed where present in CONFIRMED.
const TEST_RANKS = {
 "q1_ad":[1.2,1.32,1.44,1.56,1.68], "q1_cd":[5.0,4.8,4.6,4.4,4.2],
 "e3_duration":[7.0,7.5,8.0,8.5,9.0], "e3_bonus":[0.30,0.33,0.36,0.39,0.42],
 "e3_true":[0.25,0.275,0.30,0.325,0.35], "e3_cd":[32.0,31.0,30.0,29.0,28.0],
 "r1_ad":[1.5,1.75,2.0], "r1_cd":[130.0,120.0,110.0],
 "p1_leech":[0.02,0.04,0.06], "p2_heal":[0.07,0.11,0.15], "p2_cd":[120.0,100.0,80.0]
}
static func ranked(key: String, rank: int) -> float:
 var values: Array = TEST_RANKS[key]
 return values[clampi(rank-1,0,values.size()-1)]
static func hero_stats() -> Dictionary:
 return {"ad":INITIAL.hero_ad,"ap":0.0,"attack_speed":INITIAL.hero_as,"crit_chance":0.0,
 "cdr":0.0,"max_hp":INITIAL.hero_hp,"defence":0.0,"move_speed":INITIAL.hero_speed,
 "lifesteal":0.0,"tenacity":0.0,"penetration":0.0,"regen":0.5}
static func damage(amount: float, defence: float, penetration: float, is_true: bool = false) -> float:
 if is_true: return maxf(0.0, amount)
 return maxf(0.0, amount) * 100.0 / (100.0 + maxf(0.0, defence - penetration))
static func cooldown(base: float, cdr: float) -> float:
 return base * (1.0 - clampf(cdr, 0.0, CONFIRMED.cdr_cap))
static func control_duration(seconds: float, tenacity: float) -> float:
 return seconds * (1.0 - clampf(tenacity, 0.0, 1.0))

static func countdown(value: float, delta: float) -> float:
 var left: float = value - delta
 return 0.0 if left < 0.00000001 else left
