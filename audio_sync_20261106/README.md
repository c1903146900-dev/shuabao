# Shift audio classification checkpoint

Source-only audio_sync01 overlay after the complete hit_feedback02 baseline. Apply audio_policy.gd at its relative runtime path and regenerate binding metadata. Earlier overlays and assets are required; this is not a standalone project. Prior versions remain unchanged. Runtime SHA256: c99305b1a1138d6b8e4a77edb2248ce8012958f4ebeec4ac62085fee338011bc.

The original policy did not classify normal Shift dash events. This narrow change maps a valid current dash to the existing blink_move sound bank with its own per-cast claim, validating dash ID and duration. No new WAV files, volume changes, voice/rate-budget changes, or combat/timing changes are included.

## Verification and limits

- Production loading and 118 policy checks passed, including malformed/replayed event rejection, separate claims and source immutability.
- The audio device could not open, so the engine fell back to Dummy. Verification recorded actual engine Master-bus stereo PCM at 44.1 kHz, not speaker/headphone listening or physical-output acceptance.
- In the isolated dash window, baseline PCM was all zero. After the change it contained 14,008 nonzero samples, peak 0.0310669 and RMS 0.00201706. Existing attack/impact transients remained, and no sample clipped. Recording alignment does not establish hardware latency or subjective sound quality.
- Pause/resume, duplicate-consume and mute checks passed without resuming a stale cue. A sampled post-resume window was silent; this does not prove an audible cutoff because that dash was stopped before reaching the captured mix.
- Baseline, changed-audio, policy and lifecycle runs all exited with code 0 and complete cleanup. Device fallback diagnostics remain part of the test limitations.

Full-floor/UI regression of this exact runtime is pending. Windows, physical audio output, subjective timbre/loudness and user acceptance remain unverified. Only source, test, hashes and this summary are included. Recordings, capture scripts, raw logs, device details and sound assets are not published.
