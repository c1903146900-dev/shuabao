# Enemy defeat visual review: isolated work in progress

Accepted baseline remains motion_combo14. No game mechanisms have been changed.

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
