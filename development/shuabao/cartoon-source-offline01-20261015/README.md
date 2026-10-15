# Cartoon source-only compact backup

Join the numbered parts in SOURCE_ARCHIVE_MANIFEST.json order to reconstruct cartoon_source_delta.tar.gz. Verify each SHA256 and the complete archive SHA256 before unpacking. The archive contains only regular relative-path files under cartoon_source_delta/; do not accept symlinks or traversal members. Then read the inner README and use its exact source-restoration command with the package_files_sha256 from this manifest.

This package reuses the already public G23 source base linked in the manifest. It contains exact source deltas, a separate compact-scholar14 overlay, and the independent offline art fixture. It excludes generated caches, actual run evidence, private paths, reference video and footage. Source restoration is not runtime admission, final art acceptance or realtime performance verification. No engine is launched by the restoration script. The actual offline clip published separately is a staged art preview, not gameplay FPS.
