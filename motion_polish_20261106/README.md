# Motion polish checkpoint: 2026-11-06

Source-only overlay for the integrated motion_polish02 candidate. Preserve the four-script `combat_rebuild_20261106/changes` baseline, apply `rebuild_20261106/flow_next`, then apply these two files at their relative runtime paths. These files are not a standalone project; rebuilding also requires the restored runtime assets and refreshed binding hashes. Original baseline files remain unchanged.

Changes: continuous normal-attack ready/recovery endpoints and body weight shift; dash travel remains visible through actual source movement, followed by a short visual landing settle; dash-attack uses continuous thrust and recovery instead of overriding the motion with three abrupt poses. Original art, authoritative timing, direction, damage, cooldown, collision and displacement are unchanged.

Frozen integrated runtime SHA256: a13aa63a0a811b1a7b9fbe32a00357c66663c9e3be3f9c9633795f4a105f2793. CHANGE_PINS.json records both source hashes.

## Limited fresh verification

- Production loading, input-buffer boundaries, finite motion samples, matching attack endpoints and dash/landing assertions: 220 checks passed, exit 0 and complete process cleanup. The check script needs the normal boot/runtime dependencies.
- Final combined dash/attack and standalone-dash captures each sampled 60 chronological frames over eight simulated seconds using normal source combat and scripted normal actions. Runtime guard checks passed, exit 0, with complete cleanup. Visual review reported intact face/blade, continuous thrust/recovery, and landing after actual dash travel. These are sampled sequences, not 60 fps video or perfectly synchronized receipt/image evidence.
- The first standalone-dash capture exited abruptly and logged an ObjectDB leak warning. A repeat with normal run closure used the same production runtime, passed in 21.9276 seconds, and had no ObjectDB leak warning or SCRIPT ERROR/ERROR. Existing boot Unicode/NUL and platform VSync diagnostics remain.

This remains source-art cutout/mesh animation, not bespoke eight-direction animation. No subjective feel or user acceptance is established. Full-floor regression for this final integrated runtime is pending; earlier full-floor passes belong to the previous runtime. Windows and audio remain unverified. No release or adoption is claimed.

Only code and this summary are backed up here. Capture scripts with local paths, raw logs, frames, video, art and playable packages are excluded.
