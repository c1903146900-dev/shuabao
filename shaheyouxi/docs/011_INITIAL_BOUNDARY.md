# 011 one-shot initial confirmation and actual save-root binding

Status: the first native method ran and failed two baseline assertions. The
test-only comparator correction below awaits rerun; the other seven methods
remain unrun. No native pass or live-owner acceptance is claimed.
The preceding frozen-source correctness rerun and benchmark remain unrun after
resource admission refused to start any engine. This slice adds no RPC/owner
scheduling, gameplay tick, save I/O, actor activation or transport.

## Purpose and exact boundary

The inherited owner saves a fresh world before its local-host join. At that point
there are no active actors, but the Frame core previously had neither a confirmed
cache nor a supported empty-actor submission. Its ordinary submit cannot stand in
for startup confirmation: that would introduce a gameplay delta and still reject
the empty activity set.

Frame.prepare_initial_boundary(owner = null) now captures one fully validated
initial boundary. It is permitted only before any submitted native frame or
existing lineage, with no pending frame, active authority peer, active model actor
or native actor. Restored inactive profiles and actor records remain valid and
receive all existing dynamic schema, resource, layer and fallback checks. The
inactive-only restriction describes this bootstrap API, not an input/action ban.

Preparation returns ok=false, pending=true, prepared=true, initial_boundary=true,
save_ready=false and delta_consumed=false. Its opaque ticket has owner_id,
generation and kind=initial_boundary. Ordinary two-field frame tickets cannot be
used to confirm/cancel it, and this ticket cannot confirm an ordinary frame.

confirm_initial_boundary requires a later actual physics frame and exact equality
with the prepared full boundary, including native generations/bindings and the
source lease. Only then does it establish the existing Frame lineage, public cache
and base save cache. It does not admit input, tick, advance either clock, change a
model revision/input generation or write a native body. Same-frame confirmation,
ordinary submit and public/save access remain explicitly pending. The initial
last-confirmed snapshot is empty until confirmation, never a tentative baseline.

A matching cancellation releases the lease and permanently closes initialization
on that Frame. It does not dispose caller-owned services because no model/native
write occurred. The caller still performs normal cleanup. Bad preparation is also
one-shot; retry cannot attach another owner, recapture mutated state or remint a
lease. A changed prepared or confirmed boundary is fatal, with no delta retry and
the existing runtime cleanup path. Duplicate/foreign/wrong-kind tickets reject
without replacing the valid outstanding ticket.

## Bind the real schema4 owner's actual persistence root

SourceLease.prepare accepts an optional save_owner Object. It must be the actual
Node using res://scripts/actor/actor_terrain_network_main.gd, identified through
its already-loaded exact script path and then captured script object. There is no
preload/import of that owner from Lease, avoiding the future owner→Frame→Lease
cycle. A similarly shaped arbitrary Object/Node is not a persistence owner.

The owner must refer to the exact bound authority, World, Motion, native Space,
ActorInputs and TerrainStore through its real _authority, _world, _actor_model,
_actor_space, _actor_inputs and _terrain_store fields. Each guard rechecks those
references. Owner lifetime is a WeakRef; a freed/queued-for-deletion owner, script
change or service replacement invalidates the lease permanently.

The owner currently keeps _terrain_component separately from Space._terrain.
Both actual roots are graph-preflighted before any freeze. The existing complete
runtime-source validation runs, the actual owner terrain must compare exactly to
runtime terrain, and Store.restore fully validates that actual persistence root
against the same World. Only after all configuration/dynamic/native checks pass
are both roots recursively made readonly along with the existing roots. Bad owner
bindings, malformed/mismatched terrain and failed validation leave every previously
mutable source root mutable. No caller-injected getter or detached public copy
stands in for the owner's actual field.

The hot guard retains both readonly root identities. Replacing either with an
equal copy is still invalid, and restoring an old pointer cannot revive a revoked
lease. This is setup-time full validation plus identity guards, not another
per-frame terrain traversal. Existing no-owner Lease/Frame callers remain valid;
an already-attempted ownerless lease cannot silently acquire an owner later.

## Publication, saving and remaining live integration

The existing Frame public_snapshot and combined_save_state gates use the confirmed
initial lineage just as they use an ordinary confirmed frame. The returned save
object is still the explicitly labeled authority_world_actor_base, with
requires_terrain_wrapper=true. It is not a complete schema4 state. The owner must
combine that base with its bound actual terrain through TerrainSession and retain
the full SaveStore validator at actual I/O. This slice performs no disk write and
does not acknowledge an automatic-save deadline mutation.

No current owner calls these new methods. They are the permanent initial phase of
the same Frame that subsequent presence, input/F, tick and save-ack integration
will use. Host/remote join, disconnect, rename and deadline changes still require
pre-derived lifecycle capabilities; direct Controller mutation after confirmation
correctly fails lineage. Reconstructing Frame or clearing its lineage is not an
integration strategy. Legacy schema3 runtime/owner paths are unchanged.

## Finite validation target

ActorInitialBoundaryTest.gd contains eight grouped native methods covering fresh
and restored inactive baselines; same-frame pending and next-frame confirmation;
prepared/confirmed state corruption; actual owner/native terrain replacement;
bad owner bindings/terrain without partial freeze; ticket isolation/cancellation;
and real Node owner plus service weak lifetimes. Fixtures use the actual schema4
owner without adding it to the scene tree or invoking _ready/network setup, then
free the Node explicitly. Weak service assertions use the single process-frame
stack unwind established by the retained frozen-source diagnostic, never polling
or manual reference-counter manipulation. The preceding Lease8/Frame10 and
separate benchmark retain their own gates; no result is inferred from source.

