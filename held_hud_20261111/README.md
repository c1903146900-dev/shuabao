# Held basic attack across non-modal HUD hover

Based on the passed regeneration equipment candidate ea0e1041 (backup338e4d9), without the isolated warning-layout changes.

Goal: a left-button hold that began in the playfield should temporarily stop issuing attack retries while the pointer is over non-modal HUD controls, then resume normal cooldown-governed retries when the pointer returns. UI-origin presses, real UI button actions, pause/modal/focus changes, encounter changes and death must still require a fresh physical press. No attack timing, damage, aim mapping, movement or dash rule is changed.

QA.json distinguishes short native pointer observations from sustained-cycle input-router tests and script-assisted normal-floor regression. Native baseline hover and return are established, but the short native gesture alone does not demonstrate an entire post-return attack cycle. The first connection-interrupted attempt remained paused and is not acceptance evidence.

Apply only the provided source patch to the exact before runtime identified by SOURCE_HASHES, then rebuild the manifest, pack and release descriptor through the existing chain. No private binaries/assets/documents/raw logs or guard changes are included.

Verified result: native D+left-button drag waits on HUD through cooldown expiry, resumes on returning to the battlefield without a new press; UI-origin drag stays suppressed. The focused fixture completed all five sections and the script-assisted 12-room route reached the Boss and completed. See QA for exact coverage; this is not Windows or human full-play acceptance.
