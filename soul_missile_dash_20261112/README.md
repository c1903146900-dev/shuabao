# Offline G10/G16 plus directional dash-attack candidate

NOT RUN; NOT SELECTED. Parent remains the separately short-tested G10/G16 combination 338124f7, publicly backed at e73f0f94. Passed baseline 4112ebb6 and every prior candidate remain untouched. This new independent pack is 1ba056a553431429888f81c5b4c7e38d99dc3a0388d816aa81755cb343395f36 with 259 authenticated bindings.

Only the exact single presentation aim-condition line is transplanted, plus the byte-identical puppet_motion.gd from the existing b5429886 dash-attack candidate. Do not replace the entire old presentation file: that would discard G10/G16. Both helpers and every scope/death cleanup remain unchanged. Gameplay, direction, damage, immunity and timing sources are untouched. No engine was launched for this work and no guard or runtime settings were changed.

Two observer copies now read presentation.receipt.get("puppet_motion",{}).duplicate(true), not the persistent puppet helper receipt. Exactly two accesses per observer changed. This prevents interpreting the helper's cached last pose as current rendering after the presentation omits its puppet pose. The observers and this combined runtime have NOT been executed, so this is a source-level correction, not a new runtime pass.

Run tests/check_transplant.py with --parent (338124f7 runtime), --after (new runtime), --dash (b5429886 runtime) and --original-observers (public dash_attack_pitch_20261111 directory). STATIC_QA records exact-scope/signature/helper/observer/binding checks, not GDScript parsing or visual acceptance.

Recovery: apply presentation.patch with zero-context support to exact SOURCE_HASHES parent, overlay changes/fengli_route_20261024/puppet_motion.gd, then reseal using the existing public recovery tool. Verify BUILD.json PCK and source hashes. No new asset or private material is needed beyond existing authorized private inputs. No binaries/raw logs/screenshots included.

## Risks still open
- Existing dash-attack short tests had no real dash-attack damage event; this combination has no engine coverage at all.
- South-facing sword remains partly occluded by leg/HP cue in earlier visual evidence. No unverified layer or geometry change was made here.
- Source polygon clipping is cached once, but per-frame deformed mesh rebuilding remains; combined rendering cost is not measured.
- Same-frame G10 pickup/G16 projectile test was independently interrupted at startup by the unchanged guard. That result is not a pass and does not justify another engine retry.
- Simultaneous dash attack/pickup/projectiles, actual hit/miss, action ending/interruptions, full first floor, Windows and actual audio remain unverified.

Do not substitute prior independent tests for runtime validation of this new candidate. Keep it isolated until safe, authorized testing becomes possible.
