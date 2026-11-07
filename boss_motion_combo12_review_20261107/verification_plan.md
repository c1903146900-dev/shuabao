# Shortest useful ordinary-route verification

## Known evidence and limits

The namespaced initial choices, slot0 refresh to common_g13, slot1 refresh to
fengli_h08, its actual select button, and normal E1 rank1 learning passed the
short bossh08draft02 UI run. First-room real E1 damage, enemy_control stun and
matching mark were observed in bossh08cancel01 before it guard-stopped in room3.
The live Boss, Boss cancellation and new-run cleanup were not reached. H06 is
eligible by source but this review has no actual UI acquisition proof for H06.

H08 (定命) gives 1.0-second stun on a real E1 dagger hit, and on a second-stage
pierce hit against its marked target. H06 (震锋) gives 0.5-second stun on a real
Q3 wave contact. Fengli explicitly allows those stuns on Boss; generic push/pull
remains blocked. Shift dodges and does not cancel a Boss warning.

No resumable disk save or dedicated ordinary Boss entry exists. The earliest
legitimate live test still requires reaching row12 through the ordinary route.
Keep the existing guard and its pins unchanged. A drawing fixture is useful for
unit presentation checks, not a substitute for that traversal. Do not transplant
a recorded snapshot, hot-replace a live presentation, write HP/hex/state, force
seeds, skip nodes, or increase guard thresholds.

## Reconcile observe_h08_cancel.gd before another long run

The existing observer is a useful route driver, but not yet a strong pass oracle:

1. Its watch() counts any Boss cancellation. It does not bind a current warning,
   scope, E1 cast, dagger contact, stun, mark and matching wave cast ID. Require
   that chain instead of treating cancelled>0 as sufficient evidence.
2. It waits for one release before trying a later cancellation. This is not
   needed to prove cancellation, and Boss B forces a close sweep afterward.
   Maintaining its current ~4.9-unit offset can delay that sweep indefinitely.
   Cancel the first wave warning; observe successful releases separately.
3. The neutral check can count zero poses as success unless count and actor ID
   are checked. Require exactly the intended living Boss pose, fresh receipt
   source_time>cancel_time and post-draw stage neutral with attack lean/squash=0.
   Hit-reaction tilt/flash from the actual dagger remains legitimate.
4. The current observer closes after cancellation already erased its cache, so
   an empty-cache terminal check does not exercise release-cache invalidation.
   A release record does not expire merely because its 0.28-second pose expires.
   Test closing with an actual cached release, preferably while its pose is
   active, then check old cache after encounter_finished and fresh run ID/cache.
5. Existing capture uses a .10-second interval and large JSON logs. The release
   lasts only .28 world seconds. Use bounded event-triggered frame capture after
   frame_post_draw for windup, immediate release, recovery, cancellation and
   lifecycle. Retain receipts/sequence evidence, not unlimited per-tick logs.
6. Validate all four displayed IDs, button enabled state, choosing=false and
   confirmed selected H08 before progressing. Never refresh/select by expected
   position alone. Preserve _choose's real button delay. Later milestone choices
   can use enabled buttons, but must not alter the initial two-refresh sequence.

## Minimal planned test sequence

Use normal route input, ordinary earned growth and permitted potion UI. Keep
E1+H08 active. A Q1/P2 route is compatible; do not automatically replace E1 with
E2. It is not necessary to acquire H06 as well.

1. Start a fresh run. Verify initial IDs exactly
   [fengli_h12, common_g29, common_g30, fengli_h16]. Press
   host.initial_hud.hex_draft.cards[0].refresh, await slot0=common_g13 and used
   flag, then cards[1].refresh, await slot1=fengli_h08 and used flag, then
   cards[1].select. Await the actual 0.24-second selection/close. Learn E1 through
   its enabled growth button or the existing normal HUD adapter. Verify actual
   selected_hex and active sim hex membership before the Boss action.
2. Reach row12 normally. Release held attacks. Require one living kind=boss,
   current combat scope, healthy player, E1 ready and no current E1 mark/cast.
3. At 5-7 units, let the first wave warning start; record enemy_warning and its
   boss_cast_id. Press E early (warning_progress<.30), aimed at the real Boss.
   E1 launch is .10 seconds, travel speed 25, Boss radius1.25: contact should
   occur ~.25-.33 seconds after accepted E at that separation, well before the
   1.35-second warning expires. Record actual action acceptance; do not infer it.
4. Require ordered, current-scope evidence: e1_started; damage source=e1_dagger
   targeting Boss with that cast_id; enemy_control target=Boss/control=stun;
   e1_marked with that cast_id/target; boss_wave_cancelled with the warning's
   boss_cast_id/reason=crowd_control; enemy_attack_cancelled for the Boss with
   reason=crowd_control. enemy_control itself does not include source/cast ID,
   so correlate its sequence with this actual contact, mark and active H08.
   Require no boss_wave_released between that warning and cancellation.
5. After post-draw, verify a fresh neutral Boss attack pose and no cached
   release. Repeat while .28 world seconds elapse; do not require its separate
   damage-hit response to vanish. This proves no fake attack after cancelled
   warning, not that all possible cancellation scenarios have passed.
6. For successful sweep release coverage, allow Boss within3.8 units after the
   stun/recovery and then dodge laterally/out of the committed cone. Actual
   enemy_impact (including hit=false) is sufficient release authority. Capture
   release and later neutral, with unchanged source position/picking transform.
7. For successful wave release coverage, move back to 5-7 units after the sweep
   has reset force_sweep. Let warning release while dodging perpendicular to its
   locked track. Capture boss_wave_released, immediate pose and settling. Do not
   infer a launch from boss_wave_contact, boss_wave_finished or generic recover.
8. If both projected horizontal signs are needed, move to the opposite side and
   allow another committed attack. This is separate from the minimum cancel
   proof; do not make one-direction evidence claim both directions.
9. Before a later release has expired, use actual menu/new-run controls. Verify
   encounter_finished clears old cache and fresh run has new ID/empty cache.
   Capture terminal/initial UI without editing either simulation. If full-floor
   regression is also required, kill Boss normally and verify completion first;
   then an active-release close requires a separate run. Do not conflate these.

For the shortest narrow Boss check, cancel-first plus one legitimate sweep and
one legitimate wave should avoid the old fixed45-second wait. Exact completion
time depends on normal source cadence, navigation and cooldowns. Do not set a
performance claim or bypass a guard based on this estimate.
