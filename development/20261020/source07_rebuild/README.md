# Source07 rebuild portable delta

This is the new source07 rebuild based on the recovered source06 trial package, not historical source07 or source47. It changes only the two UI files and their three exact binding seals. Native UI and engine acceptance remain unverified.

Base: source06 canonical PCK, 301521120 bytes, SHA-256 `77f747f6f68b970042f2f184de660afd812f2320cf03c6d127e244b68cbc119a`. Keep this original package.

Run `python apply.py --base-pck BASE.pck --output NEW_DIRECTORY`. The script validates the complete PCK, all payload hashes, and every changed-file preimage before writing a new directory. It refuses existing output paths and does not execute game code. It preserves every original resource and writes a deterministic canonical PCK beside the recovered source. The resulting PCK SHA must equal the manifest.
