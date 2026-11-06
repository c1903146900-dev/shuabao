# Pitcher airborne-projectile readability

Candidate lob_cues01, based on frozen audio_sync01. PCK SHA256 c9bfba8f7a73cc51019801cd78c837863a82925835d31d3a7387334cd4ed3856.

## Actual combat finding

The fourth selected room mixes armored,ranged,pitcher and three minions. Normal-source combat captured75 frames over10 seconds. In baseline frame31 the pitcher projectile's source height was2.219 world units, but presentation drew it as an undifferentiated tiny red dot on the ground. The flight arc was being discarded, making the projectile's airborne phase harder to distinguish from straight shots and landed hazards.

The new presentation projects the existing authoritative height above its current horizontal position. A small dark position shadow remains below, while the airborne orb has hostile-red outline with a pale violet core. No landing target or predicted damage-area decal is added. The existing actual landed ink disc and its damage boundary are unchanged. Timing, enemy roster, HP, damage, collision, aim lock, and projectile trajectory are byte-identical to audio_sync01; this is not a difficulty reduction.

Only presentation.gd,new lob_cue.gd,and manifest/generation seal differ from the baseline. Prior candidates and Windows ZIP are preserved.

## Evidence

Before and after normal-source routes reached the fourth room and each captured75 frames/10 seconds:baseline guard exit0/full cleanup67.315787974s;candidate guard exit0/full cleanup64.486890583s. Candidate105 checks passed, covering101 arc heights/projected points/source immutability,invalid heights and friendly exclusion. Actual candidate frames22–28 contain the source ascent/apex/descent (height0.73→3.18→1.20); manually inspected frame23 clearly separates the airborne orb from its shadow and from a simultaneous straight bolt. This does not establish player reaction success or final aesthetic satisfaction.

Normal full-floor follow-up completed; see below. Navigation and combat are script-assisted source actions, not human completion. No physical-audio or Windows acceptance is claimed. No new package has been published.


## Full-floor follow-up

Unchanged lob_cues01 completed all12 selected nodes through Boss:203.856390000 simulation seconds,215.657364347 wall seconds,HP316.008392857142,gold395,nine potions purchased/nine used. Guard passed,exit0,max gap0.124647429 seconds,all owned processes reaped. No new script errors observed; no safety or gameplay settings altered. Source-authoritative active ink discs continue to be consumed by the existing validated reader. This single successful scripted route does not cover every branch or establish manual/Windows acceptance.

Source-only overlay: apply after the preserved audio_sync01 runtime, keeping earlier overlays and required assets, then regenerate binding hashes. This is not a standalone project. Public capture copies save `user://lob_before_frame_*.png` or `user://lob_after_frame_*.png`; images, logs and runtime packages are excluded.
