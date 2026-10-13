# Native inventory continuation and isolated item gate

Source plan, 2026-10-08. No result is implied by a prepared step.

## Ordinary empty-world Continue

Use a full15-file hash-matched copy of pair01's actual ready3 checkpoint in a fresh isolated HOME. Native Continue, I open, verify same world/profile/instance and empty40+10 inventory, Escape, F10, actual saved receipt/menu, Exit. The rejected transport sequence1 from the previous connection must not be replayed: saved accepted0 remains the new connection's initial cursor. The original checkpoint remains untouched.

## Explicit offline item fixture

Parent approved an offline developer fixture, separate from ordinary acquisition. `InventoryOfflineFixture012Test.gd` accepts only its exact isolated HOME and expected ready3 slot/world/main SHA. The whole15-file source checkpoint is copied and hash-checked before preparation. Only the clone gets731+268 wood and a unique gun (item_fixture_gun/protected_fixture_gun; opaque magazine3/negative-zero bits). Carry starts empty. The profile and slot label explicitly identify an offline inventory fixture.

The actual schema5 Store validates and writes main sequence4 with reason inventory_fixture, then cold readback verifies exact state. Only after that readback does the fixture's actual index advance3→4. No session ticket, process exit, normal_shutdown reason, or F10 receipt is fabricated. The production new5 initialization is unchanged and empty. Preparation is not a gameplay or native-interaction pass.

## Native item actions

From a separate full copy of successfully prepared fixture4:

1. Native Continue, confirm labelled fixture, inventory revision2 and initial accepted0.
2. Click bag slot2 (268 wood) then slot1 (731 wood): authoritative take then merge999.
3. Click bag slot3 (unique gun). F10 while carry is nonempty must only show the temporary “请先放回手中物品再保存退出” message; no return/drop policy or shutdown is chosen.
4. Place the gun into hotbar slot1.
5. Take999 wood from bag slot1 and place into bag slot4.
6. Verify total wood999, exactly one same gun/protected ID, opaque state retained, carry empty, six accepted actions, no pending/duplicates.
7. F10 → independently verified combined save and both cutoffs → saved menu → Exit.
8. Cold native Continue from a full clean checkpoint copy, verify the exact bag/hotbar/instance/cursor state, then normal F10/Exit. Reopening must not restore the earlier fixture source or replay old unresolved input.

Expected numeric revisions/cursors are assertions to check against actual evidence, not claims of a run. The actual receiver/Frame remains authoritative. No Q, half-return, world-drop merge or unresolved disconnect-carry choice is exercised. No natural harvesting or ordinary item acquisition is claimed. Windows5 generation and playable packaging remain separate gates.

## Actual partial results, 04:42 UTC

Ordinary empty-world Continue passed natively: same world/profile/instance, empty inventory retained, new connection initial/issued/processed/accepted0 (the prior rejected transport1 is not replayed), normal F10 main sequence5, dual-stream empty proof, saved menu and Exit.123.695s/814305280B/exit0/guard green/full cleanup. A24-file private ready5 checkpoint is local only.

Offline fixture preparation produced actual validated main4 with reason inventory_fixture and index4, verified original15 source files unchanged and no locks remaining. All data assertions passed, but the suite ended red(exit101) with2orphans because resource cleanup was in suite after rather than after_test.33.811s/437047296B/full process cleanup. Failed receipt is retained. Cleanup timing is fixed in source; a separate16-file full fixture clone and two-case lifecycle/read-only verification are prepared but unrun. Neither preparation nor read-only verification is native item-interaction acceptance.

## Actual item and recovery results, 2026-10-08 06:00 UTC

The lifecycle/read-only fixture verification passed both cases in 5.443 seconds, 296,435,712 bytes, exit 0, no errors, failures, skips or orphans, with complete process cleanup. All 16 existing fixture files were unchanged; no items were granted again.

Native fixture pair03 genuinely completed six authoritative actions: take 268 wood, merge into 731 to make 999, take the unique gun, put it in hotbar slot1, take the 999 wood and place it in bag slot4. All observed states conserve the total and unique ID. The temporary carry-empty F10 message was observed without choosing a return/drop policy. Actor transport actions are separate from these inventory actions.

The server actually committed complete normal_shutdown main6, with inventory cursor6 and revision8 and exact preserved gun state, but the 300-second guard ended the client before receipt/menu completion. Original pair03 remains red: 299.558 seconds, 787,619,840 bytes, deadline cleanup, exit -15. This is not a normal GUI-close pass or an item-grant/acquisition pass.

Recovery01 refused before index publication because its verifier incorrectly expected a public Actor snapshot in the intentionally smaller terminal report. That failure and its exact source hash remain preserved. Recovery02 uses the pinned real pre-stop Actor observation (generation3490, accepted17, revision17290), terminal drained status, real saved Actor revision17295 and matching position bits, full Frame state hash, and directly persisted inventory cursor6. Actor transport cursors are not fields in the current save schema; no disk-cursor claim is made.

Recovery02 passed the real schema5 cold inspection and copied index4 to6 in 5.300 seconds, 294,141,952 bytes, exit 0 and complete cleanup. All 26 original files stayed exact; only the two copied locks were quarantined. No close receipt was fabricated. A clean 24-file ready6 checkpoint and another exact GUI copy are local only. Native cold Continue of this committed item state is still pending. The next explicit pair600 profile retains the original 896 MiB, 50 ms, identity and cleanup rules; 99 Python checks passed and the parent reviewed its two-line registration change.

