# Single-headless 011core observation and resource-policy proposal

Status: code/mock instrumentation and conditional single61 pilot preparation only.
No engine run has been authorized by this document; runtime requires the separate
source-review/protection and explicit execution window. Existing v1/v2 refusals and game failures remain
unchanged. The working runtime still uses192MiB owned RSS/900MiB effective reserve/
192MiB raw floor and45s per command/110s total.

## What the previous data actually establishes

The1747 audit contains48 successful direct-headless011core report groups and one
successful three-process, sequential terminal-probe group. These49 groups are not
49 independent peak-rate measurements. Some groups contain multiple serial child
processes; the terminal group has no recorded cgroup minimum sufficient to derive
a growth peak. No group has a complete timestamped sample trace.

Largest successful owned-group RSS:197,599,232 bytes (188.4453125MiB), in
`011core_runs_20261006T093135827100Z.json`. A preserved failed run,
`011core_runs_20261005T220950938853Z.json`, reached201,510,912 bytes
(192.17578125MiB) and correctly failed the192MiB owned budget.

Largest recorded successful full-cgroup increase:364,294,144 bytes
(347.41796875MiB), in `011core_runs_20261006T042133440135Z.json`.
This includes shared/background memory and cache, not only Godot; that group's
owned RSS was much smaller. Sampling gaps and peaks between samples are unknown.
Neither successful exits nor zero OOM events establish low memory pressure.
The actual1611 paired observation found memory.pressure absent (ENOENT), not zero.

The900MiB reserve and192MiB raw floor are local conservative heuristics, not kernel
or platform hard limits. The measured8GiB memory.max is a distinct actual boundary.
Failure of a local admission formula does not prove the computer cannot run a game.

## Evidence-first observer, with current numerical thresholds

The proposed opt-in observer applies only to direct headless Godot commands in
011core. It excludes GUI, import/editor, Python network coordinators and concurrent
engine workloads. Non-opt-in runner behavior is unchanged.

Every sample has monotonic start/finish/duration, complete cgroup counters and
complete owned-group RSS metadata, leader liveness, high/max/OOM deltas, cgroup
usage change, and explicit PSI availability. A bounded NDJSON journal is appended
and flushed once per sample. The small summary retains peak RSS, maximum sample
gap/duration and maximum adjacent growth; it does not rewrite an ever-growing
trace repeatedly. Essential live metrics missing or malformed fail closed.
Unavailable PSI is disclosed, never interpreted as low pressure.

Changes in memory.events high/max/OOM fail the observation. Any exception, including
interrupts or evidence-write failures, attempts cleanup of only the PGID recorded
for this start_new_session child, in its original PID namespace. Proposed cleanup
is TERM with at most100ms grace then KILL if needed for resource, telemetry or
sampling failures. OOM changes or raw emergency breaches require direct KILL.
After KILL, reap and empty-group verification share at most6 seconds; these6
seconds are not a grace period during which allocation is permitted. Cleanup timestamps make actual latency inspectable.
No other process is adopted by name, and inability to prove cleanup is an unresolved
failure, not a successful release. The old8s grace remains historical behavior.

## Candidate v3 for a later, explicitly approved single-core pilot

No candidate number below is active in existing/default launchers. The proposed
pilot is restricted to exactly the fixed61-method legacy asynchronous regression,
not any single-core workload chosen later. Keep the192MiB owned cap: observed188.45MiB
has only3.55MiB margin, and the failed192.176MiB case is not erased.

A transparent candidate uncertainty budget is384+128+256=768MiB:
-384MiB rounds the observed347.42MiB whole-cgroup excursion upward
-128MiB is an explicit unmeasured-peak/scheduling uncertainty allowance, not a
 statistically derived confidence interval or a measured growth-rate guarantee
-256MiB is an emergency/cleanup buffer, stronger than the current192MiB raw floor

Candidate only: effective runtime reserve768MiB, hence startup effective960MiB
including the unchanged192MiB owned cap; startup raw at least768MiB and runtime raw
at least256MiB. These extra raw requirements are stricter than the current384MiB
startup/192MiB runtime raw checks and prevent admission relying only on reclaim
credit. The candidate is workload-specific, not chosen by subtracting today's
shortfall from the current threshold. It is more conservative than simply copying
a640MiB reserve from older, different-workload experiments.

The384MiB excursion already includes the task and shared background. Adding192MiB
again in the startup effective960MiB rule is conservative overlap, not an assertion
that the task was absent from the historical growth.

This finite-sample budget cannot guarantee absence of OOM under arbitrary external
cgroup growth. Before adoption, review the observer's mocks and resource history,
then approve at most one bounded single-core pilot with full trace, unchanged
45/110 timeouts, high/max event checks and short owned cleanup. Review actual gaps,
rates and residual headroom afterward. Do not automatically lower thresholds again,
activate this for other workloads, or mark the currently unrun61/host/Frame gates
as passed. The pilot must target100ms samples and reject a completed-sample gap above250ms,
including the first launch blind window, or an adjacent cgroup rise above128MiB.
These are explicit fail-closed pilot controls, not reconstructed old observations.
Missing essential telemetry/log writes, changed high/max/OOM and unresolved cleanup
forbid a successful result or the next process. PID/group identity changes must not
redirect signals to a newly discovered or recycled process group.

## Source verification (2026-10-06 18:08 UTC)

Combined pure Python/mock suite:261 passed. Independent read-only review:44
observer plus26 integration mocks passed, shell syntax and diff checks passed.
No real child process or Godot was started for these mocks. Sources and hashes
are recorded in `011_core61_v3_source_review_20261006T1808.json`. The fixed61
pilot remains unrun and requires a separate execution-window authorization.

## Single attempt and metadata correction

The authorized 18:11:08 UTC pilot attempt was refused before launch: effective
991,751,082 bytes was below1,006,632,960; raw797,798,400 was below805,306,368.
Zero engines and zero methods ran. Thus there is no runtime trace or measured
observer cleanup result, and the61 gate remains unrun. Wrapper260933 returned2;
the desktop terminal disappeared and CUA was reset. No retry was performed.

The preserved original report contains a stale top-level legacy TERM-grace value8.
No grace was applied because no child was started. Subsequent source corrects only
opt-in metadata to the actual0.1 seconds; old paths retain8. Combined261 mocks pass.
The related background-cleanup correction is recorded in the refusal companion:
an unrelated fake-test descendant was not reliably observed terminated, so this
sample is not described as a proven quiet-background baseline.
