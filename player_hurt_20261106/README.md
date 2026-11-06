# Player damage health cue: incomplete checkpoint

Adds a source-driven local health bar below Fengli after actual positive HP damage, with live HP, a short trailing loss segment, and a two-second lifetime. No damage, healing, AI, movement or combat rules change. No new authored hurt animation is claimed.

Prior recorded focused validation: 243 helper/production-load checks passed, plus normal-source before/after attack captures. The two source hashes were rechecked against the preserved candidate. All 243 binding entries and the generation seal matched; only presentation.gd, player_health_cue.gd and the binding seals differ from walk_layer01.

## Fresh combined regression

The initial shell-only UI attempt failed before tests because its execution surface could not access a display. The existing official cloud desktop was available. Running the unchanged approved guard workflow through its terminal resolved that environment issue without installing software or weakening safeguards.

The exact frozen candidate passed 11 key-UI checks in 13.775 seconds. A separate normal-source, script-assisted full-floor run passed all 12 selected route nodes through Boss in 182.933 simulated seconds (195.763 wall seconds), ending with HP 420 and gold 395; nine potions purchased, four used. Both runs passed runtime monitoring, exited 0, and fully reaped their owned processes. Maximum monitoring gaps were 0.0571 and 0.0683 seconds, respectively. No SCRIPT ERROR appeared; existing NUL-character diagnostics remain. The runtime pack was rehashed afterward and remained unchanged.

These tests use normal source combat and router/UI actions, not injected HP, damage, resources or disabled AI. They are script-assisted regressions, not human playthroughs. Hardware audio, Windows execution, crowded-scene visual acceptance and user quality acceptance remain unverified. No release package is published by this checkpoint.

## Recovery

First follow ../rebuild_20261106/REBUILD_CHAIN.md through walk_layer01, using the two authorized private original archives and existing published source overlays. Then, from the repository root, run:

    python rebuild_20261106/build_player_hurt.py player_hurt01

The output directory must not already exist. Expected boot/packs/runtime.pck SHA-256: fe8882376278cdb9040875990d3cd3ca71691b9ccaf0c2e5cde8c542ba627a7a.

A fresh output-directory reconstruction from the preserved walk_layer01 baseline and these overlays reproduced that exact pack hash. This extension check does not repeat the full original-archive restoration. The earlier recovery chain remains necessary; this checkpoint is not a standalone playable distribution.

check_health.gd is a SceneTree test observer requiring the matching packed project/bootstrap and the existing approved runtime test workflow. It is not a standalone engine launcher. Do not bypass runtime safeguards to run it.

Only source, tests, build code and hashes are included. Private archive identifiers, assets, screenshots, recordings, runtime packages, diagnostic logs and internal reports are excluded. No release publication or completed acceptance is claimed.
