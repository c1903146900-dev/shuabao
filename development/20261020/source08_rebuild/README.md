# Source08 rebuild portable delta

Apply only to the exact source07 rebuild PCK: SHA-256 f5d8b2e8cef38cdae67fe91c8612726cb7ceec03e2ea79e879187d7cd75e4c4d, 301528916 bytes. Reconstruct source07 first using its published source06-based delta.

Run `python apply.py --base-pck SOURCE07.pck --output NEW_DIRECTORY`. Existing output, mismatched preimages and ambiguous replacements are rejected. This delta changes the Catalog scalar access implementation and exact source admission, preserving historical maps and UI07. It is unrelated to historical source08 or source47. The Catalog has independent formula microtests; integrated engine behavior and frame-rate improvement remain unverified. No game code is executed by the restoration script.
