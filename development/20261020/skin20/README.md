# Skin20 head-only shape candidate

Base: skin19 PCK SHA-256 71316dbd3a250fdcecbd1717ce0a170a5b0d1ab71d745c48429e8480a275a2fb, 301591700 bytes. Restore the published source06-to-source09 and skin16/skin19 chain first.

Run `python apply.py --base-pck SKIN19.pck --output NEW_DIRECTORY`. All paths are relative. Existing output, mismatched preimages, unknown paths and non-unique replacements are rejected; the complete result PCK must match the pinned SHA. No game code executes during restoration.

This candidate uses --test-original-skin-headshape for startup-only head-family geometry changes on independent display copies. The unshaped-copy and original-baseline selection remain available. It targets Godot 4.6.3 internal _surfaces storage, which is not a stable public API; engine/layout checks must remain exact. No material18 changes are included. Native deformation, binding, shadows and visual quality remain untested. The independent readiness receipt does not claim 2D or authority acceptance. It does not include motion14, visual15 or diagnostic12. Native status: VISUAL_NATIVE_UNRUN. Original skin restoration, source clock and game appearance still require native validation. Historical maps and gameplay statements are preserved.
