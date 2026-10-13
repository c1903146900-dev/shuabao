# Rain foundation fix01: bounded source corrections

All source audit, parse, engine, native, and visual evidence remains **NOT_RUN**. The original candidate is preserved byte-for-byte under its original paths, including its known-failing finite callback fixtures. `failed_parent_pins.json` identifies every original file before this revision. These findings were established by independent source review, not by an engine run.

## Exact changes

1. `input_adapter.gd` extends the original adapter. `suspend_input` resets the physical E-down latch; it retains only exact still-live cast/generation/room ownership. It does not call E-up, change a timer, cancel a form, or trigger a burst. A genuinely delivered late E-up can still release that same live cast, including queuing while paused. A new down rejected because that cast remains active does not erase the ownership. Lost-up natural expiry cannot cause auto-recast, and a later genuine down after cooldown can recover. A stale late up cannot target another room/root.
2. `finite_gate.gd` corrects only the callback fixture's illegal room transition: callbacks synchronously call `end_encounter`; `begin_encounter` rejection while `transaction_active` is explicitly asserted. The replacement room is then begun after the public action returns. The nontransaction hitstop-mark callback keeps its legal immediate transition. No runtime transaction contract changes.
3. `ink_e1_sim.gd` extends the original Sim and observes committed `_h02_move_target` before/after positions, covering the newborn endpoint remainder that runs after ordinary pull/push/AI. During `_step_pull`, the inherited pull is observed immediately before the first H02 leg (or at completion if there is no H02 leg); each H02 leg is observed separately. Only the obsolete whole-`_step_pull` aggregate observation is suppressed. This prevents a false diagonal/chord mark across a bend. The patch does not intercept arbitrary `_move_clipped` calls, which may include AI's uncommitted path probes. Shared core, H02 movement, wall clipping, source values, and all existing motion methods remain untouched.

## Finite new evidence to execute

The fix gate retains the original 16 groups and adds three bounded groups:

- Suspension/lost-up recovery, unchanged form deadline/no synthetic release, late genuine paused up, fresh down during a surviving form, and stale-room up isolation
- Real Q1 length0.24m at source24m/s ends0.01s into a0.02s tick. New H02's source3m/s moves an enemy0.03m across the rain-body boundary during the newborn remainder. One inherited core tick and one rain mark are expected; no damage or hero movement is added
- An explicit local-method bent-leg fixture creates a real Q1/H02 zone, then inherited pull `(-1,1)->(1,1)` followed by H02 `(1,1)->(1,-1)`. Each committed leg stays1m from the hero, outside combined radius0.9m; their aggregate diagonal would wrongly intersect the hero. The expected mark count is zero. This is labeled a local fixture, not an additional simulated world tick

The independent reviewer is checking these exact semantics. No test result is presumed. Ordinary-only phasing remains **NOT_PASSED_PENDING_TECHNICAL_REVIEW** and no full E1 or host acceptance is claimed.

## Unchanged authority

Original parent `source_basis.md` remains the exact authority explanation for all source paragraphs/61 numeric cells, accepted-effect-entry cooldown, independent H08 entry second, actor constructor identity and equipment/common/derived speed layering. Parent source and shared engine methods are pinned by `failed_parent_pins.json` and the unchanged Q1/Q3 runtime map. The new runtime stage contains the four original runtime files needed by the wrapper plus this fix01 directory; it deliberately does not execute the old known-failing gate.

Only the candidate wrapper and input adapter paths change for the corrected gate. The original source oracle is copied into this directory with root resolution and the exact inherited runtime inventory adjusted for fix01. It still checks original DOCX/XLSX and the protected current maps, and now pins every original candidate file as well. No audit has been run.

## Main-owned commands

1. `python tests/ink_e1_rain_foundation_20261005/fix01/freeze_source.py`
2. `python tests/ink_e1_rain_foundation_20261005/fix01/source_audit.py --write`
3. `python tests/ink_e1_rain_foundation_20261005/fix01/prepare_stage.py --stage <fresh_external_stage>`
4. `godot --headless --path <fresh_external_stage> --script res://tests/ink_e1_rain_foundation_20261005/fix01/finite_gate.gd`

Do not run the original parent freeze helper over the newly versioned subtree. The fix01 helper preserves and stages the exact intended parent runtime dependencies while keeping the original source-review failure intact. No helper above has been executed by this author.

## E1-STAGE-01 dependency correction, before freeze

The first independent fix01 follow-up passed23/24 source checks and identified an unmapped preload in the admission gate. That failed check and the previous authorship manifest/helper sources are preserved under `failure_E1_STAGE_01/`; neither is represented as a passing stage/engine result.

The admission assertion preloads the current `live_binding.gd`, which is intentionally absent from the Q1/Q3 runtime map it reads. Its `runtime_binding.json` is likewise absent from its own map by design. `fixture_dependencies.json` now explicitly lists both as read-only negative-admission fixture dependencies, using the exact unchanged entries from the pinned normal-host source binding:

- `tests/ink_q3_input_growth_20261004/live_binding.gd`: SHA256 `81baec0cc1f3da7aae8346d0391764286ab572735a378d192b8657b6a3b5f6a7`
- `tests/ink_q3_input_growth_20261004/runtime_binding.json`: SHA256 `ba92830cf08fb056a23e831e1b86f1ab398feb81e5f36680d7cf97aa90c06504`

The fix01 freeze/audit/stage helpers compose the unchanged214-entry current runtime map, these exact two explicit fixtures, the four inherited E1 runtime files, and fix01's source files. They preserve the current `runtime_candidates` and `source_implemented_hooks` values verbatim and record `read_only_fixture_map` separately. The source audit checks each fixture entry against the exact pinned host map and verifies it replaces no current-map entry. No host capability is added or weakened; the fixture continues to assert rejection of the isolated E1 script.

No freeze, full source audit, staging, GDScript parse or engine was run for this correction. A transitive static dependency read is the next independent review; main still owns execution.
