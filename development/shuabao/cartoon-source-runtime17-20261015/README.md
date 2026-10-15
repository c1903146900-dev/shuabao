# Runtime17 source-only checkpoint
Dependency: runtime15 source checkpoint at commit cff1f21514a7b1003f89492ef68b9c65cf726e96, ../cartoon-source-runtime15-20261015.
Join archive.part000 through archive.part006 in order as candidate17_source_delta.tar.gz. Verify every part against ARCHIVE_PARTS.json and the complete archive SHA256 42942fa14339444bd23778cbc3b89e85339db0ebb5a9b1d9e257ffd40aad1250 before extraction.
Archive: 439751 bytes, 18 regular file members. Reject absolute/traversal paths and all links during extraction.
The archive contains 10 source payloads (6 replacements, 4 additions), relative maps, a hardened restore script and instructions. It reuses runtime15 artwork; no duplicate PNGs, cache, recordings, runtime logs or reference videos are included.
PACKAGE_FILES.json SHA256: 69630b1157eb2794c80815f3808a622482555b483e0b9c166e574eadb8f57bbd.
Follow the extracted README.md. Supply the exact previously restored runtime15 source tree and original runtime15 checkpoint archive. Restore validates both dependency archive identity and its complete 3142-file source map, then writes a fresh, disjoint 3146-file source tree. Existing outputs and symlinks are rejected.
Status: SOURCE_ONLY_NOT_RUNTIME_ADMITTED. This checkpoint does not include import cache, grant runtime admission, or establish complete gameplay/performance/animation acceptance.
