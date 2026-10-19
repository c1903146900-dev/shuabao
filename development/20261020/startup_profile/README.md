# Opt-in startup timing candidate

Status: NOT_RUN. No native parser, startup-admission or performance result is claimed. This is a diagnostic-only proposal, not a released or integrated game update.

Base pack SHA256: 00e2180c6556b26ce0f74ad19e8005ff5243bbd1c424a514e87a218c289f28fe.

The three payload files are complete candidate GDScript sources. SOURCE_PINS.json records exact original and candidate SHA256 values. PATCH.diff contains only added observation statements and a bounded helper. Removing those additions restores the original sources byte-for-byte, as checked in STRIP_EQUIVALENCE.json.

## Interface

Enable with --trial-startup-profile. Read the final live Host's startup_construction_profile() once after ready or when diagnosing startup failure. The returned dictionary contains enabled, closed, rows, dropped, scope and deferred_warmup_included. Each row contains label, begin_usec, end_usec and elapsed_usec. At most 64 rows are retained. No per-frame logger, automatic report file, large world snapshot or actor reference is added. Disabled observation does not read the timer clock.

## Timing boundaries

Sixteen intervals separate total inherited ready, initial stage/UI creation, inherited encounter initialization, initial Sim/router, initial/final actor construction, other views, session construction, reward configuration, definition load, initialize_floor, initial/final refresh, final identity verification and startup report creation including argument evaluation.

Intervals are nested. Do not add ancestor totals to their children. Unmeasured remainder is not automatically hashing or model-construction time. Later deferred/asynchronous viewport warmup and first usable draw are outside the closed ready interval and require existing receipts or an external observer.

The original calls, order, branches, ownership checks, source seals and failure returns remain. This proposal does not remove actor construction, bypass hashes, cache authority results, modify gameplay timing or alter formal rules. Historical source pins must be migrated explicitly and verified before a diagnostic build can run. Unknown source changes must still reject admission.

## Reproduction boundary

Apply only to a separate diagnostic source tree whose three original hashes match SOURCE_PINS.json. Check exact consumer bindings and register explicit predecessor/current-source migrations; do not silently substitute these files beneath unchanged authority pins. Run only after that diagnostic pack has been approved, using the official Godot GUI and an owned-process guard. No engine execution is included in this evidence snapshot.
