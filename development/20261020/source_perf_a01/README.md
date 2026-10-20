# Source performance comparison arm A

Base: frame_profile_rebuild02, SHA-256 b1320d0e2779c7063baf526a0be471a1691795f8cba4d552b3573801f4a4bb32. Restore source06 → source07 → source08 → source09 → skin16 → frame_profile01 → frame_profile02 first.

This test-only arm adds three bounded opt-in profile labels. Autohex is not included. Native boundary and same-scene A/B acceptance are pending. Any later measured difference is a combined result; no individual optimization speedup is established. Nested timings must not be added.

Use python apply.py --base-pck FRAME02.pck --output NEW_DIRECTORY. Existing output, wrong base, mismatched preimages, unsafe paths and non-unique replacement are rejected. Final full PCK SHA is checked; no engine is run. Historical maps are unchanged.
