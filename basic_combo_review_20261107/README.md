# Ordinary basic attack return-stroke candidate

Isolated candidate basic_returnstroke_draft02. Accepted baseline remains motion_combo11.

Actual first-room captures confirmed three consecutive ordinary basics used the same overhead windup/downstroke. At equal attack age .08, the first and second attacks had identical arm angles. This repeated chopping stroke is a visible limitation, rather than an input defect.

The candidate alternates the existing rigid sword/arm slice on positive even ordinary attack_started serials: start -.45, windup +.50, contact +.05, follow-through -.85, end -.45 radians. All original timing nodes remain. Odd attacks keep the old downstroke. Source combo is an accepted-basic serial, also incremented by dash basics and subsequently canceled basics; this is NOT a new combo meter, finisher or gameplay sequence rule.

Only puppet_motion.arm_angle changes, strictly restricted to ordinary attack_started with positive even combo. E2/Q3/R1 shared animation branches, dash/dash-basic, body lean, walking legs, damage, contact clock, cone/range, aim, source events and input remain untouched. Contact pose and starting/ending pose match the old curve. No directional ordinary blade trail exists to conflict with the reverse swing; actual-hit diamonds remain source-owned.

First candidate used +.65 windup. It passed a short source-combat capture, but its sword dipped too low for a conservative motion range. It is retained as changes01 and local draft01. The final candidate reduces windup to +.50, within the existing normal arm-angle envelope. Current changes is the final overlay.

Build from original private recovery/runtime inputs:
python3 -I -B rebuild_20261106/build_basic_returnstroke.py NEW_DIRECTORY
Base: motion_combo11/runtime. Final pack SHA256: 841c7915e2a19908166f3ee250f058398fcf4107c4597ae27ec4fc6c571ea4ad.
Public backup contains safe source overlays, builder, observers and summary only, no private art or screenshots/raw recordings. Not a standalone playable public build.

- combostrokebefore01: normal source first-room three-basic observation; repeated downstroke confirmed; guard passed, clean exit.
- combostrokeafter01: draft01, first/second strokes visibly different, low windup reviewed; guard passed.
- combostrokeafter02: draft02, normal first-room attacks/hurt. Second stroke sampled windup .484 at age .12, contact transition .0935 at .20, upward follow -.839 at .34, return -.462 at .60. Impact/windup/return frames inspected. Guard passed, clean exit.

These are script-assisted normal source combat actions, not native held-mouse interaction or final aesthetic acceptance. Remaining: opposite-facing mirror, moving basic and dash/skill transitions, interruption/exit continuity, shared UI and complete first-floor regression. Do not promote before those checks. Old combo11 and Boss motion isolation remain intact.
