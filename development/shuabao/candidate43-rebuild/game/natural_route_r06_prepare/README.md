# Continuous natural route through r06 — frozen preparation

This is a new full original zero-resource run through r01a → r02a → r03a → r04a → r05a → r06a. No prior gameplay checkpoint is loaded or restored. The verified r03 replay files and production source are unchanged. This preparation started no Godot, parser or GUI; there is no r06 combat result yet.

## Exact additions after the verified r03 stage

- Preserve both original first battles and the original r03 RestSession settlement/readiness verification before any new action.
- With actual remaining SP and Q1 rank2, use the original visible growth button/HUD adapter route to request Q1 rank3. If unavailable, record `upgraded=false`; do not force rank or fail solely because an optional upgrade was skipped.
- If actual gold is at least200, open the original safe shop and buy exactly one `potion:1` (生命药剂I, displayed price200), requiring the actual quote to be accepted, its charge no greater than200, and the real Purchase button visible and enabled. Emit that button's original signal, retain its token/Session receipt, verify gold debit and one additional bottle, and close the shop through the original Host action. Insufficient actual money records `purchased=false`; no money is injected.
- Enter r04a training via the original connected route. Open the actual training tab, record its900-gold price, live eligibility/reason and disabled button, then close it and use original Continue. No training payment, choice, reset, free grant or random draw is invoked. The same inspection/readiness flow applies at r06a.
- Enter r05a, whose original roster is one elite and three minions. Reuse the same current-visible-body WASD/BASIC/Q1 policy. Do not modify enemy state, balance, damage, source time or attack cadence.
- In combat, if the player's actual HP falls strictly below60% of actual maximum HP, emit the current visible, viewport-present, enabled `药I ×n` button's original signal once. There is no potion keyboard hotkey in this implementation. No signal is emitted if the threshold is never met; an attempted but rejected use is reported separately.
- The original potion consumer alone heals across four seconds of the existing character combat clock. The replay never calls use_potion, heal, heal_actor, consumer.advance or direct recovery methods. Read-only observations retain the original consumer's `active.left`, `active.actual`, rate, committed-effect count, actual HP and hero_time. Damage taken can overlap recovery, so net HP delta is not misrepresented as total potion healing.
- After the original r05 terminal and four scoped deaths/rewards are verified, enter and complete original r06 training readiness. Stop there.

## Original authority references

- `docs/equipment_source_20261004/correction_0959/equipment_system_extracted.json:3499`: potion:1, 生命药剂I,200gold,20% maximum HP over4seconds.
- `tests/equipment_editable_tables_20261004/outputs/equipment_tables/converted/equipment_numeric_config.json:2383–2400`: duration, recovery percentage and price parameters.
- `tests/ink_shop_ui_host_20261004/shop_panel.gd`: `_set_category`, `_select`, `_buy.pressed`, original quote and token. `tests/ink_intermediate_shop_ui_20261004/shop_panel.gd:54` keeps original buy/craft dispatch.
- `visual_rework_20261009/runtime_host.gd:305–321`: the actual current FormalTrainingPanel and TerminalPotionControls are mounted on the retained Session.
- `tests/ink_equipment_live_20261008/content01/potion_controls.gd:19–49`: real bottle inventory controls, visible tier buttons, disabled conditions, and the original bound UID use callback.
- `visual_rework_20261009/postboss_potion_controls.gd`: original terminal-state rejection remains active.
- `tests/ink_equipment_live_20261008/content01/potion_model.gd:29–52`: original economic consumption and consumer admission, never called directly by this replay.
- `tests/ink_potion_recovery_20261008/candidate01/potion_consumer.gd:3,27–46`:20% tier,4seconds, original combat-clock advancement and observed actual healing.
- `formal_training_20261009/panel.gd:63–94` and `formal_training_20261009/model.gd:62–81`: original900-gold eligibility and disabled payment projection. No `training_pay` or `training_select` action is sent.
- `tests/ink_first_floor_user_route_20261005/runtime01/first_floor.json`: r03a→r04a(training)→r05a(elite_a)→r06a(training) connections and original roster.

One potion occupies an equipment slot. Record actual before/after stats, HP and the original health projection; do not assume a change in the initial Hex bonus. Its empty-slot effect may already be capped, so six empty slots becoming five need not change effective layers. This replay does not compensate for any genuine projection change.

The safe-entry `hero_too_close_to_next_spawn` behavior, real mandatory Hex handling, original shop close action and actual automatic growth-panel collapse remain inherited from the verified r03 replay. Only visible/current objects guide combat input. There is no global navigation or future enemy prediction.

## Evidence and success boundaries

Success requires the same original owners throughout, three real combat terminals with4 scoped deaths and accepted original rewards each, the already-verified original r03 rest receipt, original training readiness records for r04/r06, and six connected original row completions. Training must leave gold/SP/body/HP unchanged. No training outcomes are manufactured.

The report separately includes `rank3_upgrade`, `potion_purchase`, `potion_uses`, `potion_observations`, `training_skips`, service records and combat records. A route pass does not itself claim Q1 rank3 was obtained or a potion was used. Read their actual accepted/upgraded/purchased fields and final rank/inventory. Potion input is explicitly a real button signal triggered by synthetic replay, not keyboard input or native manual play.

Death, a rejected mandatory action, a source fault, insufficient time or missing final evidence is incomplete/failure. A partial route remains useful evidence and is never replaced with a funded or lethal fixture. Whole-floor/Boss completion is not claimed.

## Frozen files and launch boundary

`natural_route_r06.gd` dynamically loads adjacent `visible_route_r06.gd`; keep them together. Two `.gd.diff` files show changes relative to the unchanged r03 source. `preparation_manifest.json` records exact frozen SHA256s and static verification.

The original100-second wall observation still starts at script initialization and never resets. The parent's110-second external guard is unchanged. The previous r03 run took46.145seconds, which only suggests a possible time window for this stage; it does not guarantee an elite clear. No budget or clock changes were added.

Only a separately authorized engine window may parse or run this preparation against the unchanged training12 PCK/source binding. Use the parent's existing guarded GUI launch and a fresh `--natural-evidence` directory. This preparation has no engine-pass claim.
