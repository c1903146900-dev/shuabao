# Existing enemy cooperation: source audit and actual combat

Accepted baseline motion_combo11 unchanged. Return-stroke candidate remains separate. Product intent is distinct readable enemies that complement one another; a new hard blockade mechanic is not an established requirement. No new balance rule is introduced by this review.

## Connected implementation
Host loads Session.DEFAULT_DEFINITION, the user-route first_floor.json, then starts each selected payload. Normal r01c contains two ranged, one pouncer, three minions. Pitchers occur in r04a/r04e and all row-8 combat choices. Support plus armored occurs in r08a/r08e/r09c/r10b. The generic make_wave_roster is not the basis of this finding.

Production uses fengli_route_20261024/enemy_director.gd via sim.gd, not just the common director. It includes distance-maintaining shooters, flanking pouncers, support seeking a nearby armored, hex-bolt exposed status consumed by hero damage, actual pitcher zones, and a shared threat budget/escape availability gate. The budget includes warning actors, projectiles and zones.

## Latest actual observation
Normal source first-room r01c on combo11, 22-second combat window, script-assisted normal inputs. 34 warnings (20 ranged, 8 minion, 6 pouncer), 20 shots, 6 pounces. Viewed frames 16 and 18: pouncer active with an incoming bullet; later both shooters and a minion warn together while the player can move/dash. Max sampled threat weight 3. This is real overlapping pressure, not only a roster declaration. The room was not cleared by the bounded stop; two shooters remained, and the scripted nearest-target strategy is not a human difficulty verdict. No visual receipt errors. Guard wall40.136s, gap .054510, exit0, clean owned cleanup.

## Limits, not invented defects
Attack scheduling uses distance, shared budget, waiting age and escape availability, not explicit teammate combo timing. Pitchers aim at the committed hero position rather than choosing a future escape corridor. Support selects the nearest living armored even if its shield is temporarily broken, and can attack before arriving behind it. These are source-supported behavior limits, not yet demonstrated play failures. Do not turn them into mandatory hard enclosure or alter hero mechanics.

A useful next targeted observation is the already-authored r08a/r08e support+guard+pitcher group: watch guard break, support relocation, exposed follow-up and surviving escape paths. Preserve attack commitment, control cancellation, existing fairness gates and authored room composition. Only change behavior if the observation exposes a concrete mismatch or weakness. No production code change in this pass.

Public backup includes observer and aggregate findings only; excludes private artwork, screenshots, raw sessions and user conversation text.
