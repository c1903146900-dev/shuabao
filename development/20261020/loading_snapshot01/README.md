# Loading presentation — WIP snapshot 01

This source-only candidate adds visible loading stages and threaded resource requests. It has not been integrated or tested in the game engine. No reduction in total loading time is claimed.

## Contents

- `scripts/integration/hero_entry.gd`: replacement entry script; apply only to the exact preimage SHA-256 in the manifest.
- `scripts/integration/loading_status.gd`: new presentation and timing helper.
- `MANIFEST.json`: payload hashes and validation status. A null before hash means the file is newly added.

## Scope and limits

Stages describe resource requests, object instantiation, initialization, and first display. There are no estimated percentages. Instantiation and the synchronous `_ready` chain remain on the main thread and can still pause rendering. Threaded resource retrieval occurs only after the loaded status is observed.

Recorded post-draw times are rendering callbacks, not proof of operating-system presentation. The first usable observation is a readiness check, not a verified successful player action.

Existing confirmation cancellation and transition rejection boundaries are retained; this does not add cancellation during loading. Original recoverable resource failures remain recoverable. Successful initialization is still controlled by the game host.

## Required runtime checks

- Measure request, resource completion, instantiation, synchronous initialization, and first usable frame separately, for cold and warm runs.
- Verify repeated clicks, confirmation cancellation, return rejection during transition, and recoverable resource errors.
- During first display, verify the host preparation input guard remains effective after the entry state becomes RUN.
- Verify the loading presentation does not consume the original F10 or exit controls.
- Verify failed-load cleanup and subsequent attempts, and confirm stage text is actually visible in native captures.

Static source checks passed; engine parsing and all runtime checks remain pending. This fixed snapshot is for review and testing, not a release claim.
