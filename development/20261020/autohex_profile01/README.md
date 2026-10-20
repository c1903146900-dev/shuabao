# Auto-Hex no-pending performance comparison

Exact chain: source06 -> source07 -> source08 -> source09 -> skin16 -> frame_profile01 -> frame_profile02 -> this candidate. No visual13 branch or boat admission is included.

Base PCK SHA-256 b1320d0e2779c7063baf526a0be471a1691795f8cba4d552b3573801f4a4bb32. Result PCK SHA-256 b1cc8d89aebeed245f5b7da5b2ea615225823bd74338545075e7e26cde3e7d82.

Run `python apply.py --base-pck FRAME_PROFILE02.pck --output NEW_DIRECTORY`. All inputs and final bytes are checked; existing output and mismatched preimages are rejected.

This test-only comparison preserves the eight timing labels. Its single gameplay-path change removes a repeated pure pending predicate only when there is no pending choice, while retaining HUD clearing. Pending and active branches retain original behavior. A fixed C03 successor verifies only this exact controller before/after and real preimage through the full P3 gate; old contracts remain byte-identical.

Native boundary tests and actual same-scene CPU benefit are not yet verified. Earlier frame02 produced valid28 timing rows but retained its screenshot-count guard failure; it is not an overall acceptance result.
