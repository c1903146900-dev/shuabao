# G16 corrected integration: limited runtime evidence

Candidate runtime.pck SHA256: ffc527630e612199cc0553dcd305626cd67074110207ea8cfed4e867ab1f2261 (258 bindings). Independent from passed 4112ebb6, not merged with other candidates.

## Preserved failures
1. Original candidate: malformed existing function declaration caused authenticated bootstrap parse failure. Exit 4, no gameplay evidence. Fixed exact declaration; new regression assertion compares every existing function signature with baseline. Original checkpoint remains history.
2. Corrected candidate first trigger attempt: Q1 positioned 5 metres away missed its existing 3.5 metre length. Source-array fixture passed, but no source missiles; observer intentionally exited 3. This was a test setup failure, not guard interruption or a claimed gameplay pass.
3. Final attempt placed the hero within existing Q1 reach using the template value, without changing attack range. It passed.

## Actual final coverage
Normal initial-point UI learned Q1. Explicit fixture selected G16, positioned the hero and disabled enemy AI. Scripted input cast Q1, causing real 73 damage and source generation of two G16 missiles. Existing projectile logic moved those entities and committed two 22.56 damage events on different enemies. Source and display counts were zero after settlement. Two in-flight states and the final settled state were captured at normal game-camera scale.

Image inspection: the advanced frame visibly shows a small cyan/gold bolt in the space between hero and lower enemy. At initial emission the bolt is difficult to distinguish amid hero/attack overlap. The final image has no lingering bolt. This proves the missing source entity is now drawn, not polished readability or user aesthetic acceptance. No screenshots/assets/raw logs are included in this public checkpoint.

The separate source-array fixture passed all 14 checks: authenticated session/encounter; live read; no source/damage mutation; paused resampling; actual source movement and actual target; G11 exclusion; invalid source/expiry/dead target; hero death; source removal; room end. These synthetic state checks are not all naturally reached gameplay transitions. Offline source checks passed 36, including exact function signatures.

## Guard evidence
The established guard was unchanged during all three runs. Its historical status label REIMPLEMENTATION_NOT_PRIOR_GUARD is retained and does not prove identity with an earlier implementation. SHA256 5febee5aee051af45740ca8f20b9a00c44bda9b45fd35633caf0d8943941600a. Limits unchanged: 0.05 s sampling, 0.2 s maximum gap, 1536 MiB RSS+swap, 2048 MiB minimum available, cleanup 595 s / kill request 600 s.

- short01: exit 4, elapsed 1.584997 s, max gap 0.057045 s; guard reason ''; complete cleanup True.

- short02: exit 3, elapsed 17.096829 s, max gap 0.129786 s; guard reason ''; complete cleanup True.

- short03: exit 0, elapsed 17.953281 s, max gap 0.167208 s; guard reason ''; complete cleanup True.

## Recovery / test limits
Public observe_trigger.gd differs from the executed observer only in its opening description, screenshot destination (user://) and fixture resource name (observe_missiles.gd). That portable copy has not been rerun. The fixture bytes are unchanged. The observer requires an existing authorized authenticated project and unchanged established guard; it is not a standalone launcher. No full-floor regression or Windows test was performed. Do not call this a completed playable delivery or merge it solely on these results.
