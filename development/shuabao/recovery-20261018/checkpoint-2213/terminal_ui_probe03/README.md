# Probe03: explicit startup HOLD diagnosis

The terminal production candidate and three non-runner fixture files are unchanged. This revision changes only fixture observation and failure reporting. It preserves the original 10-second preparation limits and every gameplay, visual admission and terminal-summary acceptance gate.

## Observed previous failure

The actual first terminal invocation was stopped externally after 328.68 seconds. Its original Host report says `status=HOLD`, `failures=[stable_startup_draws_timeout]`. No terminal-summary gameplay was reached. The previous fixture checked only `startup_session_error` and `floor_error`; the original preparation failure function writes neither, so it failed to terminate promptly on this explicit HOLD.

The failure does not prove a broken terminal summary, an actor-readiness failure, or a cold-cache cause. The original preparation window begins in an ancestor `_ready`, including synchronous assembly; that is a timing hypothesis requiring observations, not grounds to widen or bypass the gate.

## New diagnostics

- Read the original `_mainprep_receipt` and fail immediately on HOLD, interruption, a finished Host, entry rejection or an explicit startup error.
- Observe from the existing independent `process_frame` callback as well as the awaiting startup loop. Lock success off before emitting failure evidence; do not wait for the 470-second global watchdog.
- A separate 30-second fixture observation budget bounds an otherwise silent startup. It produces a failure, never readiness or permission to continue.
- Record the original stable-draw counter, attempted/pending flags, suppressed process count, actual Host draw count, current and last viewport sizes, original `start_ticks`, current observation tick and source phase/time/pause.
- Passively timestamp the exact original Host's `child_entered_tree` and `ready` signals, plus request-call boundaries and the first observed Host. Signal timestamps are observations, not a replacement readiness criterion.
- Save the raw live receipt if at most 64 KiB, otherwise save its status, failures and exact serialized hash/size. Do not duplicate the large actor/bone proof graph.
- Do not force-close/free a subtree still owned by a preparation coroutine. Exit the fixture with code 4 and report `source_released=false`; the external owned-process guard must establish actual cleanup.

## Run contract

Use the same exact 3047 production candidate, 98 verified cache files and four fixtures in a new sealed stage. Default `--terminal-outcome=victory` remains the priority. Defeat remains a separate optional invocation and report.

Entry remains `res://yan_terminal_full_floor_20261018c/runner.gd`.

Pass `--full-floor-evidence=/absolute/fresh/fixture_evidence` and the original supported Host argument `--ink-evidence=/absolute/fresh/host_evidence`. The two directories must be distinct. Choose paths accessible to the native process and evidence collector, rather than assuming that native `user://` shares the execution workspace. The fixture does not invent a new Host output API.

Do not interpret a subsequent warm-cache success as a cold-start defect being fixed. Production, preparation timeout constants, visual-ready bits and Host authority remain untouched. No engine has been launched by this package preparation.
