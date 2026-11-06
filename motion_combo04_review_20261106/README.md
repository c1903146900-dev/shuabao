# Shooter facing merged into pouncer baseline

motion_combo04 starts from the verified motion_combo03. The only behavior change is extending its existing signed enemy-body scale from pouncer to pouncer and ranged shooter, plus a read-only shooter-facing receipt. It does not replace the full presentation file with the older shooter branch and therefore retains pouncer anticipation/landing, hero/minion animation, health cues and all previous accepted work.

Package SHA256: f27313d385817900802ac84a8956214fdb18e28b2dccb6e690a3db3f0284005e. Only presentation.gd and manifest/generation seals differ from motion_combo03. All simulation, enemy AI, skill mechanics, combat values, room progression and artwork remain byte-identical. The future body picker must record this same signed scale; body_aim05 is not included.

The combined mixed-combat observation passed: wall49.223753 s, gap0.065637 s, exit0 and cleanup. It recorded2,576 shooter-direction samples,2,151 left and425 right. Actual mixed combat images25/40 were reviewed with both enemy types present. All11 UI checks passed on the final package (wall12.458214 s, gap0.054872 s). Existing NUL font diagnostics remain; no SCRIPT ERROR.

Full-floor result is appended below. No candidate is promoted on an incomplete run. Earlier motion_combo03 and all failed guard records are retained.

Recovery: rebuild motion_combo03 through its documented chain, then run rebuild_20261106/build_motion_combo04.py with a fresh output name. Private original inputs/art are required; this is source/recovery evidence rather than a standalone public release.

## Final full-floor pass

FINAL NATURAL_PASS time=157.211168666665 rows=12 HP=321.888392857137 gold=795 purchased=7 used=2 route=["r01a", "r02a", "r03a", "r04a", "r05a", "r06a", "r07a", "r08a", "r09a", "r10a", "r11a", "r12boss"]

Guard wall169.203585 s, max gap0.151342 s, exit0 and full cleanup. This final package passed mixed combat,11 UI checks and the full floor and is adopted as the latest functionally verified development baseline. It is not human aesthetic or Windows acceptance. body_aim05 and Q3 animation remain separate.
