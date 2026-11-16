# Terminal auto-hex guard candidate (2026-11-16)

Isolated candidate on flow-trio PCK `2c552be19883c8473d72717b9ccfcf2d4ce34155f3e12cfa962205aec4efe346`. Not selected for play.

## Source finding
Boss settlement can leave a newly earned pending milestone while setting session status to completed. Host calls ensure_auto_hex on every frame; inherited auto_hex_pending checks progression but not session liveness. Opening required UI emits modal_changed, and route set_modal_blocked rejects terminal sessions with no_live_run, which host records as floor_error. This is a source-level reachable end-of-floor defect, not a reproduced explanation for mid-floor hangs.

## Narrow fix
Route-only controller overrides the predicate: delegate unchanged in preparation, combat, between_rooms and service; suppress new required-choice UI in terminal/unbound/missing sessions. Host changes only its controller preload. Shared controllers, model, ledger, session and rewards are byte-identical. Pending milestones are retained rather than discarded. This does not implement post-completion milestone claiming and does not repair already-open terminal modal dismissal callbacks.

## Checks
352 independent predicate-model cases, 128 live-state equivalence cases, 21 formerly true nonlive cases now suppressed. Model checks preserve XP, level, pending list and reward receipts. Exact directory comparison proves all other runtime bytes unchanged except generated manifest/generation metadata. Pack assembly has 258 validated bindings, candidate SHA256 in BUILD.json.

These are Python model/source/pack checks only. No Godot parser, engine, UI, gameplay, natural boss completion or complete first floor was run. Historical rejected launch was not retried.

## Apply and reproduce
Add growth_controller.gd at fengli_route_20261024/growth_controller.gd and apply host.patch to the flow-trio runtime. Regenerate its binding manifest/package with the existing approved packaging workflow. Test: python test_model.py --base BASE_RUNTIME --candidate CANDIDATE_RUNTIME. Source comparison expects regenerated manifest and generation metadata. BUILD.json records the already assembled isolated candidate, not a published executable. No game binary or runtime assets are in this backup batch.
