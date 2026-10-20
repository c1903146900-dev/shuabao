# Visual11 portable delta

Base: source09 rebuild PCK SHA-256 00e2180c6556b26ce0f74ad19e8005ff5243bbd1c424a514e87a218c289f28fe, 301573944 bytes. Restore the published source06-to-source09 chain first.

Run `python apply.py --base-pck SOURCE09.pck --output NEW_DIRECTORY`. All paths are relative. Existing output, mismatched preimages, unknown paths and non-unique replacements are rejected; the complete result PCK must match the pinned SHA. No game code executes during restoration.

This visual candidate changes exact minion material tags and Q1 fragment ink appearance only. It starts from source09 and contains no diagnostic10 timing. Native status: VISUAL_NATIVE_UNRUN. Actual material tag hits and Q1 movement still require game validation. Historical maps and gameplay statements are preserved.
