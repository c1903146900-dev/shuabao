# E1 full-floor and UI follow-up

Candidate e1_motion01 remains byte-identical to the previous checkpoint.

The normal UI regression passed all 11 checks: no script error, guard passed and cleaned up, max sampling gap 0.054863 s.

The first E1-equipped full-floor attempt was stopped in node 2 by the unchanged guard: sample_gap_untrusted, max gap 0.307239 s against the 0.2 s limit. Peak owned RSS+swap was 395026432 bytes. All owned processes were cleaned up. This was not counted as a pass and the safety limit was not relaxed.

A fresh 45-second idle scheduler diagnostic then showed max gap 0.051919 s, no samples above 0.2 s, load declining 0.16 to 0.07. These observations do not establish the cause of the earlier scheduling interruption. One fresh guarded attempt then completed using E1 rather than the earlier E2 loadout: all 12 nodes through Boss, 204.397685 simulated seconds, final HP 223.236786, gold 795, seven potions bought and consumed. Guard passed, exit 0, wall time 216.282035 s, max gap 0.069787 s, peak RSS+swap 404439040 bytes. All owned processes cleaned up; no script error. Existing NUL diagnostics remain.

This confirms scripted first-floor and UI regression, not manual acceptance, universal skill balance or Windows validation. No asset or mechanic changes were made for these tests. Both failed and successful local evidence are retained; raw logs and private screenshots are excluded from this public backup.
