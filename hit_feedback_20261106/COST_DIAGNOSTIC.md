# Row8 feedback-cost investigation

A separate measurement-only pack was built from hit_feedback02 by wrapping hit_reaction.accept/sample with microsecond timers/counters. It does not replace or change the frozen production candidate. No gameplay logic, source timing, enemy values, or guard settings changed. The diagnostic uses normal source combat via the existing router/UI test and stops at170 simulation seconds; it is not a full-floor acceptance test.

Result: passed guard,exit0/full cleanup,181.825480415 wall seconds,max sampling gap0.132467569. The normal route completed row8 and reached Boss before its diagnostic cutoff.

Row8 contains six authored enemies:armored,support,ranged,pitcher,and two minions. Across27 one-second observations (simulation97.879–124.070s), median process time24.775ms,median59FPS,median161 draw calls,max185; maximum sampled projectile count2 and hit-cache count1. Total helper accept cost1,636us over206 calls (7.942us mean),sample cost22,601us over4,606 calls (4.907us mean). About24ms of helper CPU was observed across this26-second interval, not per frame. Earlier cumulative maxima were214us accept and1,032us sample, and did not increase in row8. No evidence of unbounded hit-cache or helper work growth was seen.

Limitations: this measures GDScript helper CPU, not GPU mask/texture draw time. There was one717.655ms process-time sample at simulation121.057s,with134 draw calls and no projectiles; helper cumulative maxima did not change. It occurs near the row's completed-combat interval, but attribution to map/UI, renderer, scheduling or other subsystems is not established. Do not claim consistent smoothness or a resolved root cause.

Static inspection: eight flash masks are created once at presentation initialization,not per hit. No mask/image allocation is added inside the draw-time flash method. Existing source event sequence/scope validation and short per-enemy cache prevent accumulating visual displacement. These observations do not independently prove performance on Windows.

Decision: the diagnostic traversed the two earlier failure points without relaxing protection and found no disproportionate helper cost. One further full-floor run of the unchanged frozen production pack was subsequently performed, as recorded below. Keep all failures and do not count this instrumentation-only run as production acceptance.


## Frozen production follow-up

After the separate cost diagnostic, unchanged production hit_feedback02 passed hitnatural03:all12 nodes through Boss,193.447893000 simulation seconds,205.170903428 wall seconds,HP324.418392857134,gold395,nine potions purchased/six used. Guard passed,exit0,max gap0.120035536 seconds,full cleanup. No instrumentation code was included in this production pack. All241 manifest entries and the frozen PCK hash remain unchanged. Previous failed runs remain valid historical failures,not erased by this pass. Intermittent sampling/long-frame root cause remains unresolved. This is script-assisted normal source combat,not human or Windows acceptance.
