# Visual17 portable delta

Base: visual15 PCK SHA-256 62baea1172b0892cdbbf553cf9b988b98f489948c42554930993f679db1d50d7, 301581560 bytes. Restore the published source06-to-source09 plus visual11, visual13 and visual15 chain first.

Run `python apply.py --base-pck VISUAL15.pck --output NEW_DIRECTORY`. All paths are relative. Existing output, mismatched preimages, unknown paths and non-unique replacements are rejected; the complete result PCK must match the pinned SHA. No game code executes during restoration.

This visual candidate changes two exact minion material tags in one script from visual15. It does not include motion14, diagnostic12 or the skin16 test branch. Native status: VISUAL_NATIVE_UNRUN. Actual minion material values and game pixels still require validation. Historical maps and gameplay statements are preserved.
