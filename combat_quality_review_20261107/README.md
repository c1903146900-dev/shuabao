# Enemy defeat motion candidate

Accepted baseline: motion_combo14, preserved unchanged. Current candidate is v2 in changes/. Exact v1 source is retained in changes01/. See LIVE_STATUS.md for actual observations and limitations.

Issue: actual normal combat and R1 clear frames show defeated enemies disappearing abruptly, including an unobscured last armored enemy. Existing source commits death and rewards correctly, but immediately skipping dead body drawing cuts off all body follow-through.

The candidate creates an inert 0.22-second original-art defeat remnant only from the current source-confirmed kill and its last rendered body frame. V2 visibly tips and compresses the body before fading. It preserves the original crop and signed mirror basis. It does not register picking, collision, health bars or warnings, or change source positions, death, rewards, damage, attack timing or room exit availability.

Combat aging uses source real_time. Since that clock stops at victory, a bounded presentation-only tail finishes the remaining visual duration without advancing the simulation. Normal menu pause hides and freezes the existing scene and resumes that same run; new-run/source-scope replacement cannot inherit an old remnant. Hero death, invalid ownership and non-combat/non-victory state clear the effect when presentation processing runs. No claim of immediate processing while the tree is disabled is made.

Build current v2 using:
python3 -I -B rebuild_20261106/build_enemy_defeat.py enemy_defeat_draft02
Use a new output name if it already exists. The builder refuses to replace existing output. Recovery depends on the accepted combo14 source/build chain and locally authorized original assets; this public source checkpoint is not a standalone asset distribution.

V2 pack SHA-256: ed78f36bbd844fa4435d26158a5305e68caa29afd012c9847bc53921d38a3045
V1 pack SHA-256: 1dfc14fe45184ea0376fa63b06e32926849c937274cc9184dfd7afe1882707a7

V1 was judged too fade-dominated despite passing a narrow technical check. V2 has been rendered in an actual final-enemy kill and visually reviewed, but remains isolated pending further combat/lifecycle regression. Do not treat static curve checks or observer exit0 as final visual acceptance.

Only project source, builders, bounded observers and aggregate summaries belong in this backup. Original assets, runtime captures, raw logs, private reference material, credentials and personal data are excluded.
