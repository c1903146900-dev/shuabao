# Actor-specific hit feedback checkpoint

Source-only overlay for hit_feedback02, layered after the complete projectile_cues02 baseline. Preserve earlier overlays in order: combat_rebuild, flow_next, motion_polish, enemy_readability, projectile_readability, then these two files. Required restored assets and refreshed binding manifests are not included; this is not a standalone project. Prior versions remain unchanged.

Runtime SHA256: 744d7a6f5506d00249d78b9c8194c8529d1e9f4bf0833e24631540b017703994. Source hashes are in CHANGE_PINS.json.

Only actually struck enemies receive a short, source-timed silhouette flash and foot-anchored compression/lean. The helper rejects stale, duplicate, replayed, invalid and non-positive damage events, expires pulses after 140 ms, and suppresses dead actors. Original textures are unchanged. No real stagger, knockback, damage, cooldown, enemy AI, HP, source clock or collision changes are introduced.

Fresh verification: production loading and 134 helper checks passed. A final normal-source combat sequence captured 60 chronological frames over eight simulated seconds; its 21.630-second run passed with exit 0 and complete cleanup. Visual review reported a brief response on actually hit bodies while unhit neighbors retained their original appearance. No SCRIPT ERROR/ERROR/ObjectDB warning occurred in that successful final capture; existing boot Unicode/NUL and platform VSync diagnostics remain.

An earlier baseline capture and an initial final-candidate capture were stopped during startup by safety checks. Both were fully cleaned up and were not counted as gameplay evidence. Separate unchanged-code attempts subsequently passed. An intermediate RGB-only effect was rejected during visual review for weak contrast and is not this final version.

Captured frames are sampled sequences, not 60 fps video or exact receipt/image synchronization. Full-floor and key-UI regression of this exact runtime remain pending; prior passes do not transfer automatically. Windows, audio and user acceptance remain unverified. Only code, tests, hashes and this summary are included; no images, raw logs, original art or runtime package are published.
