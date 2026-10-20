# Visual13 portable delta

Base: visual11 PCK SHA-256 5539c9a50ed88c3db779297e73346e830611075e7f62a71b1cd99e74f959e271, 301578056 bytes. Restore the published source06-to-source09 plus visual11 chain first.

Run `python apply.py --base-pck VISUAL11.pck --output NEW_DIRECTORY`. All paths are relative. Existing output, mismatched preimages, unknown paths and non-unique replacements are rejected; the complete result PCK must match the pinned SHA. No game code executes during restoration.

This visual candidate changes exact minion material tags and Q1 fragment ink appearance only. It starts from visual11, narrows minion policy to the four observed material tags, and contains no diagnostic10/12 changes. Native status: VISUAL_NATIVE_UNRUN. Actual material tag hits and Q1 movement still require game validation. Historical maps and gameplay statements are preserved.
