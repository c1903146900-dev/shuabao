# P1 final correction and existing ordinary lifesteal

Source-only new leaf above the unchanged 342/342 checkpoint02 parent. It does not modify or reinterpret that historical zero-lifesteal finite pass. New runtime/ordinary combination not run yet.

## Existing legal scope

Ordinary commerce already maps B09 血泵 (500 gold, +4% lifesteal), I06 血袭刀环 and I10 狂战泵 (+6%). `tests/ink_intermediate_stats_20261004/source_map.json` and the existing stat consumer project these into hero.stats.lifesteal. This is not BASIC-only: current `ink_damage_scope_guard.gd` calls heal for ordinary reaction-enabled damage, and shared `hero_combat_core.gd::_hero_lifesteal_factor` uses 0.4 for direct+area. Current base Q1/Q2/Q3/E1 packets have those source properties. BASIC uses its existing factor1; non-direct uses the existing factor0.25. None of these original formulas are changed here.

The effective P1 decision authorizes end-of-whole-cast final correction and refund; it did not explicitly prescribe zero supplemental lifesteal. Production coordination authorized applying the existing source Q/E area lifesteal to actual P1 supplemental damage, without another hit/crit/defence/on-hit transaction. This document distinguishes that technical integration from the user's quoted timing decision.

## Exact lifecycle and timing convention

The leaf observes only the parent's genuine committed `yanguizhou_p1` final_supplement damage event, with an already-claimed settled root, one original target, matching family/target identity and current room/hero/target instance. It additionally matches the parent's already-appended committed P1 receipt, including the exact positive actual_supplement amount; a settled root with an already-dead target and zero supplemental damage cannot authorize a later forged positive-tag event. All four admitted Q/E families are direct+area. Before outward callbacks, it claims a generation/room/root key and snapshots the existing effective lifesteal rate and factor at supplemental-damage commit time. This is not the rate at initial cast or past ordinary packets; no old damage's lifesteal is replayed.

After the inherited damage notification returns, the same current living hero and exact target instance must still belong to the same combat room. A hero death, room/owner replacement or ended encounter prevents old healing. Target death committed by this supplement is valid and does not suppress its earned lifesteal. Same-room cast cancellation after committed damage cannot reopen the claim or erase the earned once-only healing. Pause inside this committed damage callback follows the existing synchronous damage transaction: it does not rewind already committed damage/healing; later simulation stays paused.

Requested healing is actual_supplement × snapshotted current lifesteal rate × existing source area factor. It uses the existing `heal` API exactly once. That API caps to missing HP, returns actual recovery, updates existing equipment health dependencies and invokes ordinary healed observers. Full HP recovers zero; excess is discarded by the existing API, with no invented shield or overflow bank. No second damage_enemy, before_hit, crit, mitigation, after_hit or action completion is called.

The order is: parent atomically commits supplemental enemy HP/CD/dead state; outward damage notification; scoped supplemental heal and its existing healed observers; then parent's already-scoped common.killed/_hero_killed/kill notification chain. The original parent checks scope again after every kill callback. If a healed callback changes room, the old root cannot notify or heal the new room. Diagnostics expose requested/actual heal and snapshot rate/factor separately from P1 damage receipts.

## Required bounded validation

Use a real B09 commerce purchase/stat projection in an explicitly funded finite fixture; ordinary startup must remain Lv1, 0 gold, 0 XP, 1 SP. Check ordinary Q/E healing remains unchanged, supplement heals only actual committed damage at factor0.4, enemy-lethal correction is HP-capped, hero-full-HP recovery is zero, late hero death/room replacement receives no old healing, and duplicate/cancel callbacks cannot pay twice. Preserve the 342 parent gate and label its zero-lifesteal boundary honestly. No native/art/whole-floor acceptance follows from this source.
