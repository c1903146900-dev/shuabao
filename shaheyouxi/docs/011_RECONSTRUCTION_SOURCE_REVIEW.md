# Independent source review of reconstructed011

Reviewed 34fd7ae and narrow fixes 2c4e7a1 read-only. No engine execution or test pass is implied.

## Findings and source-level disposition
1. P1 integration blocker: ActorState.error exposed category/corruption, while SaveStore._read consumes recoverable_corruption:false to stop incompatible-main fallback. Fixed by adding that exact field for non-invalid-data failures. New ActorSaveBoundaryTest cases write an unknown-schema or unknown-source main with a valid automatic backup and require load refusal, no fallback and LOAD_REQUIRED on attempted overwrite. Tests unrun.
2. P2 revision boundary: restored revision2^53−1 could be incremented into a self-invalid snapshot. All mutation/commit entrypoints now refuse exhausted revision before changes; preview also refuses unusable active transactions. New maximum/maximum−1 atomicity tests unrun.
3. P2 death boundary: health_anchor_value0 with stored health5e−10 passed near-number tolerance and could permit F before next tick. Validation now requires stored/derived health to agree on zero-versus-positive before numerical comparison. Regression unrun.
4. P3 clarification: redundant released events intentionally idempotently clear/retain false without generating pressed edges; move/aim in the same envelope remain independent input, as with action none. No identified authority/resource replay effect. Added explicit regression, unrun.

The independent reviewer re-read all three fixes and found their narrow source changes consistent, with no newly identified partial commit.

## Confirmed source properties, not runtime claims
Input whitelist and typed validation; provenance/hash-bound parameter consumer; analytical resource anchors; food threshold/death segment splitting; oversized-clock refusal; all-candidate validation before mutation; stale preview rejection; public whitelist; restore validation before replacement and inactive restored sessions.

## Remaining integration and verification debt
- Native joint CCD, actual position commit and layer transfer remain unimplemented.
- Actual loaded-layer/fallback membership and occupied reconnect position require world/physics validation beyond syntactic layer validation.
- Authenticated RPC entity mapping, actor/world common clock and combined atomic save remain unimplemented.
- Physics-ready startup must precede listen/save.
- At revision exhaustion, failed deactivate cannot be ignored by owner: close the service and dispose all input/colliders, or implement a separately reviewed non-revision cleanup path. No network owner currently calls this model.
- JSON restored layer.depth numerical normalization and complete roundtrip must be tested in Godot; not declared broken or passed by inspection.
- Temporary no-offline food/energy settlement is a technical unresolved policy boundary, while absolute server-clock cooldown semantics follow the confirmed original rules.
- All79current GdUnit methods remain unrun. Historical59 from lost source is unrelated.
