# Pending-choice navigation guidance

Two-source isolated delta on corrected 7b10 (GitHub 6b927471182074ba7efd58643e79b63227ec8806). Not uploaded, not selected playable, no engine/parser/visual acceptance.

Confirmed issue: a paid body choice may remain pending after the shop closes. Session correctly prevents exit, but prior guidance still directed the player to the upper exit. Host now reads the actual model snapshot derived pending fields only in live safe preparation/between_rooms/service states. Guidance identifies the required choice, tells the player to press P to reopen a closed shop, and prevents an older transient notice from hiding the current blocker. Fault remains highest priority. Terminal and combat guidance retain their previous behavior. No pending, payment, damage, movement, input or transition rule is modified.

Restore: prepare ROOT/corrected_feedback_candidate with exact 7b10 PCK using the backed prior chain; preserve ROOT/tools and ROOT/source. Run python restore.py --root ROOT --output NEW_ABSENT_DIRECTORY. It checks base pack, before/after source hashes, route source pin and 258 manifest bindings, and expected output pack. Original private archives remain required.

Service guidance: while a live safe shop is open, show P/Esc close instructions before manual pause or obsolete Enter guidance. Enter only marks readiness; button now says prepare to leave and service text explains walking to the upper exit afterward. Existing completion, purchase and transition rules are unchanged.

## Proposed publication
Six text-only recovery files, prepared locally and NOT uploaded. Destination: c1903146900-dev/shuabao, branch checkpoint/player-health-cue-20261106, directory choice_guidance_20261117/. Public content reveals game source changes and restoration instructions. No art, audio, game binary, original private archive, account data, private conversation, or execution logs are included.

## Verified recovery
The 7b10 baseline was rebuilt from the owner-held verified original archives and fixed public history, including recovery_unified_20261117 at ad4dd4db4c28acee35583fc545b1ca8d7c20b034 and combat_feedback_20261117 at 6b927471182074ba7efd58643e79b63227ec8806. This two-source delta has been restored to a fresh directory, matching all 260 runtime files and PCK bytes. Expected output PCK SHA256: 8a4dbdc3dc4c75328e762c65bdc2af232f7507e475a3353fe9ade316b4c87045. The generated boot descriptor carries its own output path, so whole boot-directory byte equality is not claimed. Independent source review covered pending-choice fields, safe/live gating, terminal exclusions, actual Enter and Esc handling, and snapshot projection. No engine, parser, visual or gameplay acceptance is claimed.
