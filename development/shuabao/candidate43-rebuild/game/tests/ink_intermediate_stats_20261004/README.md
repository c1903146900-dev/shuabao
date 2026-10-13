# 17 intermediate equipment: isolated source candidate

This directory extends the exact initial-Hex c997 composition. It has not been run in Godot by its author. Original source/stages/bindings, main host, input, art, reward values, and CURRENT_STATE are unchanged.

## Supported slice and source feasibility

I01–I11 and I13–I18 are supported as plain stats, alongside existing base B01–B11. Their 17 recipes depend only on those existing supported base items. All18 intermediate source entries have no passive, active, or task mechanism. `source_map.json` lists exact original item names, descriptions, formal parameter IDs/units/current values/source values/source references, components, prices, and derived combine fees. No recipe or source mechanism is changed.

B12 and all of I12 remain HOLD: the source regen number has no time unit. Known I12 HP is not used as an excuse to sell an item with inert regen. All final equipment and consumable combat effects remain unsupported. Actual table values are the original unbalanced values; this is not a balance pass.

## Runtime composition

- `ink_intermediate_sim.gd` inherits the exact initial Sim, hence H02, six real common hooks, the HP observer, and original combat/input/reward algorithms. It adds no implementation or authority.
- `intermediate_stat_adapter.gd` first delegates all12 base definitions to the tested base adapter, then maps18 original intermediate rows from the formal numeric parameter map. One row is wholly unsupported. Missing, invalid, negative, nonfinite, or wrong-unit stats fail closed. Current values never come from historical prose.
- `ink_intermediate_model.gd` inherits the same initial model/HP transaction wrapper/single ledger/frozen commerce kernel. It changes only support/status metadata. The inherited effect consumer sums actual held UID entries; consumed components become audit lineage, not extra stats. The one six-slot inventory, exact inverse patches, task dependency receipts, and no-general-restore policy remain inherited.
- `ink_intermediate_bridge.gd` explicitly admits only this exact Sim, substitutes this adapter/model at fresh startup, and uses the same initial stat consumer on both health and bridge paths. Runtime defaults remain Lv1/0gold/1SP. No funding method is added.
- `live_binding.gd`/`capabilities.json` bind exact candidate hashes, preserve the eight initial-Hex source hooks, and leave ordinary/native acceptance false. Existing initial controller may be used because the model selector API is unchanged; no UI host is modified here.

HP semantics remain the approved HP fix: a valid same-visit/no-dependent-health-event inverse restores only its transaction's recorded clamp, without healing procs. Real health changes seal HP-sensitive transactions. Irreversible consumed-item and reward dependencies seal their lineage, unrelated transactions may still reverse, and body purchases never reverse. Close/reopen UI preserves the visit; ANY next room commits it. Nothing creates a second wallet, reward authority, inventory, or general snapshot rollback.

## Main-owned finite engine gates

1. Run `python tests/ink_intermediate_stats_20261004/verify_source.py` (Python-only, writes only this directory)
2. Stage to a new empty destination: `python tests/ink_intermediate_stats_20261004/prepare_stage.py --dest <new-main-stage>` (copies only bound sources, starts no engine)
3. Main may serially execute the following scripts in that stage with its resource guard and preserve separate actual logs/exit/results:
   - `res://tests/ink_intermediate_stats_20261004/intermediate_gate.gd`
   - `res://tests/ink_intermediate_stats_20261004/common_regression_gate.gd`
   - `res://tests/ink_intermediate_stats_20261004/hp_regression_gate.gd`
   - `res://tests/ink_intermediate_stats_20261004/selector_regression_gate.gd`

The new gate checks all17 recipes, full/partial ownership, exact component identity/order/lineage, combine fee, buy/craft/sell/undo/replay, six-slot replacement, no duplicate component stats, editable-parameter and HOLD admission, same-visit close/reopen, intermediate HP clamp inverse, actual heal dependency sealing, external receipt lineage, body never-undo, ANY-room commits, G24 slot changes, and G30 craft debit/35HP clamp inverse. It separately exercises real BASIC/Q1 damage, cooldown, attack interval, crit, lifesteal, mitigation, tenacity, and locomotion. Finite funds are explicitly assigned only in the gate after asserting normal defaults. No forced kill/reward modification is used. The external task receipt is a generic inherited seam test, not an invented intermediate task or an actual task reward.

Three regression gates are explicit copies of the initial-Hex fixed sink, HP, and selector tests with only new Sim/Bridge/Model binding paths and result identities changed. `regression_rebindings.patch` records every difference. Thus all six common actual hooks and H01/H02 can be rerun in the new composition; earlier905/185/25,349 results do not become this candidate's results. No old lossy-HP assertion is silently treated as the new policy.

Main can additionally audit all four full logs/results with `inspect_engine_results.py --stage <stage> --runs <runs.json>`. The receipt is a JSON list of script/exit_code/log_path; paths resolve beside that receipt. Supply merged stdout/stderr logs. The auditor requires a matching terminal report and full copied-regression counts (905 common,185 HP,25,349 selector/288 runs), preserving the prior accepted gate breadth; these expected counts are not new execution results. The helper starts no processes and rejects missing output, incomplete case markers, runtime errors, nonzero exit, changed source hashes, wrong candidate identity, or assertion failures. Timeouts must be supplied as nonzero exits. A log that contains SCRIPT ERROR fails even if a nested helper later returned control to the test caller. The source result is not a Godot syntax/runtime pass. Native UI, ordinary initial selection, later milestones, full floor, final equipment, consumables, balance, Windows, and user acceptance remain separate.
