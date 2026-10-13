# 011 exact numeric persistence boundary (source candidate)

## Reason and scope
Two native runs preserved the failing bare-JSON evidence. Full-precision JSON still changed the observed food binary64 from little-endian 26778a51c3ff5840 to 27778a51c3ff5840, and two actor position leaves changed. Validation/restore succeeded before strict equality failed. The fix does not add epsilon or round live resources/positions.

SaveStore gains an explicit final constructor argument exact_scalars=true, selected only by 011 owners with a state validator and a nonzero byte ceiling. Existing constructors default false and keep envelope v1. No new globally registered script class, editor plugin, listener or RPC is introduced. Actual ENet session owner integration remains later work; current production-path tests exercise this SaveStore directly.

## Exact transport
Envelope v2 uses payload_codec=scalar_bits_le_v1. Its entire payload, including sequencing metadata and world clocks, is encoded as a tagged basic tree before JSON. Integers are signed64, floats finite IEEE754 binary64; both are fixed eight-byte little-endian lowercase hexadecimal. Negative zero retains its sign bit. Actual gameplay validators remain responsible for narrower legal integer/resource ranges. No Object/Resource/Callable/RID/packed-vector deserialization exists.

Every node has a strict tag/payload pair. Dictionary payloads are arrays of String-key/node pairs; duplicate keys remain visible and are rejected. Limit64edges of depth and100000value nodes bounds codec recursion/work; original file byte limit is unchanged. Unknown tags, types, malformed hex, nonfinite floats and duplicates fail closed.

Outer envelope and encoded payload must be canonical JSON. Outer version is produced as exactly representable float2.0 so its own JSON parse/re-encode has stable numeric representation. Outer duplicate keys or foreign fields are rejected. The original payload SHA is verified before decoding. This hash is integrity detection, not a network trust/authentication mechanism.

## Write/read policy
The existing state validator runs before write and again after temporary-file readback. Temp-write, flush, validate and atomic rename order remains. Encode failure never promotes an empty file. On load, successful exact decode is followed by original project/epoch/schema/world/authority/actor validation. Unknown/mismatched codec/version does not fall back to old backups. Existing envelope v1 is not migrated to v2; user-directed old-save policy remains the planned011.5 responsibility.

## Verification boundaries
Original strict equality checks now traverse the same codec; additional actual SaveStore create/write/close/reopen checks require entire state equality plus recursive type and float-bit equality. Negative cases retain an older valid backup and verify no fallback/no rewrite for unknown codec, mismatched version, invalid node and duplicate outer key. Old bare-JSON failures remain recorded, not relabeled as passes.

All new codec/SaveStore tests and changed model tests remain unrun until an allocated engine window. This does not establish networking, native collision, GUI or full011 acceptance. Existing v1 SaveStore/lock/world-save regressions must be run separately before accepting this shared implementation change.

Independent integration review found that size-only outer validation could misclassify an unknown replacement checksum field as recoverable corruption. Fixed with a complete five-field whitelist before hash checks; added a real-main/older-backup negative case. This correction is source-only pending runtime.
