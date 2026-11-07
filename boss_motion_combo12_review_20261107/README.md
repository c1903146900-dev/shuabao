# Boss motion rebase onto combo12/13: accepted in motion_combo14

The overlay is derived from motion_combo12, with only the reviewed Boss additions
from boss_motion_review_20261107/changes03. It does not overwrite combo12 with an
old presentation file. Combo09/10 entry and host input boundaries, combo11
directional player recoil, combo12 pitcher ink, enemy facing, flash and exact
alpha picking remain intact. No mechanics or assets change.

Files:
- prepare_overlay.py: checks pinned combo08, candidate03 and combo12 identities;
  reconstructs candidate03 exactly; applies only those additions to combo12;
  verifies their removal restores combo12 exactly; checks protected functions.
- changes/fengli_route_20261024/presentation.gd: generated additive overlay.
- boss_additions.patch: human-readable difference against combo12.
- static_review.json: results of the preparation checks, not engine acceptance.
- build_isolated.py: optional isolated copy/seal/pack builder. Refuses existing
  outputs, source drift, extra files and any runtime change except presentation
  plus the two generated seal files. Never launches Godot or changes the guard.
- verification_plan.md: actual-input plan and prior observer limitations.

Preparation check:
`python -B boss_motion_combo12_review_20261107/prepare_overlay.py --check`

Build only after the current guarded run finishes, not concurrently with it:
`python -B boss_motion_combo12_review_20261107/build_isolated.py boss_motion_combo12_draft01`

The builder is pinned to accepted combo12. If a later candidate becomes the new
accepted baseline, review and rebase again before building; do not drop its new
changes. The separate returnstroke candidate is not incorporated or overwritten.
This preparation note predates the live runs. See live_validation.md for the built combo12 and combo13 candidates, actual narrow Boss pass and remaining checks.

Historical candidate03 remains unaccepted. Its short startup and isolated drawing
fixture passed, but none of its guarded ordinary-route attempts reached the Boss.
The last H08 route attempt stopped around room3 under the unchanged sampling
guard. A verified initial UI path selects H08 and learns E1, and a real room1
dagger contact applied its stun. Neither proves Boss cancellation or live body
event handling. Do not report those missing checks as passes.

Latest status: the combo13-based exact tested content is accepted as motion_combo14. See live_validation.md and motion_combo14_review_20261107/README.md; older preparation limits below are historical.
