# R1 + Q2/E2 combination regression

The existing r1_motion01 candidate already overlays the previously checked q2_e2_combo01 build. No second merge or mechanics edits were needed. Q3 and the untested locomotion-exit candidate remain excluded. Both older packages are preserved.

## Normal complete floor and UI
- Normal script-assisted combat and UI actions completed all 12 first-floor nodes including the boss. No levels, health, targets, gold or skill state were injected. Simulation elapsed 166.232453 seconds, remaining HP 324.638393, gold 395, nine purchases and four potions used.
- Source event counts: R1 started/finished 3/3; Q2 strike starts/finishes 21/11; E2 spin starts/blinks/finishes 31/10/10. Start counts are not damage-hit counts. The last partial E2 sequence ends with the encounter; this is not evidence of an additional finished spin.
- Guard passed: wall 178.314827 seconds, largest sampling gap 0.102496 seconds, peak owned RSS+swap 407248896 bytes. Exit 0, all owned processes cleaned up.
- Existing 11 key UI checks passed. Guard wall 12.763262 seconds, gap 0.055627 seconds, peak 397746176 bytes, exit 0 and clean cleanup.
- No SCRIPT ERROR in either run. Existing NUL diagnostics remain. These checks are functional regression, not user aesthetic approval or manual/Windows acceptance.

## Damage and interruption rules
Source review confirms that R1 intentionally grants damage/control immunity during its real-time presentation and rejects other actions with ultimate_presentation. Shift must not be described as successful cancellation. The normal complete floor does lose HP outside those intervals and all three R1 casts finish normally. No synthetic damage was injected to manufacture evidence.

Normal finish clears the core presentation, r1_active, clock state, R1 cast state and cast ownership, then emits r1_finished; presentation.gd consumes that event and clears the pose. Encounter shutdown cancels casts and clears pending effects, core presentation, locks and clock; presentation.gd clears its pose on encounter_finished. Runtime menu/new-run cleanup is checked separately below.

## Scope and recovery
Pack SHA256 remains 633da80415771827a17231aee5f60948444b9a789c6cb0735275917434f5b08d. Compared with q2_e2_combo01, only the two presentation source files and generated manifest/seal differ. Preserve q2_e2_combo01 as the older complete-floor version. Mirror, extended modifiers, death during unrelated mandatory health loss, and human gamefeel acceptance are not covered here. No guard settings changed.

## Incomplete lifecycle attempt
The separate natural-leveling/menu-reset observer stopped at wall 5.503671 seconds, before the R1 test point, because the unchanged guard observed a 0.438962-second sample gap. Peak owned RSS+swap was 311275520 bytes. All owned processes were cleaned up. It provides NO runtime immunity/Shift/menu-reset result. No blind retry was made after this scheduling failure. The public observer remains a pending test, not evidence of a pass. Until that gap is covered, this combination is complete-floor/UI checked with lifecycle validation pending, rather than an unconditional release replacement.


## Successful lifecycle follow-up
A new 45-second idle scheduling diagnostic recorded a maximum gap of 0.103061 seconds and no gaps above 0.2 seconds. This justified one fresh guarded attempt, not a relaxation of protection or a guarantee of future stability. The observer's skill-learning priorities were aligned with the complete-floor Q2/E2/R1 combination.

The normal run naturally reached R1. At age 0.26 seconds before its unified release, damage and control immunity both reported true. A normal Shift input left R1 active and its animation intact, consistent with the original non-cancellable presentation rule. Through the ordinary menu, Start New Run and confirmation flow, the old encounter then reported clean: old cast no longer current, pending effects and wind projectiles empty, core presentation empty, r1_active false, R1 cast state absent and rendered animation empty. A different new run ID and clean new presentation/projectiles were confirmed.

Guard passed: wall 108.986424 seconds, largest sample gap 0.128570 seconds, peak owned RSS+swap 419229696 bytes, exit 0, all owned processes cleaned up, no SCRIPT ERROR. This closes the pre-release menu/new-run cleanup gap; the earlier failed attempt remains a failure. It does not claim after-release forced closure, death or every modifier. The build can now be described as Q2/E2/R1 complete-floor, key-UI and pre-release lifecycle checked, while retaining the older combination and excluding Q3. It remains subject to user visual/gamefeel acceptance.
