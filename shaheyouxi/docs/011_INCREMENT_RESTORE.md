# 011 cumulative source increment recovery

The complete accepted baseline is 010 Library version 9, identity libfile_d6bd92fba62c819186257151206493c0, file file_00000000725881f7a7a9ec2a296d0976. Its archive is 10,529,322 bytes, SHA256 425daf7cb9408c995a7bcbfbd04c64c8aa2677b85381916fdac3583bb8c725a8.

011 source increments use a separate stable identity libfile_8dcf95a771d48191a4026c4b7c5c26a8. Every version is cumulative relative to010 v9. Recover only the latest intended increment on a clean verified010baseline; earlier increment versions are not required and should not be stacked as a dependency chain.

1. Preserve any existing working tree before recovery. Validate archive hashes against the retained version records.
2. Inspect archive members before extraction. Reject absolute/traversal paths, links and special files. The010archive has one shaheyouxi_project root; increment members are relative to that project root.
3. Restore010 and verify all 4900 files listed in its historical RECOVERY_MANIFEST against archive member bytes. Git commands can refresh the local.git/index, so do not mistake that metadata refresh for corrupt archived bytes.
4. Apply the selected cumulative increment to the project root. Read INCREMENT_MANIFEST.json and verify every listed file SHA256. The increment contains source/docs/evidence, not runtime identities, private saves, Godot import caches or new.git object history.
5. source_commit in the increment manifest is provenance of the producing tree. A restored Git repository still has 010 history and will show modified/new source files; do not claim the producer's011commit object was restored. Record the increment identity/version/hash, inspect the diff, then make a new local reconstruction commit if continued work requires a frozen Git candidate.
6. Update the local backup record from the actually restored Library version. Historical registry rows inside the archive can point to its preceding checkpoint; do not infer the active version solely from that embedded row.
7. Cold caches and native runtime verification must be re-established only in an explicitly allocated software window. Historical tests from a replaced environment, and source-only review, do not validate changed/reconstructed source. formal_world_allowed remainsfalse.
