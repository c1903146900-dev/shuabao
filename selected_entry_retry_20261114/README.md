# Isolated selected-entry retry patch: STATIC ONLY

Independent patch from base PCK 87533e97b657add32a4fb6f0db2531fdf5847871994ffe11cc5ce3c31029a7db. It is not integrated or selected for delivery.

Selection is recorded before room entry. A pre-commit rejection leaves a selected node but the original map no longer offers it. This conditional source gap has not been reproduced through ordinary player actions and is not a demonstrated cause of the historical few-room complaint.

The patches offer only the same selected node when the original full preflight passes. The host uses a retry-aware selection wrapper, then its original entry call. Original two-stage preflight, commerce authority call, fresh-room checks, entry receipts and resource owners remain unchanged. There is no rollback, reselection, reward grant or second commerce path. Post-commit failure recovery is outside scope.

Local verification: 260 bindings checked, three Python test methods passed. Source comparison verifies original selection/preflight/entry methods and row-state bytes unchanged. Deterministic state-model cases cover first/second-preflight and commit rejection, same-node retry, wrong node rejection, entered repeats and committed-but-not-recorded room. Models do NOT execute GDScript or prove actual commerce behavior.

Run test_contract.py with BASE_RUNTIME and CANDIDATE_RUNTIME set to matching runtime roots for source checks. Without them the source test is explicitly skipped. Two model tests alone are not source validation.

Actual GDScript interruption/retry fixture is prepared locally but unrun and not included here. Parser/runtime acceptance, real ledger no-double-commit verification, commerce-denial injection, map discoverability, close/reopen, normal room regression, human play and Windows remain unverified. No engine or guard ran or changed. This package contains only these new patches, source pins and static test summary; no runtime tree, binary, asset, screenshot or raw log is included.
