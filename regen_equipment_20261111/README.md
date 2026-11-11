# B12 / I12 combat regeneration admission

Baseline: G02 checkpoint 26b3bc726d859a0195feda225b6c83368d767efe. This admits the two original regeneration equipment definitions and adds explicit combat-time units to their shop descriptions. No additional skill, timer, model override, price change or new undo restriction is added.

The original design gives regeneration values 3 and 5 without a time unit. The mapping to per-five actor combat seconds is the existing 2026-10-08 developer interpretation, shared with the current training regeneration, not a quotation from the user.

Apply regen.patch to a separate copy of the exact G02 runtime. Run regen_reencode_portable.py with arguments BEFORE_RUNTIME regen_definition.json FRESH_OUTPUT_DIRECTORY to reproduce the template and pins from the original template plus regen_definition.json; compare SOURCE_HASHES and the tool output, then rebuild manifest, pack and release descriptor through the existing recovery chain. The owner-held original archives remain necessary. No private binaries, assets, source documents or raw logs are included.

QA.json distinguishes static reasoning, explicit focused-test fixtures, normal earned-gold gameplay and real mouse actions. Until it records completed runs this is an unverified candidate. All engine runs must retain the existing guard. No Windows or real-audio acceptance is implied.
