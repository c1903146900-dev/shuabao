# Diagnostic12 portable delta

Base: diagnostic10 PCK SHA-256 44c6727ed9800f43b8edfb98c93f3fb4801739ea9d521e2580604069b74b9f32, 301620640 bytes. Restore the published source06-to-source09 and diagnostic10 chain first.

Run `python apply.py --base-pck DIAGNOSTIC10.pck --output NEW_DIRECTORY`. All paths are relative. Existing output, mismatched preimages, unknown paths and non-unique replacements are rejected; the complete result PCK must match the pinned SHA. No game code executes during restoration.

This candidate retains diagnostic10 startup observations and makes developer report output opt-in. Use the same --trial-startup-profile flag for A/B; diagnostics default off. Other caller argument evaluation costs remain. Explicit diagnostics and F8/F9 export require native testing. It is not a gameplay release or a measured performance improvement. Native status: DIAGNOSTIC_UNRUN. Nested intervals must not be summed; deferred warmup is outside this observation. Historical maps and original gameplay statements are preserved.
