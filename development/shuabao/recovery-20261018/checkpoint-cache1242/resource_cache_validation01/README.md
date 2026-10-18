# Official cache subset preservation

35 ordered binary parts reconstruct official_cache_98.tar.xz (36192656 bytes; SHA256 28b6fa7b0d9be2c38314d6aa32a28fbb2e2ce9bd8204f406c93feabf08504691). PARTS.json pins each part and the internal manifest. The supplied restore tool checks all parts, the archive, the exact 99 regular safe members, and all 98 cache hashes before writing a fresh output. Use only a fresh trusted directory; it does not execute downloaded game code.

USABLE_CACHE_MANIFEST documents 196 current ResourceLoader loads and three rendered frames for the exact resource/source hashes. This does not make the original import run a pass: original sidecar/project changes caused import rejection. The selected cache subset was validated separately against original descriptors. ALSA fallback and UID warnings remain explicit; audio, full game, animation and Windows acceptance are not claimed. Source sidecars/project are not included or overwritten by this archive.
