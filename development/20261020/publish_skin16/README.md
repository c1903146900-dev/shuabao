# Original-skin16 test baseline

Base: source09 PCK SHA-256 00e2180c6556b26ce0f74ad19e8005ff5243bbd1c424a514e87a218c289f28fe, 301573944 bytes. Restore the published source06-to-source09 chain first.

Run `python apply.py --base-pck SOURCE09.pck --output NEW_DIRECTORY`. All paths are relative. Existing output, mismatched preimages, unknown paths and non-unique replacements are rejected; the complete result PCK must match the pinned SHA. No game code executes during restoration.

This test-only baseline selects original 3D skins with --test-original-skin-baseline. Without the flag the original 2D presentation path is retained. The independent readiness receipt does not claim 2D or authority acceptance. It does not include motion14, visual15 or diagnostic12. Native status: VISUAL_NATIVE_UNRUN. Original skin restoration, source clock and game appearance still require native validation. Historical maps and gameplay statements are preserved.
