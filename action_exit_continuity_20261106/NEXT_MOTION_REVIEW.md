# Remaining motion review priorities

Source-based planning only; do not present these as newly observed gameplay defects or implemented fixes.

1. Q2: skill_effects.gd projects each source strike into a hero-clock duration with no recovery. presentation.gd switches dash to dashattack_contact at 65% of that duration. Inspect an actual multi-target chain before replacing this abrupt pose boundary. Any continuous motion must follow each source strike, respect facing changes and never invent travel, targets or impact timing.
2. E2: each validated e2_spin_started event owns a world-clock rotation duration and currently reuses three attack poses. Inspect initial and extra rotations, blink and return. A new motion must not restart the continuing pose on a return event or mistake world time for hero/real time. Do not simply apply an anatomical 360-degree arm rotation to a front-facing cutout.
3. R1: source has 1.1 seconds to a unified release and a 1.6-second total, on real time. It is not a series of separately timed damaging slashes. Inspect whether its long held pose communicates anticipation. Do not manufacture repeated hit events or replace real time with the slowed world clock.
4. R2: nail_effects.gd reuses E1 throw art with source hero-clock timing and validates every front. Inspect throwing-arm travel before changing it; keep nail count, coincident glyphs and actual source contacts intact.

The isolated locomotion-exit fix is lower-risk than inventing new motion for unseen sequences. Preserve the verified E1 baseline, the pending Q3 candidate and this static candidate separately.
