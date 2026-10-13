# 011 predicted presentation: source-grounded next-step draft

No implementation, protocol change, runtime test or acceptance is claimed here. Current pending task remains restored cold import and the frozen ENet reconnect diagnostic.

## Source requirement and observed current seam

Direct original cehua paragraph22 requires immediate local pressed/held/released action, aim, dodge-afterimage and other predicted presentation while the server remains final authority over resources, cooldowns, legal position, damage and control. Paragraph84 retains eight-direction WASD, no sprint, single Shift edge and last valid movement history for stationary dodge. The technical GUI currently renders authoritative geometry only; real S/Shift/mouse/F10 evidence does not satisfy this prediction requirement.

`ActorInputPending` explicitly tracks admission-only sequences. `ActorMotion.accept_input` applies action/resource decisions and updates latches at current server clock, while position advances later in the owner physics step. Therefore accepted_sequence is not proof of movement integration or action success. Do not relabel it as a simulation acknowledgement, infer that every covered press succeeded, or use it alone to re-run and commit client gameplay.

## Small presentation-only step to review before coding

Maintain a separate bounded local presentation state keyed by full world/epoch/profile/actor/peer/input_generation and locally issued sequence. Feed it only intents that the existing local producer actually issued; remote actors stay snapshot-driven. Never write ActorClientState, authoritative actor positions/resources, SaveStore or collision bodies from this state. Clear it on binding loss, stream change, send failure and teardown; an old cache may not revive it.

First prove immediate local aiming/action presentation and correction with fake delayed snapshots. A tentative action is not a gameplay success or resource deduction. For dodge, use the formal table and known last valid movement history, but account for the fact that public snapshot currently lacks all private control/timer fields. A controlled/rejected action must not become an authoritative dodge merely because its sequence was admitted. Server state supersedes discrepant provisional presentation; the correction policy must be explicit and cannot rely on global time scaling/hit-stop.

Do not silently expand this into deterministic movement rollback. If positional prediction/replay is added, first specify a true simulation-covered boundary and its association with snapshot position/clock, plus collision/materialization data and reset rules. Existing accepted_sequence alone is insufficient. Any new wire fields/version require strict validators and compatibility refusal; old save migration remains the separately documented user policy.

## Finite first evidence targets

- Input presentation changes before a delayed authoritative snapshot arrives
- Admitted-but-rejected dodge does not become confirmed merely from cursor coverage
- Later authoritative position/aim/action state corrects only local presentation
- Disconnect/reconnect generation resets presentation and cannot resurrect old provisional state
- No predicted resource/damage/position reaches authoritative model, outgoing input envelope or save
- Technical projection pass precedes a separately allocated real GUI observation; no formal-art or full-playability claim

This is a bounded planning note only. It does not alter the frozen game source or unblock the pending import/reconnect test window.

## First isolated source slice — 2026-10-06 04:17 UTC

Cold import and the frozen reconnect diagnostic have now completed successfully; see CURRENT and runtime evidence. actor_local_presentation.gd is a new disposable RefCounted pure display state with 13 authored, unrun methods. Production GUI is unchanged. Caller integration must feed only production-send-success intents and close on all binding/send/teardown paths. A newer actor revision replaces provisional aim/action hints without consulting cursor coverage; duplicate revisions preserve newly issued display. This deliberately conservative first policy can withdraw hints before input reaches the server. It makes no positional prediction, dodge afterimage, action-success receipt, or full P22 completion claim. A changed stream permanently closes the old presentation instance; a new one is required to rebind. No engine was launched while implementing this slice.

## Model gate completed; next proposed seam

The isolated13methods now pass in the actual engine. Next bounded source step should integrate only the explicit play client: after successful production send, take the same current validated checkpoint and feed the exact locally generated sequence/intent; on accepted snapshot synchronize this display state; on every loss/stop/failure/cleanup close and clear it. Keep the sampler and wire envelope unchanged. PlayView should draw local aim/action hints from separate display records and retain authoritative actor positions/resources and all remote actors unchanged. Test adapter dispatch, stale-generation/loss cleanup, same-cache correction and draw-record separation before any new real GUI allocation. Any display/metadata label change must also update the corresponding GUI probe expectation rather than silently accepting an old label. This is not dodge-afterimage or full prediction completion.

## Play-client source checkpoint — 2026-10-06 04:41 UTC

Production-send-success now feeds exact local sequence and the same current checkpoint into the isolated model. Snapshot consumption first clears the view, then republishes synchronized local display; legal duplicate revisions preserve fresh provisional hints. Pending close and cleanup clear both model and view. A dedicated first-stop gate prevents a failed publish plus dispatch propagation from repeating transport/report/quit effects or overwriting the first failure. Adapter coverage now includes duplicate republish, focus-cleanup send failure, and publish-error idempotence. Model13 + Adapter16 + View15 = 44 engine methods authored; this combined candidate is UNRUN. The 36 Python runner mocks and source/cache preflight pass. No engine or CUA launched for this checkpoint. Position prediction, afterimages, formal art and full P22/011 remain unimplemented or unaccepted.

## Play-client gate completed — 2026-10-06 04:47 UTC

Frozen source b9a2ac3 passed all 44/44 methods across the three suites, with 0 errors, failures, skipped cases or orphans. Actual report: evidence/011core_runs_20261006T044708330047Z.json; exact runner log is retained alongside it. One headless Godot PID/PGID135469 exited0 and was verified absent, as was its process group. Peak owned RSS119951360bytes stayed under the unchanged192MiB guard. Terminal launch used the approved Application Finder command and delayed wrapper; CUA reset before admission. New presentation pixels and real focus-loss inputs still require a separately authorized GUI window. This completes the narrow local aim/action model-adapter-view seam, not positional prediction, afterimages, formal art, or full011.
