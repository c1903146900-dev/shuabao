# 011 legacy asynchronous composition-seam regression

Status: source authored, engine gate unrun. Production files are unchanged by
this addition. The intended first legacy-compatibility gate contains the existing
ActorOwnerSeamsTest 17 methods, ActorNetworkOwnerTest 40 methods and the new
ActorLegacyAsyncSeamsTest four methods, for 61 total.

The four directed checks exercise the existing base owner's actual methods:

1. Its default _join_authority_peer_async delegates to the old synchronous join
   with the exact supplied peer/request and server-owned local_host argument,
   preserves success and rejection values, and does not yield a physics/process
   frame. A similarly named request field does not become a trusted argument.
2. Its _handle_remote_hello retains the explicitly supplied captured sender across
   a real SceneTree.physics_frame await in the join override, and forwards the
   validated request and result to that same sender's completion seam.
3. Validator rejection never invokes either join path and completes with the exact
   rejection, without a physics wait.
4. Closing is set by a one-shot real physics signal while the hello handler is
   awaiting join. The closing check suppresses completion and any sync/broadcast
   calls even when the join override returns a success-shaped result.

The Probe overrides _ready so it does not parse process arguments or allocate a
transport. Validation/join/completion observations contain only synthetic marker
values and fixture peer numbers; no identity, resume proof or real RPC sender is
fabricated. Completion is observed rather than executing welcome.rpc_id. Sync and
broadcast overrides are tripwires, not evidence of successful packet publication.
Request/result expectations are detached before invoking the tested methods, so
an in-place mutation cannot also alter the oracle and make the assertion pass.
This is a composition-seam test, not ENet/authentication or old-schema3 host
end-to-end verification; the latter remains a separate planned gate.

There are no World/Stage/Space or SaveStore fixtures in the new four methods and
only two actual physics waits. The expected test body is below one second, with
engine/test-framework startup additional; this is an estimate, not a measured
result. The existing 57 tests retain their own actual work and assertions. No
native or software run is performed during this source-only preparation.

Source gate: final detached-oracle fixture passed independent review;191 combined
Python checks and source/cache preflight passed in1640 evidence. The full61 gate
selects unchanged OwnerSeams17 and NetworkOwner40 plus these4 seam methods,
with192MiB owned RSS/900MiB reserve/192MiB raw floor,45s single command/110s total,
no import or GUI and explicit wait/reaped/empty-group verification. Runtime unrun
at this checkpoint. Real legacy host and shared Frame26 remain later gates.

The first61 attempt `011core_runs_20261006T164436111029Z.json` was refused
before launching any engine: v2 effective1,081,586,230 <required1,145,044,992
bytes. Zero methods/processes ran; wrapper253470 exit2, terminal disappeared/
CUAreset. The61, real schema3 host and shared Frame26 remain unrun on this
changed source. No resource threshold change or repeated attempt followed.
