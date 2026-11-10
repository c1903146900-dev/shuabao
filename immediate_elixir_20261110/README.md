# Immediate elixir source recovery and current QA

Four recovered source files enable immediate consumption effects, preserve effects across safe rooms, bind them to the next battle, expire them after that battle, and clear consumed effects at a committed rest entry. Held bottles remain inventory. These are recovered earlier implementation bytes, not four newly designed files. Their hashes match the retained source hashes.

The current tested candidate combines these four files with the separate steel_undo_20261110/steel_undo.patch checkpoint. Four files alone rebuild the earlier immediate candidate, not the current tested correction.

## Recovery order and integrity

Start with the existing repository recovery instructions and the two original private game archives. This public repository does not include those archives or original art/assets. Preserve the established reconstruction order through motion_combo17 and elixir_all_recovered01. Expected all-five PCK SHA-256: 79c6fa4a3c61b3a54b63e2db81087c1c8048493870ecbd3e678dfcc4ddd21dab.

Copy this directory's changes into a fresh copy of that all-five runtime. Use the existing rebuild_20261106/build_elixir_all.py manifest, generation-seal and PCK packaging procedure unchanged. For a standalone builder derived from that template, replace only its runtime source expression R/'motion_combo17/runtime' with R/'elixir_all_recovered01/runtime' and its overlay-folder list with [R.parent/'immediate_elixir_20261110/changes']. Keep the template under rebuild_20261106 and select a fresh output name. Expected immediate PCK SHA-256: d218ded00ff78fd279f4b585382f3dc910bf194ca0dbc00ef4bec1d5d7864c4e.

Next, apply steel_undo_20261110/steel_undo.patch to a fresh copy of this immediate runtime, using zero-context unified-patch support. Verify its before and after SHA-256 values, regenerate the binding manifest and generation seal using the same packaging procedure, and package again. Expected corrected PCK SHA-256: 30fc86491e3b1b407016770f3040bd7f8be09237660d60220e3f563e8ed289e6.

Both runtime PCK hashes were independently reproduced again during backup preparation. The patch also reproduced all three after-source hashes. Exact local builder scripts, generated packages and original assets are not included in this checkpoint. Recovery therefore requires the private original archives plus the existing build chain and the adaptations described above; this directory alone is not a runnable project.

## Current verification

All QA files describe the corrected 30fc8649... candidate, not the four-file overlay alone:
- Three elixirs, auto/manual lifecycle: 280 assertions, zero failures.
- Arcane/hunt isolated attribute lifecycle: 171 assertions, zero failures; proc/final-damage behavior is outside this check.
- Source-earned shop route: 725 gold, 650 purchase, 75 remaining; war drink changed attack 38 -> 73 and lifesteal 0 -> 0.08. Setup/navigation used scripted normal actions; purchase and drink used native input.
- Committed-rest fixture: 90 assertions, zero failures; steel removal preserved ratio, rest healed once, held war bottle survived, repeated entry did not heal twice. This fixture funds its own model and seeds HP.
- Fresh source-action full floor: 12 rows, nine purchases/uses, exit 0, 253.573 wall seconds. It is scripted, not a human playthrough.

Earlier fixture failures and interrupted startup attempts are not counted as passes. A lifecycle attempt stopped before checks; the later lifecycle02 result is recorded here. No Windows, audible-device, player aesthetic or exhaustive economy acceptance is claimed. Native full-slot and same-name duplicate purchase remain outside the natural-shop evidence.

The lifecycle probe was restored from retained source text without an old script hash, not proven identical to its historical bytes. Other probes include existing fixture scaffolding. Public copies change only output handling to user:// paths; those output adaptations have not been rerun in-engine. Use fresh output directories and the project's unchanged process/resource safeguards. No capture images, raw logs, private reference materials or credentials are published. FILE_HASHES.json binds the delivered source, test and QA files.
