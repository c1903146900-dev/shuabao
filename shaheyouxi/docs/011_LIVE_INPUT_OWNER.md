# 011 explicitly enabled fixed-roster input owner

This source slice connects the existing schema4 owner to its existing Frame for
bounded movement and natural F. It remains disabled by default. Source authoring
and review are not native, transport, process-exit or gameplay acceptance. The
preceding legacy compatibility and shared-core gates belong to their protected
revisions; this change needs its own gate. Earlier idle/no-owner benchmark results
do not measure this workload.

## Activation and supported scope

`activate_supported_input_phase()` is a server-only, non-RPC, one-time method.
It requires the actual owner-bound confirmed initial/bootstrap Frame, a nonempty
confirmed underground roster, startup readiness, and no pending bootstrap or
hello work. It binds each actual authority peer/profile/actor/input generation,
the owner services/epoch/world, and each real remote connection incarnation.
Local input continues to use the inherited non-RPC host method with constant
peer 1; remote RPC continues to supply the sender captured by the base wrapper.
No client field chooses an actor, generation or host trust.

Activation performs a fresh synchronous actual `bootstrap_join` save and requires
its complete result before enabling input. This deliberately consumes another
save sequence and uses an already supported save reason. A stale or forged output
receipt cannot enable the phase. This extra durable boundary and fixed roster are
engineering choices for this limited entry, not gameplay rules from cehua.
The same Frame and frozen actual runtime/save terrain roots remain bound; no
Frame reconstruction or lineage reset is permitted.

Native support is still the existing 147 underground cells in three 7x7 regions.
Outside coverage stays unknown and rejects. A new player's surface birth and the
surface-to-underground entry route remain unsupported. Late joining, renaming and
authenticated disconnect mutation are not added. Once enabled, late hello is
rejected before validation or presence. An authenticated duplicate receives no
false welcome and cannot enter the old rejection/disconnect completion. Losing
an authenticated connection fails closed without a new save. The existing
90-second technical-entry timeout remains; this is not a general long-running
production server.

## FIFO and physical phase

The FIFO holds only not-yet-admitted input. It reuses Frame's limits: 64 envelopes,
4,096 bytes per stored event and 65,536 total bytes, including trusted binding
metadata. Primitive command validation precedes copying; stored requests are
detached. The owner captures identity from the confirmed fixed roster and checks
the actual peer map, input generation, transport incarnation and source lease
without projecting tentative actor records. Frame's existing envelope validation
and full dynamic/native checks remain in use. The queue is checked again before
confirmation, saving or publication.

Enqueue returns `queued=true`, `ok=false`, `accepted=false`, `confirmed=false`.
It cannot advance a public cursor. Sequence admission occurs only inside Frame's
ordered submit; the public accepted sequence appears only with its confirmed
snapshot. It still describes admitted input, not successful F or a count of
simulation ticks. The existing wire schema is unchanged. RPC does not gain an
input receipt or interaction-success reply.

Each actual physics callback, once per frame, does the following:

1. Recheck owner, roster, source and queued bindings
2. Confirm the previous native/model ticket at the later physics boundary
3. If automatic saving is due, complete its actual exact save and deadline update
4. Refresh the confirmed cache and publish at the existing snapshot cadence
5. Submit the bounded FIFO and exactly this callback's delta, then retain its ticket

No old Controller step or separate Authority advance runs here. A paused entry
does not accumulate delta. The first enabled tick uses only its current callback
delta. A duplicate callback cannot tick twice. Failed ordinary F remains consumed
and still receives that frame's normal tick; held F is not retried. Multiple
release/fresh-press pairs remain ordered, with no added per-frame F limit or
cooldown. Native transfer, destination CCD and movement continue to use the
existing same-frame transaction and later two-RID confirmation.

The source rules and distinctions recorded in
`011_NATURAL_TRANSFER_CANDIDATE.md` and `011_ACTOR_FRAME_TRANSACTION.md` still
apply: same-layer pointing/range, shared XY, preserved off-center actor XY as the
explicit conservative landing choice, blocked/unknown rejection, no snap, and
no new moving, dodging or control ban. Summon/beacon migration remains a later
formal dependency. The finite adapter's existing certification flags are unchanged.

## Stop, fatal results and storage

A stop request records a serial cutoff and rejects subsequent input. The physics
owner first confirms any outstanding frame, then consumes all queued input up to
that cutoff in order with one current callback delta. The next confirmation must
succeed before an exact `normal_shutdown` save and close. It does not discard a
queued release or F, save a half-frame, retry a failed delta, or run a spare tick
once the cutoff is drained. `_process` only latches this request; it does not
advance time or automatic deadlines.

Queue exhaustion is terminal because this RPC has no delivery/admission reply
that could safely repair a dropped release. Stale service/roster/native proof,
unprovable submission/confirmation and failed actual saves are also terminal.
The internal phase method returns a sticky fatal outcome with no retry; the
real physics or RPC caller immediately invokes the existing fatal cleanup/quit.
Every owner publication/save preview/write gate remains closed even during the
short interval before that dispatch. Confirmed read-only cache access while a
healthy frame is pending never exposes the tentative model.

The shared owner save helper calls Frame's actual SaveStore path itself. It does
not accept external acknowledgments. If main commits but backup fails, receipt
and deadline preserve that durable fact, then publication and continuation stop.
No claim of main rollback or unwritten bytes is made.

## Verification boundary

`ActorLiveInputOwnerTest.gd` contains eight finite methods using exact Owner,
real native bodies, the same initial/bootstrap Frame and actual temporary
SaveStore. Successful detached-owner bootstrap/phase calls are not real ENet
sender or process-exit evidence. Terminal tests inspect the same internal phase
outcomes and real I/O; they do not override production quit or pretend that
inspecting an outcome executed the outer fatal handler. Separate parent-owned
real-transport/terminal probes and a moving/F workload benchmark remain required
for those claims. The planned 1/4-actor moving/F benchmark must identify queue
workload, confirmation/submission timing and RSS; no 60-Hz claim follows from
source review or the previous idle benchmark.
