# Equipment static audit

No new gameplay feature or runtime change was made. The requested affordable final-equipment chain does not exist at original prices: all 42 final items exceed the 2485 pre-first-Boss budget (minimum 2750).

105 read-only checks passed: 30 base/intermediate equipment stat definitions (including explicit unit conversion), original prices and recipes, absence of invented passives/actives, and 15 source-level consumer checks. No missing mapping or consumer was demonstrated. AP is mapped and used by conditional Common Hex formulas; this does not authorize new AP scaling for AD-only skills. None of the 30 items grants attack range.

This is not an engine test or behavior acceptance. No Godot, GUI, production, prior checkpoint, guard, price, or mechanic changes were made.

## Reproduction

Run `python audit.py --runtime RUNTIME --source-extraction PRIVATE_SOURCE_JSON --decoder PORTABLE_DECODER --output LOCAL_REPORT_JSON` using the existing portable variant decoder. Do not publish or package the private source extraction or generated detailed report. The audit script only reads these inputs and writes the requested report. The existing regen conversion is retained.

## Input hashes

Runtime machine-template SHA256: e8e31a330fe29aff67a1ca1a04c806e9c7e1f8a67c04983af09119b7c6ccb74a

Private source extraction SHA256: fc8cd1fc1a739ff1cd6704f8c80bec210f0daddf4c84a8a6fdd2509543a79c76

The decoder is the existing g02_reencode_portable.py, SHA256: a41e46a819d4ce8359c6df9afe4173e0f4fae2dd20d6aa326376d40be19c977a