Source review and 136 Python checks passed before runtime; source/cache preflight
confirmed eight methods and unchanged existing global registration. No engine ran
for this checkpoint. The isolated native8 gate uses192MiB owned RSS,900MiB effective
reserve,192MiB raw floor,45s command and110s total; no import or GUI.

First native attempt `011core_runs_20261006T131213835866Z.json` failed discovery
with warning-as-error Variant inference at test lines410/424, zero methods started.
Engine230045 exit/wait105, reaped, desktop namespace group empty; wrapper230020
exit1, terminal disappeared/CUA reset. Only those two WeakRef declarations now
have explicit types; production and assertions are unchanged. Remaining inferred
locals were checked for the same issue. This correction is not yet engine-tested.
A later file-tool transport interruption was recovered on the same host; final
two-line diff and SHA330645ba… independently read back before protection.

The corrected-source attempt `011core_runs_20261006T132010029033Z.json` was
refused before launch: effective1,116,837,158 < required1,145,044,992 bytes.
Zero engines/methods; wrapper230883 exit2, terminal disappeared/CUAreset.
The type correction remains unverified by engine. No threshold or automatic retry.

At14:04:41 UTC one authorized read-only desktop namespace sample still showed
effective1,114,352,582 bytes below1,145,044,992 required. Initial8 was not
launched; measurement terminal disappeared/CUAreset. Source remains unchanged,
no cache action or repeated admission attempt was taken.

The14:07 desktop namespace diagnostic found no active Godot/Blender; the only live
terminal was the diagnostic itself, later closed. Historical Z-state entries had
zero RSS; no process or shared cache was altered. Top15 sanitized command labels,
parent/child relations and cgroup categories are retained in the diagnostic JSON.
A70-file completed/backed archive whitelist was separately authorized. All inode/
size/mtime metadata matched and no visible FD reader matched, but874 process FD
directories were inaccessible in the desktop namespace. The fail-closed script
therefore issued zero POSIX_FADV_DONTNEED calls. No files were changed or deleted.
The subsequent independent14:21:39 sample still had effective1,118,572,438 bytes
below1,145,044,992 required; Initial8 was not launched. Terminal closed/CUAreset;
no repeated gate attempt or expanded archive scope followed.

## Native baseline comparator correction

The retained gate `011core_runs_20261006T143204476445Z.json` discovered the suite
and ran its first method. Its log `011core_actor_core_20261006T143204476445Z.log`
records two failures at _assert_unchanged; the remaining seven methods did not
start. This does not establish a production state mutation, nor establish that
production was unchanged: the selected comparison oracle cannot compare its own
native baseline successfully.

TerrainStore._same deliberately accepts JSON-like data only. The test's complete
baseline also contains RID values in native spaces, body and shape arrays. With
active actors its input move/aim and native actor position additionally contain
Vector2 values. Store therefore returns false for even an identical native
baseline. Production Store and Frame are unchanged by this correction.

The test-only _same_baseline now recursively compares every original field and
String key, exact key sets, array lengths/order and Variant types. Finite scalar
floats use eight-byte binary64 comparisons; Vector2 compares both components by
the same exact-bit check; RID leaves compare their handle values. Only null,
bool, int and String are the other accepted leaves. Unknown types fail rather
than taking a permissive generic equality branch. No field/RID/array is removed
from _baseline, and the original pre/post full-state assertions remain.

The first method also checks baseline self-equality and rejection after replacing
one copied space RID with a newly allocated distinct RID, without changing live
state. That temporary RID is freed before assertions report. Small pure-value
checks cover float-vs-int, signed-zero bits, Vector2 components, array order,
different key sets and unknown-type rejection. These additions stay within the
existing eight methods. The original red log is preserved; no corrected native
result is claimed before a separate authorized rerun.

Archive maintenance authorization was confirmed before a single successful retry.
The70 matched backed files received nonbinding POSIX_FADV_DONTNEED; mincore
resident sum72,916,992→0 bytes. No visible reader matched,890 inaccessible FD
directories were disclosed, not claimed absent. No file content/deletion action.
After reset, the independent14:31 sample had effective1,180,719,356 bytes,
above the unchanged1,145,044,992 gate. The ensuing native first-method red
exited/waited100, reaped with same-namespace group empty; wrapper237924 exit1,
terminal disappeared/CUAreset. Peak132,034,560 bytes,2.882s outer.
Comparator source review/preflight and89 runner/callback Python checks passed;
corrected Initial8 remains unrun.

Corrected native8 passed in `011core_runs_20261006T144030363106Z.json`:8 methods,
zero errors/failures/skips/orphans/script warnings;20.464s test and21.748s outer.
The full typed baseline assertions passed before/after confirmation, with the
independent different-RID negative retained. Engine239083 exit/wait0, reaped,
desktop namespace group empty; wrapper239040 exit0, terminal closed/CUAreset.
Peak132,603,904 bytes. The earlier discovery/runtime reds remain unchanged.
Affected existing Lease8/Frame10 regression is pending for this initial API delta;
owner live integration and moving/F/network performance remain unverified.

Affected existing Lease8→Frame10 passed in `011core_runs_20261006T144529471312Z.json`:18
methods, zero errors/failures/skips/orphans/script warnings,21.721+12.397s tests
and36.702s outer. Both leaders exited0/reaped with desktop namespace groups empty;
peaks121,061,376/128,180,224 bytes, wrapper239596 exit0, terminal closed/CUAreset.
The launcher initially retained the correctly typed command without activating
on Return; a fresh visible Launch button then started the sole actual run.
No concurrent duplicate process or extra test retry occurred.
