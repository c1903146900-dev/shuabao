# Diagnostic10 portable delta

Base: source09 rebuild PCK SHA-256 00e2180c6556b26ce0f74ad19e8005ff5243bbd1c424a514e87a218c289f28fe, 301573944 bytes. Restore the published source06-to-source09 chain first.

Run `python apply.py --base-pck SOURCE09.pck --output NEW_DIRECTORY`. All paths are relative. Existing output, mismatched preimages, unknown paths and non-unique replacements are rejected; the complete result PCK must match the pinned SHA. No game code executes during restoration.

This diagnostic adds bounded startup interval observations only with --trial-startup-profile. It is not a gameplay release or a measured performance improvement. Native status: DIAGNOSTIC_UNRUN. Nested intervals must not be summed; deferred warmup is outside this observation. Historical maps and original gameplay statements are preserved.
