# Q3 mirrored and lifecycle follow-up

The q3_motion01 pack remains unchanged. The last fully completed floor candidate remains e1_motion01.

## Mirror
Normal-input Q3 capture facing +1 passed: 12 Q3 samples span hero age 0.00-0.38. Inspected the opposite-facing sword sweep. Guard exit 0, wall 24.462581 s, max sampling gap 0.096215 s, peak RSS+swap 607305728 bytes; all owned processes cleaned up.

## Actual cancellation rules and checks
Source review: Q3 locks actions until its contact plus commitment interval. Shift does not bypass this Q3 lock; its ordinary cancellation path only cancels pending non-dash basic attacks. Q3 has no general player-requested combat cancel through Shift. The existing scene lifecycle and death invalidate casts, and the presentation's cast-current check clears stale Q3 poses.

Exercised the actual menu flow, not direct simulation mutation: pause to menu, request a fresh run, confirm ending the old run. Before release, at age 0.04, the old cast was current with 1 pending effect and 0 waves. After confirmed host closure, cast no longer current, pending empty, waves empty, animation empty. New run had a different run ID and no stale Q3 state. Exit 0, wall 12.774317 s, max gap 0.068821 s, peak 408088576 bytes.

Repeated after release at age 0.18: old cast current with 1 active wave and 0 pending effects. Confirmed closure cleared the cast, wave and pose; fresh run clean. Exit 0, wall 13.592595 s, max gap 0.057212 s, peak 405782528 bytes. Both guard runs passed and all owned processes cleaned up. These are genuine lifecycle-cancellation checks, not proof of a combat-cancel feature or death-path test.

## Full-floor blocker retained
With Q3 and E1 learned through normal UI, the full-floor attempt reached node 9, then the guard stopped it: sample_gap_untrusted, max gap 0.477562 s exceeding unchanged 0.2 s limit. Previous samples were 0.052429 and 0.050976 s; owned memory remained 407158784 bytes and available memory about 8.22 GB. Wall 162.978530 s, exit -15, all owned processes cleaned up. No script error was seen before termination. This is NOT a completed floor run. Low memory use does not establish the cause of the scheduling gap.

No immediate blind long retry or safety-limit change was made. Keep the candidate separate until a stable guarded full-floor attempt completes. Further skill changes have not been stacked onto this unverified floor candidate. Public source observers are included; private screenshots and raw runtime logs are excluded.

## Later isolated complete-floor attempt
After a fresh 45-second idle precheck (maximum gap 0.171548 seconds, no gap above 0.2), one new run of the unchanged q3_motion01 isolated package was attempted with source Q3 event counting. The guard stopped in the first room at wall 14.045800 seconds: sample_gap_untrusted, maximum gap 0.417499 seconds, peak owned RSS+swap 393162752 bytes. Exit -15; all owned processes cleaned up. No SCRIPT ERROR was reported before termination. This remains a failed/incomplete full-floor attempt, not a pass. Q3 was not merged and protection was unchanged.

Independent work continued instead: the static locomotion-exit candidate was rebased onto the newer Q2/E2/R1 combination in a separate package. It has only structural/hash checks, not runtime acceptance. See combined_exit_review_20261106/README.md. Preserved passing Q2/E2/R1 package is untouched.
