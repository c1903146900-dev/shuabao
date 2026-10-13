# Base R1 isolated core candidate

2026-10-06 UTC. This is the first source-only R1 core step, inherited from the
current E1 ordinary sim. No normal host, chooser, capability, input adapter,
learning UI, art, audio, stage or engine launch is changed by this step.

## Original source

DOCX paragraph85 and XLSX `晏归舟技能!E80:H86` define `独钓寒江雪`.
`tuning.gd` reads the seven original tokens through the existing final catalogue.
There are four ranks: cast range12m, radius11/11.54/12.5/14m,
duration6/6.7/8.2/10.5s, ordinary reduction70/73/79/88%,
elite40/44/52/65%, Boss25/28/35/45%, cooldown140/131/116/96s.
Both movement and attack rate consume the matching category reduction.
Base R1 has no damage, freeze, heal, immunity, taunt or global time dilation.
H13/H14/H15/H16 remain unavailable; R2 is not implemented by this leaf.

## Recorded implementation conventions

- The independent core API is `request_action("r", point, command_id)`.
  The following ordinary input step will add R aim then fresh LMB confirmation;
  this core step does not claim actual keyboard/mouse routing or native input.
- The circular center is the exact finite ground point within12m of the hero at
  commit. It remains fixed. No clamping, following, artificial line-of-sight test
  or requirement that the entire domain fit inside the arena is added.
- Source rank/parameters are captured at creation. Successful creation starts
  cooldown once through the existing CDR service. Invalid requests create no
  domain or cooldown. No duration-long action lock or presentation is entered.
- New R is rejected during real control or E1 rain form; an already committed
  domain remains when the hero is subsequently controlled or enters E1.
- Enemy inclusion uses the existing circle-query body-overlap convention on
  XZ: center distance<=domain radius+enemy radius. Spawn/dead/stale/replaced
  objects are excluded. Membership is sampled at the enemy phase of the
  existing fixed step; continuously swept crossing is not claimed.
- `rank_category` is authoritative. `armored` remains ordinary when its category
  says ordinary. The authored category percentage bypasses no control immunity:
  it is a field rate projection, independent from `apply_control`, tenacity and
  the common timed-slow clamp. Unknown categories receive no field projection.
- Existing timed movement slow is preserved and multiplied by the independent
  R1 movement factor once. R1 never writes `slow_amount`, `slow_left` or base
  speed. This composition is a declared implementation convention, not an
  additional percentage from the original source.
- Attack rate scales only `enemy.timer` progress in chase, warning and recover.
  Spawn grace and active pounce remain world-time durations. Pounce movement
  receives the movement factor once, like the existing movement-slow behavior;
  its0.40s activity is not lengthened. CC, guard, navigation, facing, wait age,
  projectile/zone clocks and global director commit gaps retain original dt.
- A slowed warning retains its original threat reservation until real release.
  Its normal world-time decrement remains, with a local minimum of remaining
  warning timer plus the original0.10/0.40s active allowance. Release/interrupt
  still performs the original threat handoff; this is not a second threat token.
- No-R/outside-domain behavior delegates to the original director methods.
  The new director inherits the current fixed navigation and Q3 interception.
- Domain duration uses the same hero/world clock as ordinary skills. The final
  partial lifetime weights only the two field rate factors; it never reruns the
  core, scales an entire enemy dt, or rewinds world time. Pause and existing Q2
  remainder behavior remain inherited. If a callback pauses, finalization waits
  for a resumed step; the recorded natural finish time remains its exact expiry.
- Natural expiry retires and finishes once. Cancel/death/end-room retires without
  a natural finish event, damage or heal. It never resets R cooldown. Existing
  safe-node `free_move` does not tick cooldowns; subsequent real combat does.
- R1 is non-damaging and does not add a new victory-pending reason. Existing
  Q/E/BASIC pending work still owns its original settlement boundary. Killing the
  last enemy may end the room and cancel the remaining domain normally.

## Progression and scope

The unchanged Model retains18 levels/18 base SP, Q/E6 and P/R4 ranks, R costs
1/2/2/2, first learn atLv6 and no later hero-level gates. Full four-slot ranks cost
23SP. No ordinary XP, SP, gold or HP is granted. Any seeded level/rank/target in
`finite_gate.gd` is a named finite fixture, not a natural progression result.

Core source checks do not prove GDScript parse, runtime behavior, native input,
normal learning, full-floor survival, Boss, graphics or sound. Root owns all
actual engine windows and source staging. No E2/E3/P1 candidate is inherited.
