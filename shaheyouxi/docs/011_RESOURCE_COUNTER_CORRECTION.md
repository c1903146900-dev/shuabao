# Resource counter correction, separate from game correctness

The Linux cgroup-v2 documentation distinguishes memory type counters from reclaim
LRU lists: shmem is on the anon lists, not the inactive_file list.
Source: https://docs.kernel.org/admin-guide/cgroup-v2.html (memory.stat,
inactive_anon/active_anon/inactive_file/active_file description).

The previous local policy subtracted shmem directly from inactive_file and thus
counted that exclusion twice. The approved narrow correction is:

eligible = max(0, min(inactive_file, max(0, file - shmem))
                  - file_dirty - file_writeback - file_mapped)

The type-based file-minus-shmem cap also conservatively handles inconsistent
counter snapshots. All arithmetic remains integral; eligible//2 is credited,
plus min(slab_reclaimable//4,128MiB). Active file and anon receive no credit.
The file counter is now mandatory and missing/malformed/negative/duplicate data
fails closed. The policy identifier becomes
inactive_file_type_bound_half_plus_capped_slab_quarter_v2.

No owned RSS budget, effective reserve, raw floor, timeout, OOM check, process
cleanup or namespace requirement changed. For the pending native split gate these
remain192MiB owned RSS,900MiB effective reserve,192MiB raw floor,45s per process
and110s total. This is a counter interpretation fix, not a kernel configuration
change, cache operation, guaranteed reclaim measurement or real-time guarantee.

Eight independently specified byte-scale examples test shmem non-double-subtraction,
file-type caps, zero lower bound, conservative dirty/writeback/mapped deductions,
no active credit and integer truncation. Guard/network mock tests passed36 checks.
The separate1558 comparison JSON evaluates recorded raw counters under both formulas;
it does not rerun admission or alter historical refusal/failure statuses.

A read-only two-snapshot script is prepared, not run at this checkpoint. It records
all memory.stat/events/pressure readability, high/max/min/low/current and swap
counters in the desktop namespace30 seconds apart. It does not start an engine,
change a cgroup setting, reclaim cache or authorize a subsequent run.

Actual read-only pair `011_resource_pair_20261006T161144Z.json` is30.0009s apart
in desktop pid namespace4026532200. Raw930.22→932.72MiB; derived effective
1110.57→1113.42MiB. All high/max/OOM events were0; swap.current0. memory.high
and swap.high/max were unlimited, memory.max8GiB. memory.pressure was absent
(ENOENT), so this does not establish low PSI pressure. Full counters preserved.
No engine/config/cache action occurred in this measurement; terminal closed/reset.
