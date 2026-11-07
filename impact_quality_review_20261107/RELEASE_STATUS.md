# R1 single-release wind burst candidate

Accepted baseline remains motion_combo15. Ground-star v1 and airborne v2 are preserved. V2 completed normal and northern-position presentation/pause/cancellation observations, but actual review found that isolated target cuts did not sufficiently convey a coherent burst after the hold.

This v3 retains the complete airborne entry/five connected edges/return/hold and target-contact drawing byte-for-byte. It adds one source-owned release sheet, exclusively from an admitted real r1_impact event. The event position, radius and direction define it. The open288-degree wind crest has a72-degree tapered rear gap, transparent interior, and no equally bright closed ring. It expands visually from.18R toR in.08 seconds and dissipates by.14 seconds. These are drawing times, not damage times or extra contacts. The existing single simultaneous damage event is unchanged.

The wind sheet stays at or inside the actual event radius, draws behind enemy bodies/health bars, and clips above the HUD. No new filled attack region, targeting, collision, immunity, clock, camera, input or source state is introduced. The v2 visible body/pause/cancellation implementation and.16-second body-hit lifetime remain unchanged. Its one real-event drawing call does not manufacture a release from elapsed cast age.

Overlay: star_performance_v3_changes/fengli_route_20261024. Builder: rebuild_20261106/build_r1_release.py. Pack SHA-256:9b9a2792a5d883f2c25069f6236df4c7392f9f8c8c043cb48459e0dc85edc934. Recovery starts from preserved combo15 and authorized original inputs, not redistributed assets.

Static inspection checked27,440 envelope cases and1,536 clipped quads. Actual whole-cast comparison r1release01 passed under unchanged protection:28 recorded frames include connected travel, return/hold, normal pause/resume, actual release, six true damage hits and empty terminal presentation. Real wave samples at ages0/.08/.12 seconds remain within source radius14; later samples contain no wave. Wall133.008157s, maximum sampling gap .184327 at startup3.045s (not the release), exit0/cleanup passed.

Actual sequence review finds a substantive improvement: hold then immediate source-centered release, quick outward expansion and disappearance connect the local hits into one burst. Enemies, defeat motion, HP bars and HUD remain readable. A single still frame can resemble a thin cyan bubble; the short expanding/fading sequence was reviewed rather than treating that frame as the whole action. This is not user aesthetic approval.

Exact-candidate shared UI run r1releaseui01 passed all11 checks: wall12.598283s, max gap .054087, exit0/cleanup passed. Full-floor run r1releasefull01 FAILED protection at wall35.081071s with max gap .292313 exceeding the unchanged .2 limit, before any R1 cast. Cleanup passed. It is not a completed floor, was not automatically retried, and does not permit promotion.

The prior v2 northern-origin/menu-new-run cancellation evidence remains preserved; v3 retains those underlying presentation/state rules but has not separately repeated every v2 scenario. All247 runtime files are sealed,245 seal entries verify, and only the three visual files plus generated seals differ from combo15.

Current status: preserved isolated v3 candidate, normal full-floor regression still required under trustworthy sampling conditions. Accepted baseline remains motion_combo15. Do not promote on short checks or visual review alone.

Only public-safe code, builders, bounded observers and aggregate summaries are included. No screenshots, raw logs, private source references, credentials or user conversation are uploaded.
