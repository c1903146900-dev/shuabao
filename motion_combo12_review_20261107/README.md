# motion_combo12 accepted development baseline

Adds verified landed-ink material to preserved motion_combo11. No game mechanics change. Pack SHA256 f400fce7fbfc1468c071d5896741345ad1ca6ffb30ccff19e597a41f29ea38e0, identical to tested ink_material_draft01. Recovery: reconstruct combo11 via its existing chain, overlay ink_material_review_20261107/changes using rebuild_20261106/build_ink_material.py with a fresh output name, regenerate seals/pack. Original private inputs required; public backup is not a standalone playable build.

Complete12-row/Boss normal source regression,11 UI checks, real player/nearby enemy/warning crossing, and synthetic multi-zone material draw all pass. See ink_material_review_20261107/summary.json for scopes and timings. Previous baseline remains intact; returnstroke candidate has not passed full-floor and is not merged. Boss-body candidate remains separate.
