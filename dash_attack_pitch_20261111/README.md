# Isolated directional dash-attack display checkpoint

This is not the selected playable build. Baseline 4112ebb6 is retained. The patch touches only two presentation sources. Apply with git apply --unidiff-zero against the exact SOURCE_HASHES before bytes, then reseal manifest/generation/PCK using the existing recovery tools. Expected candidate PCK is in QA.json.

Native input short tests passed under the unchanged guard and show clearer vertical blade direction. Full-floor validation was stopped at startup by the guard; do not claim a full pass. South blade visibility remains partly obscured by the existing leg/HP cue. See QA.json for exact scope.

The two observers are byte-identical to executed tests and write screenshots only to user://. They use scripted ordinary room setup followed by actual native input. Their persistent helper receipt may be stale after action exit; settled screenshots, not that receipt, support the exit observation.

check_static.py is the executed development static test. It expects the recovered baseline at ../source/rebuild_20261106/dash_trail01/runtime and patched sources at changes/. Recreate those inputs before running; it is not standalone GDScript/renderer verification. Static QA predates runtime testing.

No binary, artwork, private design documents, screenshots, raw logs, process identities or Windows package are included.
