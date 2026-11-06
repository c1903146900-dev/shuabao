# Player damage health cue: incomplete checkpoint

Adds a source-driven local health bar below Fengli after actual positive HP damage, with live HP, a short trailing loss segment, and a two-second lifetime. No damage, healing, AI, movement or combat rules change. No new authored hurt animation is claimed.

Prior recorded focused validation: 243 helper/production-load checks passed, plus normal-source before/after attack captures. The two source hashes were rechecked against the preserved candidate. Full-floor and key-UI regression of this candidate are still pending. A fresh key-UI attempt failed before tests at display initialization because neither X11 nor Wayland was available; process cleanup completed. This is not a gameplay failure or test pass. Windows and human quality acceptance remain unverified.

## Recovery

First follow ../rebuild_20261106/REBUILD_CHAIN.md through walk_layer01, using the two authorized private original archives and existing published source overlays. Then, from the repository root, run:

    python rebuild_20261106/build_player_hurt.py player_hurt01

The output directory must not already exist. Expected boot/packs/runtime.pck SHA-256: fe8882376278cdb9040875990d3cd3ca71691b9ccaf0c2e5cde8c542ba627a7a.

A fresh output-directory reconstruction from the preserved walk_layer01 baseline and these overlays reproduced that exact pack hash. This extension check does not repeat the full original-archive restoration. The earlier recovery chain remains necessary; this checkpoint is not a standalone playable distribution.

check_health.gd is a SceneTree test observer requiring the matching packed project/bootstrap and the existing approved runtime test workflow. It is not a standalone engine launcher. Do not bypass runtime safeguards to run it.

Only source, tests, build code and hashes are included. Private archive identifiers, assets, screenshots, recordings, runtime packages, diagnostic logs and internal reports are excluded. No release publication or completed acceptance is claimed.