Plain JSON observation loses signed-zero formatting. Exact negative-zero preservation is checked independently in the before/after saved scalar-bit payloads, not inferred from the diagnostic JSON view.

## Cold item Continue failure and bounded startup investigation (2026-10-08 06:33 UTC)

Pair04 used an unchanged 24-file copy of recovered ready6. It failed before
welcome/first inventory snapshot, last stage presence_save_begin. The client
reported SERVER_DISCONNECTED; coordinator recorded LOCAL_CLIENT_EXIT_NOT_CONFIRMED,
not LOCAL_START_TIMEOUT. Guard was red (leader_exited_with_live_descendant),
68.68844836 seconds / 731897856 bytes, with full process cleanup. This is not an
item cold-Continue or normal F10 pass. Original ready6 and actual commit6 remain.

Prior successful native joins spent 5.549064, 6.765058, and 6.584167 seconds in
synchronous save, in addition to 1.2–1.55 seconds confirmation. Exact Godot 4.6.3
bundles ENet adaptive reliable-ACK timeout defaults factor32/min5000/max30000.
A single-engine isolated two-host diagnostic, without world/save data, stalled
only server polling for seven seconds. Defaults disconnected at 6.638992 seconds;
startup factor32/min30000/max30000 stayed connected and received resumed after
7.001009 seconds. The 22.587679094-second / 74272768-byte run passed and joined
both threads, destroyed both hosts, and fully cleaned up. This proves that the
mechanism can explain the failure; historical pair04 did not record a lower-level
wire timeout reason code.

A separate four-source candidate narrows startup allowance to exactly owned
local sessions. Load and join have independent fixed 30-second monotonic budgets.
Client allowance restores after validated first snapshot. Server allowance
restores after first same-generation confirmed accepted Actor cursor, or fixed
30-second expiry without disconnecting an already joined idle player. Successfully
prepared owned handshake uses the same fixed deadline; other peers retain the
legacy five-second reaper. Disconnect/epoch/incarnation transitions clear captured
state without mutating a replacement. Synchronous confirmation/save/activation
and final welcome boundaries recheck deadline; a completed commit remains real
if the later startup publication is refused. No success welcome precedes commit.

Four-file independent source review passed (server SHA61aceac250d5c2474839434daac4570c019db82f006a4a229f21655fb971ac83).
Eight Python source-order checks and five GDScript grammar parses passed. Sixteen
Godot tests and the real ready6 Continue/F10 remain pending at this checkpoint.
Connected-peer tests exercise native set_timeout calls and connection survival,
not a native getter for timeout values. Long synchronous save/activation crossing
the deadline is source-guarded, not yet a real fault-injected runtime result.

## Actual cold item Continue and complete normal shutdown, pair05

Startup16 ran in the isolated dependency-pinned project: all16 passed, zero errors,
failures/skips/orphans, 2.091434239 seconds / 174489600 bytes, exit0 and full cleanup.
The independently reviewed four files were then applied at their exact hashes.

Pair05 resumed another exact24-file ready6 clone. Actual native I showed bag slot4
wood999 and hotbar slot1 unique gun; carry empty. New connection generation17296,
inventory initial/issued/processed/accepted all6, revision8: no previous action
was replayed or granted again. Native Escape/F10 returned to menu “世界已保存”,
then native Exit. Guard passed117.641721869 seconds / 815345664 bytes, exit0 and
full cleanup. Combined main8 reason normal_shutdown has SHA256
b2c34506e344495c2bc588ed40f12c9ad7427591c03510e82b9ea9dabe16178e.
Actual receipt covered Actor cutoff/accepted1 and inventory initial/cutoff/
processed/saved6 revision8, queue empty, child exit0, writer released, complete
main committed. Independent readonly checker passed actual envelope hashes,
identity, all cutoffs, menu completion, quantity/instance conservation and carry
empty. Persisted gun signed-zero bits remain0000000000000080, protected ID and
magazine3 unchanged. New ready8 full33-file private checkpoint has no locks;
original ready6's24 hashes unchanged. Screenshots show inventory and saved menu.

This completes technical-fixture native actions→actual save→cold reconnect→
normal save/menu/Exit, while preserving pair03 timeout and pair04 join failure as
failed historical runs. It is not natural acquisition or Windows runtime proof.

## Committed-save late-return fault (isolated injected copy)

After pair05, a separate complete project copy injected an expired monotonic
admission deadline immediately after actual successful bootstrap_join save.
Only copied base quit was changed to capture exit1 rather than terminate GdUnit;
real failure Store/peer close and runtime cleanup remained. Source comparison
confirmed exactly two injected production-shaped files and one added test.
One test passed, zero errors/failures/skips/orphans, 27.599733965 seconds /
394637312 bytes, exit0 and guard full cleanup. Actual main2 remained committed,
LOCAL_JOIN_TIMEOUT returned, input never enabled, welcome count zero, fresh
real Store acquired and cold-read2 with identical committed bytes. This is
explicit host logical fault injection; no production source changed and no real
30-second blocking/network-failure claim is made.
