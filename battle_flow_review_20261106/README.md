# Mixed-room battle-flow observation

Observed normal script-assisted gameplay through the ranged/pouncer route rather than only isolated animation frames. The 45-second combat window reached three rooms: ranged enemies maintained distance while minions and pouncer engaged; once melee enemies were removed, shooters remained to be approached. Room one took roughly 26 seconds in this input strategy, room two roughly 11. This is one strategy, not proof of human difficulty or a reason to rewrite authored enemy roles.

Guard passed: wall 72.586598 s, max gap 0.067396 s, peak RSS+swap 704897024 bytes. Separate threat-framing check passed at wall 43.800227 s, gap 0.152910 s, peak 560332800 bytes; 49 warning/release observations, two lower-boundary pouncer foot anchors, bodies still visible. No camera change justified. The next body-aim geometry sample passed at wall 42.905914 s, gap 0.183617 s, peak 559906816 bytes. All exited 0 and cleaned up owned processes.

The most concrete usability issue found was body-versus-ground ordinary-attack aiming. See body_aim_review_20261106/README.md for evidence, isolated implementation and explicitly incomplete native validation. No balance, spawn, attack cadence, damage or progression rules changed.
