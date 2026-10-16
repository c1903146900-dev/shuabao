# Presentation motion-sampling fix

Base: Sprite appearance WIP commit ce0aa8e3774873cdaf4b517bb4abce21a94ba9e8, 3338 files. Target 3341: adds the presentation sampling helper and two independent test scripts; modifies Actor view and base_room presentation snapshot only. Payload was constructed by applying SOURCE.patch with zero fuzz to exact published base copies, then checked byte-for-byte against the tested overlay. No whole candidate tree was copied.

The Actor retains its last verified moving state across Host frames that repeat the same simulation sample, subject to movement intent and eligible combat state. A real blocked step clears it, as does release of movement input. Source position, simulation clocks and gameplay are not rewritten. base_room adds scheduler identity only to a duplicated presentation snapshot. Future audio changes to base_room must merge their separate hunks with these fields, not replace the file wholesale.

## Evidence
Native motion fixture passed 3011/3011 with 44 unchanged pins. In the separate actual Host capture comparison, erroneous idle before reaching the wall changed from 8/55 to 0/59; real wall contact was idle in 20/20 observations and released movement was idle in 15/15. Video03 retained 354 input pins, raw ERROR list empty and owned cleanup empty. Capture sample rate is not game FPS. Original video02 failure evidence remains included as text/hash references; no JPEG or MP4 is included.

The inherited Sprite prototype remains WIP: gait/direction transitions, attacks, VFX, full art and audio acceptance are not established by this motion fix. The historical overlay manifest says source_only_not_engine_validated because it predates the separately included native evidence. No audio implementation or unfinished audio Host result is included.

## Recovery
Concatenate parts in ARCHIVE_PARTS.json order and verify each part/archive SHA-256 and size. Extract into a new directory and review restore_sources.py. Run Python 3 restore_sources.py --base-game PATH_TO_CE0_SPRITE_TREE --base-map PATH_TO_CE0_TARGET_SOURCE_MAP --output NEW_OUTPUT_PATH --manifest-sha256 VALUE_FROM_ARCHIVE_PARTS. Output must not exist. All 3338 base files and 3341 target hashes are checked, leaving the base unchanged. No engines run. Exact before hashes prevent accidental installation over a divergent audio/motion tree; merge separately before repinning.

No recordings, user reference material, private media, raw logs, cache, userdata or audio payload. Local independent restoration is verified; remote Git SHA/size validation is not a second remote download-and-restore.
