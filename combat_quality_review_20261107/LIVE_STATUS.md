# Enemy defeat visual review and combo15 acceptance

Latest accepted baseline is motion_combo15; the historical candidate stages below started from preserved motion_combo14. No game mechanisms have been changed.

Actual baseline observations:
- quality14a: 20 seconds of ordinary first-room combat, 25 bounded screenshots, guard max gap 0.055331552, exit/cleanup pass.
- deathbefore14a: first actual low-health minion kill, 14 frames before/after. Source dead/HP0 and removal from picking occur at the real kill; the target is partly occluded, so this is limited visual evidence. Guard max gap 0.055321487, pass.
- lastbefore14a: clearly visible last armored enemy disappears between adjacent actual frames, about 58 ms apart, while victory/gold/exit are correctly committed. Twelve frames; guard max gap 0.055426793, pass. This is the clearest abrupt-removal issue, not an inferred new game rule.

First candidate enemy_defeat_draft01 pack: 1dfc14fe45184ea0376fa63b06e32926849c937274cc9184dfd7afe1882707a7.
It freezes the actual last original-art body frame for a bounded 0.22-second visual remnant, triggered only by a source-confirmed kill. It cannot be targeted and has no collision/HP/warning contribution. Combat uses source real_time; victory finishes the visual tail without advancing the source clock or delaying rewards/exit. Ordinary menu suspension hides/freezes the old scene; resuming that run follows the same pause rule. New-run scope does not inherit the old remnant.

- defeatlast01: ordinary last armored kill reaches victory immediately, remnant visible then cleared and never in picking. Guard max gap 0.139528380, pass. Automatic observer shopping/learning after kill created an unhelpful capture gap; this was not an animation failure or aesthetic acceptance.
- defeatlast02: same candidate with observer simply releasing inputs after kill. Better intermediate samples at visual ages .061/.127/.189 seconds show alpha .826/.431/.116, followed by expiry. Guard max gap 0.055470547, pass. Visual review judges the current version primarily a ghost-like fade with only slight lean, insufficient to claim a strong defeat animation. A separate stronger-collapse candidate is being prepared; no promotion based only on technical passes.

The overlay subsequently gained two receipt-only observation fields (body_mirror_sign and frame_real_time); draft01 contains the earlier presentation version. Keep pack/source identities separate. Original actual captures and raw logs remain local and are excluded from public backups. The project source, builders and bounded observers are public-safe recovery material.

V2 pack: ed78f36bbd844fa4435d26158a5305e68caa29afd012c9847bc53921d38a3045.
It keeps the same 0.22-second lifetime and source rules, but increases the visible collapse and holds opacity through the first 30%, so the body falls before fading. defeatlast03 completed the actual last-armored kill: visible samples at .049/.099/.164 seconds, alpha 1/.881/.299 and lean .216/.384/.515; then no remnant. Guard max gap 0.055124665, wall30.061263 seconds, exit0/cleanup pass. The actual middle frames were inspected: the armored body now visibly tips and compresses instead of mainly turning transparent. Victory is already active while this short body-only animation finishes. This is a meaningful bounded visual improvement, not final aesthetic/full-regression acceptance. Additional crowd, multi-kill and lifecycle coverage remains pending.

Further v2 validation:
- defeatcombat02: real minion defeat while combat continues. Four live remnant samples (.033/.073/.133/.173 seconds) followed by expiry; the dead actor is absent from picking throughout. Actual crowd images inspected. Guard max gap0.055417771, wall22.173368 seconds, pass.
- defeatfull02: normal 12-node first floor including Boss defeated, HP333.468393, gold395, nine potions purchased/four used. Guard max gap0.170418565, wall248.932651 seconds, exit0/cleanup pass. No new script/parse/visual errors. This does not by itself certify group-clear visual quality.
- defeatui02: all 11 shared UI checks pass; guard max gap0.054221330, wall12.296561 seconds, cleanup pass.
- defeatlife02 failed before a kill because the observer incorrectly rejected the initial safe-area route-selection map. Stable guard, exit9; no gameplay-source modification. That failed observer is retained locally.
- defeatlife03 with only that observer-navigation error corrected passed: source-confirmed minion kill, real menu pause with hidden/disabled old tree and frozen source/remnant, actual Resume with the same owner/run and advancing real-time remnant, then menu Start/Confirm. Old owner/helper weak references release; three fresh initial draw frames contain empty caches/no remnant. Guard max gap0.066708179, wall23.322245 seconds, exit0/cleanup pass. Menu correctly preserves its paused same-run state rather than falsely clearing it.

The package has 244 verified sealed entries; only presentation, the new visual helper and two generated seals differ from combo14. Group-clear visual observation is the next quality check; no premature promotion.

## Limited group-clear observation, not a full observer pass

defeatgroup02 reached the first legitimate learned R1 in room r08a. That actual cast killed five of six enemies; the armored survivor remained alive. The observer required victory as well and timed out with exit9, so the run remains FAILED and is not a full-room-clear proof. Guard was stable (max gap0.055806674, wall123.114708 seconds) and owned cleanup passed. No retry or production change was made to force a clear.

Its 12 real frames nevertheless provide useful, narrower evidence. Five matching kill IDs each produced exactly one body remnant; all five were absent from living/picking immediately. Actual source-real ages 0/.06/.10/.14/.18 show their bodies tipping, compressing and fading together, with none remaining by .227 observer seconds. The surviving armored enemy and its live health bar remain distinguishable. These frames were visually inspected and their ID/expiry conditions independently checked. This covers five-enemy defeat feedback, not victory in that room. True last-enemy victory/expiry and full-floor completion were separately tested above. Do not rewrite this failed observer result into a pass.

## Accepted development checkpoint

After the independent limited group visual review found no blocking issue, v2 was promoted byte-for-byte to motion_combo15. Full observer failure above remains unchanged; it does not supply a full-room victory pass. Separate actual final-enemy victory, complete first floor, UI and menu/new-run checks provide their stated coverage. All 246 runtime files and pack match tested draft02, and all 244 seal entries verify. Combo14 and both candidate versions remain preserved. This is not final user aesthetic or exhaustive all-facing acceptance.
