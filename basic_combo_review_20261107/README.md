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

The first comparisons and mirror are script-assisted normal source combat. combomirror01 inspected the opposite facing, preserving the same returnstroke shape. combonative01 used actual held left mouse plus W/S/D, then Shift+mouse, then resumed ordinary moving attacks. Moving lower windup and upper follow-through were visible while walking continued. Dash attack retained its old forward thrust. Shift transition was accepted, but this does not prove precontact cancellation. Guard passed in both runs.

returnui01 passed all 11 normal UI checks. An accidentally reused older comboui01 launch was rejected before engine launch by the fresh-output guard; that older result is not evidence for this candidate. Complete first floor combofull01 was stopped after 83.819 wall seconds by the unchanged sample-gap guard: .306298 s exceeded .2 s. Owned process cleanup completed. This is NOT a complete-floor pass, and the candidate remains isolated. No immediate blind long retry. Independent static review confirms the seven-line change only affects positive even ordinary basics and preserves contact/start/end poses.

Not final player aesthetic acceptance or Windows/hardware/audio acceptance. Old combo11 and Boss motion isolation remain intact.

Lifecycle source review: presentation.gd rejects old run/room/generation events, clears on scope change and matching cancellation, replaces on new actions, and expires on hero clock. Host close ends encounter; new run frees old room/presentation. No stale returnstroke state found. Native Shift occurred 1.04 seconds after the preceding attack, after its .6333-second visual duration, so precontact cancel remains untested here.

## Actual precontact cancellation
returncancel01 uses normal source combat and normal input-router Shift, script-assisted rather than native OS timing. Second basic cast 2 was canceled at hero age .06, before contact .216667. Source attack_cancelled contains cast 2; no impact exists for that cast. The visual receipt and inspected frame 13 switched to dash, then later basic casts 5/6 generated ordinary impacts. No production state, clock, cooldown, damage or rules were edited. Guard passed: wall 22.002 seconds, max gap .059014 seconds, clean exit. Earlier native transition remains a separate non-cancel sample.

returnfull02 followed the stable 22-second cancellation check, but was also stopped by the unchanged guard at wall 62.213 seconds: gap .336804 > .2. Cleanup completed. Full-floor acceptance remains pending; no promotion or further immediate full-floor retry.

returnfull03 followed a 60-second idle scheduler check (max .172211, no gap > .2, load declined). The unchanged guard later stopped the run at wall 238.052 s, gap .404584, during r12boss before completion. Cleanup passed. This shows an idle precheck does not guarantee the sustained engine run; do not treat reaching Boss as full-floor acceptance. Candidate remains isolated.

## Combo12 rebase
Latest isolated candidate returnstroke_combo12_draft01 uses accepted combo12 (including landed ink), with only the same seven-line ordinary arm change plus new seals. All243 manifest entries verified. Pack1f1962274098891b667d621611393d5f55f1dc12758ee6b8d431a01a95abaf7a. Builder rebuild_20261106/build_returnstroke_combo12.py preserves the original builder/candidate.

returnfull04 was stopped at wall138.385 seconds by gap.343603 > .2, cleanup complete. This is not a complete pass. returnui02 passed11 checks, and returncancel03 again proves cast2 canceled at.06 before .216667 contact with no canceled impact and later ordinary attack resumed. That observer writes separate captures; an unused returncancel02 stage is not runtime evidence. No immediate long retry or promotion.

## Accepted as motion_combo13
returnfull05 passed all12 normal-route rows including Boss with the unchanged combo12-rebased returnstroke pack. Simulation230.874034s, HP420, gold395, nine potions bought/used; Q3started21 and contacts28. Guardwall243.266277s, maxgap.114100, exit0 and clean owned cleanup. Previous failed/interrupted runs remain recorded, not relabeled.

Together with original/native mirror and moving/dodge samples, the unchanged rebase's UI11 and genuine .06-second precontact cancellation checks, this supports accepting the development baseline as motion_combo13. Rebuilt245 runtime files and pack are byte-identical to the tested candidate; pack1f1962274098891b667d621611393d5f55f1dc12758ee6b8d431a01a95abaf7a. Old combo12 retained. Boss-motion candidate is still separate. No Windows/audio/user aesthetic acceptance is claimed.
