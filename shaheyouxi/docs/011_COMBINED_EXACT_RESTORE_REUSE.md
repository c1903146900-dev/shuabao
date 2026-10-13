# Combined terrain exact-restore reuse candidate

2026-10-08 00:23 UTC. Source candidate; engine validation pending.

Pair05 failed during initial synchronous join save before sending any v2 full or reference payload. It does not test the new reference wire. Frame combine, save-state prevalidation and saved temporary main/backup validation all call the same CombinedStore through TerrainSession. Each call previously repeated semantic checking of the same 667-cell terrain.

The candidate keeps one successfully validated tuple per CombinedStore instance: exact scalar-tagged JSON encoding of the complete supplied terrain, exact scalar-tagged JSON encoding of the complete supplied world component, and world ID. It compares complete strings rather than a digest. Type and float-bit identity are retained by ExactScalarCodec. Every call still checks inputs_current and the original artifact type/node/depth/size gates before reuse. Any difference takes the original complete validation path; unsupported world encoding cannot be cached. Only a successful complete validation updates the tuple. Every result contains a fresh deep copy of the supplied terrain.

No save format, atomically committed bytes, acknowledgement, timeout, world generation, actor validation, or network protocol changes. Existing surface/entry semantics and regeneration prohibitions remain. The cache intentionally does not share mutable artifact trees between results.

Six candidate tests: the existing four contract/storage tests plus warm-cache exact-hit/copy isolation and row/type/checksum/world/configuration-change rejection. Timing and real New/Continue/F acceptance remain unestablished. Pair05's retained failure and all prior limited successes remain separate.

Actual bounded validation: tests02 passed all 6 cases in 35.017 seconds, peak 279650304 bytes, clean exit and full owned-tree cleanup. Two exact cache hits and independent returns were asserted. tests01 failed at Godot user-directory startup before tests; retained separately. No GUI save-time claim.

Pair06 real GUI reached welcome, consumed 156 snapshots and accepted native S/release/F10 cutoff sequence3 with pending0. Join save3.740506 seconds, compared with historical pair04 6.202621 seconds (not controlled benchmark). Server exited0 during F10, but guard then failed owned_process_escaped_session and terminated client before menu/receipt confirmation. 47.512 seconds, 703262720-byte peak, all owned cleanup. No normal F10/Continue pass.

Pair06 server report independently records normal_shutdown, saved/main_committed/complete true at sequence3, and full1/reference155 wire packets. This is server-side evidence, not client receipt/menu confirmation. Pair terminal guard candidate retains only seen exact pid/start identities after a unique held-pidfd terminal reproof; 25 Python tests pass and independent source review found no blocking issue. Actual re-run pending.
