# Front world combat sample: new implementation, unexecuted

Parent: `recovery_20261018b/worldfx_ui_native03/source/game`, 3046 files. Entry preimage SHA256 `50ed11e0c188bd4114dec928fc0d6f69820b2630244a66d1fbcdba3e83dcb764`. The parent contains existing P3, WorldFX and UI. This folder is a payload draft, not a new frozen source tree.

Deploy controller/renderer/geometry/mapper/capture plus 3 PNG to `res://yan_front_hero_20261018/`; deploy entry.gd to existing `res://yan_visual_attach_20261018/entry.gd`. Tests are not production entrypoints. Existing WorldFX synchronous event connection and deferred UI projection remain byte-preserved around the new thin hook. No entry launch override, actor replacement, Sim call, skill modification, or physics/collision modification.

## Reused evidence

Native06 continuous 2D geometry was drawn successfully and visually reviewed at idle/Q1 key poses. Its complete sleeve curve is retained. Direct world spatial material and 3D vertex conversion are NEW and have not been parsed or drawn yet. capture.gd is copied byte-for-byte from the extant restored file, not reconstructed from a summary. The old reducer is absent. mapper.gd is a new small implementation.

## Actual source mapping

Actor is `host.hero_view`, camera `host.stage.camera`, renderer sibling under the same Host. Current Actor report is produced by `tests/ink_q1_flow_20261005/gesture06/root_return_rebuilt01/recovery_follow02/hero_view.gd`, lines 57–71/234–235. Exact current `sample_report.upper` decides idle/basic/Q1; `upper_time-first` divided by original key_windows.span determines basic/release progress. No cooldown, button hold or projectile travel interval is used as attack duration. Q1 drawing/hold uses true input.draw_fraction, retaining the observed same-gesture draw fraction when committed release arrives. Cancelled previews do not cancel committed waves. Original source+room+generation+clock/domain identities come from capture. Original actor is retained and continues all animation/source processing.

Gait phase is derived from actual accumulated gait elapsed, original .50s cycle, independent of upper motion; pause leaves authority time unchanged. Same source-time metadata is required. Current front sector is camera-ground +Z ±45 degrees. Other sectors, upper actions, ultimates, dash, stun, knockback and death restore original appearance. This is explicitly a partial front integration sample, not final full-action 2D coverage.

Basic pose is a newly authored short brush strike using the native06 continuous rig, sampled over the actual original basic clip. It has NOT had art or native acceptance. Q1 partial-draw release origin continuity is new and unverified. Full-draw release preserves native06 trajectory.

## World presentation

Direct MeshInstance3D meshes with spatial unshaded alpha/depth-prepass material. No SubViewport, HUD overlay, no_depth_test, time advance or screenshot loop. Pixel geometry is converted around sole anchor (210,612) with fixed 2.181m height, matching original static GLB ground-to-head extent approximately. Camera-facing basis and current original Actor world position determine placement. Layer z spacing 0.0005m preserves continuous skin ordering. All candidate meshes must pass original finite/positive triangle checks before any commit; visibility switches only after commit succeeds.

Exactly nine explicitly named skin MeshInstance3D under the original Skeleton are layer-hidden; bindings record original parent/mesh/skin/layers. Restoration only writes originally owned zero layers while exact binding remains. Blood bars, effects, R nib, sockets and original actor transform are untouched. R nib is source-hidden for non-R, but real scene ordering still requires native verification. Failure locks the adapter and restores owned original skin.

## Required next validation

- Source review first. No engine has run this payload.
- contract_tests.gd contains 12 cases using production mapper, not executed. It preloads renderer/controller for eventual parse coverage.
- Actual original Host event ordering, Q1 hold/release/partial preview cancellation and pause.
- World scale, sole anchor, transparent edge depth, body/hand layer overlap and real foreground/background occlusion.
- Native original basic→idle and stationary/moving Q1→idle; no invented stop capture or redraw requirement.
- Unknown action/sector fallback and owned-skin restoration on room disposal.
- First load cost and direct-mesh per-draw construction cost, no timing claim yet.

No original native combat PASS is inherited. Assets remain development candidates. Other directions/actions need future real assets/animation support.
