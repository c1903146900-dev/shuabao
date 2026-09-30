extends RefCounted
## Extended ability test geometry, explicit provisional policies, and numeric-only growth.
const INITIAL = {"q2_initial_range":8.0,"q2_chain_range":4.5,"q2_interval":0.2,"q2_behind":1.3,
 "q3_length":11.0,"q3_width":2.0,"q3_impulse":8.5,
 "e1_range":12.0,"e1_speed":18.0,"e1_timeout":2.0,"e1_recast_radius":3.0,"e1_width":1.3,
 "e2_radius":2.7,"e2_spin":0.25,"e2_blink":6.0,"e2_landing_radius":1.8,
 "r2_boss_stagger":0.3,"r2_boss_stun":0.65,"r2_length":12.0,"r2_width":1.6,"r2_show_real":0.25}
const POLICIES = {"q2_targets":"closest_to_pointer_then_nearest_unvisited_actor_id_tiebreak",
 "q2_dead_target":"retarget_from_last_position_or_finish; never repeat; landing clamped behind last hit",
 "q3_geometry":"instant long rectangle once_per_target, no added stun or charges",
 "e1_invalid":"dead_target_or_projectile_timeout_starts_cd; no mark on lethal first hit",
 "e2_geometry":"one immediate movable spin hit then blink toward snapshotted_pointer",
 "r2_count":"attack_completed including misses since first throw; cumulative; no cap",
 "r2_geometry":"every nail shares one long rectangle and can hit every target once",
 "r2_window":"3 world seconds from each throw, boundary exclusive; third show end starts CD",
 "post_room":"freeze ability states; remove presentation flags; completed third throw commits CD"}
# Numeric-only test growth. Rank 1 preserves confirmed coefficients. No extra mechanics.
const TEST_RANK_DAMAGE = {"q":[1.0,1.1,1.2,1.3,1.4],"e":[1.0,1.1,1.2,1.3,1.4],"r":[1.0,1.1,1.2]}
