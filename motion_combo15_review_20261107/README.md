# motion_combo15: enemy defeat follow-through

Accepted development baseline: exact tested enemy_defeat_draft02 content promoted byte-for-byte. Combo14 and v1/v2 candidates are preserved. This improves the abrupt disappearance of defeated enemies with a short original-art tilt/collapse and fade. It does not change gameplay mechanisms, hit timing, rewards, collision, picking or room-exit timing.

Build using rebuild_20261106/build_enemy_defeat.py with a new output name. The recovery chain starts from preserved combo14 and combat_quality_review_20261107/changes. Pack SHA-256: ed78f36bbd844fa4435d26158a5305e68caa29afd012c9847bc53921d38a3045. All 246 runtime files and the pack match the tested candidate; all 244 seal entries verify. Only presentation, its new enemy_defeat visual helper and two generated seals differ from combo14.

Visual decision: v1 mainly faded a nearly standing enemy and was not considered enough improvement. V2 holds opacity initially, visibly tips and lowers the original body, then fades within the unchanged .22-second visual lifetime. Actual single-target, final-room-enemy and five-target R1 frames were inspected. Live enemies retain their health bars and remain distinguishable; dead-body remnants never enter the pick list.

Successful exact-content checks:
- Ordinary minion defeat during ongoing combat, immediate dead/pick removal, visible tail and expiry.
- Actual final armored kill with immediate victory/rewards/exit and a bounded visual tail despite the stopped simulation clock.
- Normal full first floor including Boss: 12 nodes, remaining HP333.468393, gold395, nine potions purchased/four used. Guard max gap .170418565, exit0/cleanup pass.
- All 11 shared UI checks.
- Source-confirmed kill, actual menu suspension, same-run Resume with continued tail, then Start/Confirm new run. Old owners/helper release; three fresh draw frames have empty caches and no remnant.

One group observer remains FAILED: its first R1 killed five of six targets, so its extra full-room-victory requirement timed out. It was not rerun or altered to manufacture a pass. The actual 12-frame record separately demonstrates five simultaneous confirmed kill remnants, immediate removal from picking, visible collapse, and complete expiry by .227 observer seconds while the sixth enemy remains alive. That limited finding was independently checked; full victory is supported by the separate final-enemy and complete-floor checks, not by this failed observer.

This is a bounded engineering/visual improvement using existing art, not final aesthetic, human/OS-input, every-enemy-facing, or exhaustive helper-boundary acceptance. See combat_quality_review_20261107/LIVE_STATUS.md for exact run results and preserved failures. No original/private assets, screenshots, raw logs, credentials or personal data are included in the public backup.
