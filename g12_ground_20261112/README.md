# Isolated G12 bombardment source presentation

Status: OFFLINE ONLY, NEVER ENGINE RUN, NOT SELECTED. Passed 4112ebb6 and the G10/G16/dash candidates remain unchanged. This candidate is independent from 4112ebb6, not layered on experimental candidates. PCK cc7b6f1a9a02547cae5ab065bed3e3dc205009b837360b2ab7b4ba56dc036b9a, 258 authenticated bindings.

## Confirmed source gap
Existing scripts/combat/common_hex_runtime.gd lines 458–465 schedules a delayed bombardment after the existing eligible long-distance hit count, with actual position, radius, due time, room and generation. Lines 795–805 execute the actual area damage. Lines 507–513 emit area_effect after execution, including an empty-area strike. The existing bridge forwards that as common_hex_area_effect, source common_g12. Baseline Fengli route has no G12 bombardment consumer or rendering. This is a missing feedback connection demonstrated in source, not a newly observed playtest failure. The original source mechanisms and selection rules are not altered.

## Implemented isolated change
A read-only helper renders real pending scheduled bombardment footprints at their exact projected ground position/radius, beneath actors and enemy warning overlays. The restrained warm-gold outline is friendly, without opaque fill or new text. Pending marks are resampled from the actual source array; no warning event spawns or persists a fake attack.

A brief ground-spoke impact is created only by the synchronous original common_hex_area_effect event from common_g12, matching current event sequence/log and scope. A countdown expiring cannot create an impact. This includes a genuine source strike with no enemy in range, but does not claim that damage occurred. The 0.20-second persistence is visual-only and uses the existing source world clock; pause does not advance an independent timer. Impact records are bounded to 32 and cleared by scope/death/invalid owner/ended combat. No retargeting, new collision, damage, countdown, input, progression, currency or guard change.

Only presentation and the new helper change, plus manifest/generation resealing. All existing function signatures are preserved. Forty offline checks cover existing source evidence, event/source filtering, no gameplay mutators, draw/cleanup hooks, exact changed scope, finite real-radius geometry and 258 exact binding entries. These checks are not GDScript parsing or runtime acceptance.

## Recovery and remaining checks
Apply presentation.patch with zero-context support against exact SOURCE_HASHES before bytes, add changes/fengli_route_20261024/bombardment_view.gd, then reseal using the already published recovery tool. Verify output source hashes and BUILD.json PCK. No private reference, asset, binary, screenshot, raw log or credentials are included.

No engine was launched. Still required when safe: authenticated loading; actual original G12 trigger; mark matching original due/position/radius; true and empty-area execution; no false impact on cancellation/room change; duplicate/stale event rejection; pause/death/room lifecycle; crowded overlap and ordinary camera readability; full first floor, Windows and listening. Friendly-vs-enemy readability is a design intention, not a visual acceptance result. No claim that this completes the whole first-floor experience.
