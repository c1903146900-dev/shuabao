# R1 target-impact visual candidate

Accepted baseline remains motion_combo15. The isolated candidate only changes the actual R1 damage-hit drawing branch in fengli_route_20261024/skill_effects.gd.

Actual normal gameplay images show large surrounding R1 action strokes but small regular blue stars at the targets' feet. These read like ground markers, separated from body response and the improved defeat motion. Basic attacks and Q2 already have separate contact treatments and are not part of this change.

The R1 candidate draws a compact directional cut, bright contact core and two asymmetric fragments on the target body. Body offset comes from the actual original-art drawing rectangle and signed basis: the current live drawing or the source-confirmed kill's saved original body frame. That offset is added to the original damage world's projected ground point, not a moved target position or a guessed enemy height. Missing usable original-body geometry falls back to the previous grounded star for that event, explicitly recorded.

All local vertices remain inside the former R1 burst envelope, at most 30.8 by21 pixels initially. The original damage acceptance, deduplication, positive-hit ownership, real-time domain, .16-second lifetime and bursts receipt remain unchanged. Basic/dash attack hits, Q2 and other skills, R1 surrounding action strokes, source timing, geometry and gameplay rules are unchanged.

Overlay SHA-256: 37c22c7d87c8ef1c861ab940efaa98f5934e5198fc60f03633ad89b2d11dda0f.
Candidate pack SHA-256: 6c395e546faef7d75b65b49d30fa1afd6fc01c1237174ec46cab7f949e9e1489.
Build with rebuild_20261106/build_r1_impact.py and a fresh output name. Recovery uses preserved combo15 and the existing authorized original assets; no private assets are redistributed here.

Only pure file/geometry inspection is currently credited as static evidence: removing the added R1 helper, dedicated branch and receipt initializer restores the baseline file exactly; no shape self-intersects and all stay within the old local envelope. Formal graphical/behavioral acceptance requires the unchanged owned runtime guard.

The new normal-route observer targets actual multi-target R1 damage, source-matched bursts and expiry, not an additional full-room victory condition. Its scope differs explicitly from the older defeat-group observer, whose five-of-six result and failed full-victory requirement remain preserved. Reusing its real before-images does not convert that older failed observer into a pass.

Status: awaiting guarded actual comparison. Not promoted. No raw logs, captured images, private reference materials, credentials or personal data are included in the public checkpoint.
