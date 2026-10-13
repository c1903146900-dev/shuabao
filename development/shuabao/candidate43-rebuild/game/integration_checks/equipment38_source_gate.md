# Equipment38 / B04 source gate

Prepared against candidate09 on 2026-10-09. The parent ran the frozen source gate in two serial engine processes: first1050/1050 and second1392/1392 assertions passed, covering all six groups with2442 assertions total. The author did not launch an engine or GUI; the parent owns all engine execution. Native GUI validation remains unperformed.

## Entry and execution

Run from the sealed candidate09 project with the parent's existing Godot binary, serially with other engine work:

```sh
godot --headless --path /workspace/scratch/73ebae91a474/loot_resume_1115/candidate09 --script res://integration_checks/equipment38_source_gate.gd -- --equipment-result=/tmp/equipment38_source_gate.json
```

The default JSON includes every assertion, six required groups, original command receipts, completion observations, input records, source fixture disclosures, and the live binding SHA. Exit 0 requires every selected group and no failed assertions. Exit 1 indicates assertion failures; exit 2 indicates result-writing failure. An engine parse failure is not a source-test execution.

For the parent's60-second per-process guard, run the same frozen file in two serial partitions. Each report declares its exact three required groups; the union must equal all six:

```sh
godot --headless --path /workspace/scratch/73ebae91a474/loot_resume_1115/candidate09 --script res://integration_checks/equipment38_source_gate.gd -- --equipment-groups=first --equipment-result=/tmp/equipment38_first.json
godot --headless --path /workspace/scratch/73ebae91a474/loot_resume_1115/candidate09 --script res://integration_checks/equipment38_source_gate.gd -- --equipment-groups=second --equipment-result=/tmp/equipment38_second.json
```

The parent ran the original source01 file (SHA651f1b13992e4b62df7a4e0ea6c223c4a0efec6c33689f63e92b6db46d5108b9): parsing passed;1934 assertions completed with four failures, not a pass. Its byte-exact script is retained as equipment38_source_gate.before_fixture_fix01.gd and its red report remains outside the candidate. The fixture correction limits R/Shift baseline comparisons to the same real generation/room; original rest_service.gd clears all cooldowns, so the old row2 baseline must not be projected through rest into row7. A separate assertion checks rest clears Q/E/R/Shift while retaining B04 remainder3. Birth setup retains an original minion instead of chasing a retreating ranged actor, uses a distance inside that actor's original contact radius, and records actual start/end positions, distance, state and reachability. These changes do not modify production code or remove completion assertions.

The corrected frozen GDScript SHA is6318a62052c4ff7abb710d7df41539fc808b25beceb1926f87a0c696e73ffc7e. Verified parent execution records, relative to loot_resume_1115:

- equipment38_source01.json: preserved initial red report,1934 assertions,4 failures.
- equipment38_source02_first.json: passed=true,1050 assertions,0 failures, exact first three groups.
- equipment38_source02_second.json: passed=true,1392 assertions,0 failures, exact last three groups.
- checks/equipment38_source02_first/exit.json: exit0,38.16seconds,340770816-byte sampled peak RSS, full owned-process cleanup confirmed.
- checks/equipment38_source02_second/exit.json: exit0,38.48seconds,340832256-byte sampled peak RSS, full owned-process cleanup confirmed.

The second report includes both final-enemy variants: travel completion observes transaction_active=false, and actual birth contact observes transaction_active=true. The birth fixture reached0.294645m from an original minion with0.46m collision radius, through WASD only. All three postcompletion observer actions (cancel, close, death), original route/shop lifecycle, and the isolated common-finish cases were executed. This is source-contract acceptance only.

## Ownership and source path

The entry extends equipment37_source_gate.gd and retains the inherited fresh() body: original Host factories, exact Sim and Session scripts, original navigation admission, router suspension owner, initial milestones, original Lv1 wallet/XP/SP, original Bridge, clock and Boss Director, all seven owner assertions, and refusal to initialize another run on the same Session. The only identity extension is the complete Model chain:

