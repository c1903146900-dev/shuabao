# Isolated G10 + G16 presentation combination

Baseline remains 4112ebb636b77732788de4ed57d3d75f4dae67b488c9e76c063b8061a2e37c93. This combines G10 feedback03 (b8dee1aa) and corrected G16 view02 (ffc52763), not G28, dash-attack-pitch or warning experiments. Independent output PCK: 338124f7d307554893962383c8bd802f14afd188db2bde9b63c730514d1e7119, 259 authenticated bindings.

Only presentation.gd and two visual helper files differ from baseline, aside from manifest/generation resealing. Each helper is byte-identical to its independently tested candidate. Shared scope/death cleanup lines retain both helpers. All existing function declarations remain exact. No damage, cooldown, targeting, input, growth or guard changes.

Apply presentation.patch with zero-context support to baseline, add the two files under changes/, and reseal with the previously public recovery tool. SOURCE_HASHES verifies inputs/outputs. No private assets, binaries, raw logs or user data are included. The original failed local composition draft was retained separately; its duplicate-line uniqueness assertion stopped before producing a sealed pack. This checkpoint contains the corrected deterministic combination, not that draft.

## Verification
12 offline checks passed: exact declaration preservation, both helpers' exact source bytes, shared cleanup, rendering placement, restricted changed-file scope, 259 bindings and generation pin. An initial test assertion incorrectly expected a missile-specific owner-invalid clear hook not present in the original G16 candidate. Corrected that test to assert the actual shared owner-invalid presentation-hide behavior; production code was not changed to satisfy an invented requirement.

One guarded engine launch completed with exit 0 in 17.892180 seconds, max sampling gap 0.061295 seconds, complete owned-process cleanup. Established guard SHA256 5febee5aee051af45740ca8f20b9a00c44bda9b45fd35633caf0d8943941600a was unchanged. Existing historical status label REIMPLEMENTATION_NOT_PRIOR_GUARD is not a claim of historical original identity. Limits unchanged: 0.05 s interval / 0.2 s maximum gap / 1536 MiB RSS+swap / 2048 MiB minimum available / cleanup 595 s / kill request 600 s. A preceding shell command had a wrong relative path and exited 127 without invoking the guard or engine; corrected to the existing absolute command path, not a guard retry.

Within this combined pack, all 20 existing G10 source/lifecycle fixture checks and all 14 G16 fixture checks passed. Their historical NOT_RUN/UNRUN labels predate this invocation. G10 fixture includes explicit selection, lethal-damage packet and source-expiry fixtures, not natural acquisition. Both fixtures use independent sessions, not simultaneous event overlap.

The subsequent actual scene explicitly selected both G10/G16, positioned the hero inside unchanged Q1 reach and disabled enemy AI. Q1 was learned through initial-point UI and cast through scripted input. It dealt 73 damage and generated two actual G16 source missiles; each committed 22.56 damage to a different enemy. Final source and missile display counts were zero. G10's renderer remained present with zero live souls and zero pickup flashes in this scene. Normal-camera advanced frame visibly shows the cyan/gold missile close below the hero; no new visual-quality improvement is claimed.

## Limits
No natural G10 acquisition or actual soul pickup was exercised in the combined gameplay scene; the G10 pickup/lifecycle coverage above is fixture-only. Simultaneous soul pickup with live missiles, crowded overlap, full first floor, Windows, actual audio and native player-control quality remain unverified. This remains an isolated short-tested candidate, not the selected delivery baseline or a complete playable acceptance.

Public tests/observe.gd differs from the executed observer only by screenshot destination changed to user://. This adapted copy was not rerun; both fixture files are exact executed bytes. These observers require the existing authenticated test project and established guard, not an independent engine launcher. Do not weaken runtime protections to reproduce them.