B04 → G06 → B01 → distance → equipment expansion → postboss → frozen content01 Model, including the original Model SHA assertion.

funded_shop retains G06/B01 observer fixture keys for the parent's separate inherited-regression wrapper. This entry does not claim to execute every prior equipment gate.

Positive B04 completions come from a normal router LMB down/up pair, then request_action → original start_basic → original solver → original _retire_motion/finish_cast → original ink_basic_finished. It never emits a public event to manufacture a positive completion. Observer assertions use the original Model command receipt and read both Q/E values before the inherited Session observes the event. Per-cast state references are retained only for a negative repeated-retirement probe.

## Six executable groups

1. Original38 definitions and commerce: unchanged prior37 entries; B04 price3000, AD42, CDR18%, crit15%; passive08 only; original I13+I11 craft fee550; buy/sell/craft/undo; two-copy base attributes and one passive; I13/I11 attribute-only; public Model command rejected.
2. Real cycles and replays: actual empty path_end completions1–11; two B04 copies count once; different current Q/E values each ×0.9 on fifth; zero Q/E on tenth still consumes the group; eleventh cannot use a banked refund; original R/Shift/basic cadence unchanged; public event copies, generic finish replay and repeated original retired state cannot add a claim; unequipped real completion does not count.
3. Cancellation and nonbasic boundaries: three authentic completions followed by an unfinished real basic; original cancel_cast, Session close/clear, and true death suppress its claim; another actual cast can proceed after cancellation; a fresh original Host/Session/Model after death starts at zero; actual Q1 mouse release at the hero's position finishes without B04 progress.
4. Authored-wall completion, final-enemy ordering and observer invalidation: WASD approaches the original room obstacle, and the actual solver produces an empty blocked fifth completion; final original roster enemy is killed by an actual basic, both in travel and overlap-at-birth variants; kill < ink_basic_finished < encounter_finished(victory); birth observer still sees transaction_active=true; both current CDs and remainder are committed before observers and preserved in the victory snapshot. Cancel, close or true death in the original completion observer keeps the legitimate commit and suppresses its stale diagnostic.
5. Approved lifecycle on the original route: row1 three completions plus row2 two trigger once; another remainder3 survives original service and shop; sell-one and sale undo retain it; sell-last freezes it through three real unequipped completions; original route continues to a later shop, repurchase resumes and two more real completions trigger. No added enemies obstruct route or terminal settlement. Original roster-wide kill receipts remain mandatory.
6. Isolated common-finish boundary fixtures: an explicitly separate Sim subclass and common wrapper execute the full inherited common.complete_action and finish_cast chain, then inject a callback while finish_returned remains false. A matching public completion cannot borrow that frame. Original cancellation, end_encounter, real begin_encounter replacement, and source true death invalidate it. A plain and blocked natural source completion each retain one valid terminal witness.

## Explicit fixtures and limits

- The sole direct wallet assignment is60000 test gold, matching prior source gates. No test assigns HP, cooldown fields, remainder, tasks, rank, AI flags, hero position, inventory, room identity, or progression rewards.
- Nonzero and zero cooldown setups call original start_skill_cooldown and disclose base/current values. These are not actual Q/E casts.
- Route setup and advancement use explicitly labelled source damage against only the entered roster. The final-enemy tests first reduce the original enemy through source damage, then use the actual basic as the lethal blow. This is not a natural-play or balance test.
- Movement uses the original router's WASD API. No teleport or extra Host enemy is used.
- Common callback fixtures are deliberately not original Host/Session cases and bind no Model. They assert source-witness eligibility/invalidation, not a pretend Model counter. Their fixture-only common wrapper and blocked geometry are disclosed separately in JSON.
- Nested real completions, Q2 river enhancement, pause-inside-common and native GUI input are not covered by this entry. No false coverage claim is made for them.
- Engine acceptance above was executed by the parent and independently read from both JSON reports and guard records by this worker. No native GUI validation was performed. Source-contract acceptance does not establish native GUI acceptance, full-floor natural play or production readiness.
