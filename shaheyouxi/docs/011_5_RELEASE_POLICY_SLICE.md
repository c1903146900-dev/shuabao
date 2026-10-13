# 011.5: standalone release proposal and old-save planning slice

Status: packaging-side, pure Python only. This is **not complete 011.5**, a formal
release, a loader gate, a migration implementation, or joint 011–013 acceptance.
The existing `package010.py`, SaveStore, scene owners and save schemas are unchanged.

## Source reconciliation

| Source / identity | Meaning in this slice |
| --- | --- |
| Recovered Library `010 v9` | Archive/recovery version, never a game Build |
| Cumulative Library `011` archive (e.g. earlier `v113`) | Archive/recovery version, never a game Build |
| `tools/package010.py` | Existing Linux technical package; `formal_world_allowed=false`, no formal release identity is assigned |
| `world_network_main.gd::_make_save_store` | Actual 010 world save schema **2**, envelope **1**, no `payload_codec` field in its envelope |
| `actor_network_main.gd::_make_save_store` | Actual 011 combined actor save schema **3**, envelope **2**, `scalar_bits_le_v1` |
| `save_store.gd::_encode` | Both paths emit `development_unreleased`; `game_version`, `build_id` and `build_number` are **null** |

SaveStore's class default schema 1 is not the world owner's schema 2 or actor
owner's schema 3. This planner recognizes these two legacy contracts and the explicitly separate schema4 terrain contract.
The explicit new schema4 technical entry adds authority/world/actors/terrain with envelope2 and the same exact codec; the original schema2/3 entries remain unchanged.
It does not parse their envelopes or infer formal identity from a filename, archive
version, scene number, content hash, or technical package manifest.

Policy source: `docs/011_RECONSTRUCTION_REQUIREMENTS.md`, “Save and policy”.
Each proposed formal package has independently chosen visible `game_version` and
unique internal Build. The visible version may stay unchanged. `allow_old_saves`
must be an explicit user choice, with no default and no truthiness coercion.
The supplied boolean is a policy declaration; this pure module does not itself
verify that the user selected it or grant permission to publish anything.

## API and bounded descriptors

Only `tools/release_policy0115.py` provides runtime code:

- `ReleaseSpec`: a frozen dataclass with every field required, or its exact dict
  equivalent accepted by the functions
- `validate_release_spec(spec, known_builds)`: validate a **new proposal** and reject
  any Build already present in the supplied index, even when metadata is identical
- `plan_old_save(saved_descriptor, target_spec, known_builds, compatibility_chain)`:
  describe the remaining gates or refuse; never authorize loading or writing

A ReleaseSpec has exactly these fields:

`spec_version`, `kind`, `game_version`, `build_id`, `allow_old_saves`, `project_id`,
`save_epoch`, `save_schema_version`, `envelope_version`, `payload_codec`,
`id_semantics`, `content_sha256`, `required_components`.

A saved descriptor has the same identity/contract/hash fields, but replaces
`spec_version`, `allow_old_saves`, `required_components` with
`descriptor_version`, `payload_sha256`, `components`. It is a **local, detached
description**, not a new disk format, a decoded payload, or an assertion that the
save's bytes have been checked. No adapter from existing saves is implemented.

Technical choices below are implementation limits, **not original gameplay rules**:

- Both descriptor versions are integer 1. Integer fields reject booleans and
  floating-point equivalents. All mappings have exact whitelisted keys
- A visible version is 1–64 printable Unicode characters and cannot be all spaces;
  Chinese labels and ordinary embedded spaces are supported. It is not parsed as
  semantic versioning, and no version ordering is inferred
- `build_id` is the single internal Build token in this proposal format. Its local
  syntax is `build_` followed by 1–58 ASCII letters/digits/underscore/hyphen, with
  an alphanumeric first suffix character. No Build number is generated or inferred.
  The current SaveStore's extra null `build_number` is not converted into an ID
- `kind` is `formal` or `development_unreleased`; the latter requires both version
  and Build to remain null. All formal examples in tests are synthetic fixtures
- Only project `shaheyouxi_experiment_20261004`, epoch `shaheyouxi_20261004`, and
  local ID-semantics label `separate_content_instance_event_v1` are known. The label
  names the existing separation of content, instance and event IDs for review;
  it is not a field already written by SaveStore or proof of an ID compatibility audit
- Hashes are exactly 64 lowercase hexadecimal characters. `content_sha256` names
  the descriptor's source/content revision digest, corresponding conceptually to
  SaveStore's content revision. It is not a semantic compatibility fingerprint.
  `payload_sha256` and chain evidence hashes are syntax-checked, never authenticated
- Envelope/codec pairs are fixed: schema 2 uses envelope 1 and descriptor codec
  null (the actual envelope omits it); schema 3 uses envelope 2 and `scalar_bits_le_v1`
- Semantic component inventory labels are `authority`, `world`, `actors`, `terrain`;
  they are not literal field names in the saved state. Schema 2's actual inventory
  must be exactly authority/world; schema 3's exactly authority/world/actors; schema4 adds terrain
- A target may describe terrain as an additional **future requirement**, for schema2/3, which do not implement it. Schema4 is the separate explicit terrain-bearing contract, not a reinterpretation of schema3. A schema-3 save without terrain is refused when
  the target requires terrain, including the same-Build case. A schema-3 descriptor
  claiming terrain already exists is also refused as an unrecognized inventory.
  Supporting it would require a separately reviewed schema/contract and a real
  migration path; no component is synthesized, generated or filled in
- `known_builds` is a dict of at most 1,024 Build tokens to exact formal ReleaseSpecs;
  keys and recorded IDs must match. Uniqueness is **only against that supplied
  index**, whose provenance and completeness remain unverified. There is no global
  registry write, Build reservation, allocation, or race-safe publication here
- A chain is a list of at most 64 exact links, each containing `from_build_id`,
  `to_build_id`, `kind` (`direct` or `migration`) and `evidence_sha256`. It must be
  ordered, acyclic, fully bound to indexed Builds (plus the proposed target), and
  reach the target. Intermediate old-save policy cannot be silently bypassed

## Fail-closed dispositions

All planner reports have `load_allowed=false`, `write_allowed=false`,
`compatibility_verified=false`, `chain_verified=false`, `payload_verified=false`,
`migration_route_available=false`, and `automatic_backup_fallback=false`.

- `requires_direct_validation` means only that a structurally coherent request can
  be sent for review. Its required gates include checking the descriptor against
  the original envelope and payload, authenticating Build/index identity, full
  state/content-ID/component/runtime validation, and checking every claimed chain
  evidence item for different Builds. No hash or caller declaration completes a gate
- `refused` carries a specific code for the first failed requirement. Unknown
  schema/epoch/project/ID semantics, malformed fields, missing/unordered chains,
  unknown Build identity, disallowed old saves, missing components, and unsupported
  conversion are refused without fallback or mutation
- There are **no migration routes**. Even a caller-provided `kind=migration` link is
  refused as `MIGRATION_ROUTE_UNAVAILABLE`. This slice deliberately never returns
  `requires_verified_migration`, because doing so would imply an available route
  that has not been implemented

`verified:true`, whether added to a specification, saved descriptor or chain link,
is an unknown field and refused. A correctly shaped evidence hash is still only a
reference to evidence that this function has not read. Thus even a complete
syntactic chain remains fail-closed and cannot be passed to the actual loader as
authorization.

Ordinary balance/text/additive changes may change `content_sha256` without changing
schema/epoch/ID semantics. With a complete declared direct chain, such a difference
requests validation and is **not automatically classified as incompatibility**.
Conversely, same-Build metadata must match its registered identity exactly.
Development saves have no formal Build lineage; they cannot enter a formal target.
Identical development contract/revision descriptors may be reviewed only under
explicit true policy; changed development hashes are refused for unverifiable
lineage, not asserted to be semantically incompatible.

An already indexed target can be planned only when its entire ReleaseSpec matches
the index. This is distinct from validating a new package proposal, which always
rejects Build reuse. Explicit `allow_old_saves=false` does not reject an exactly
matching current formal Build, but never bypasses component or full-state checks.

## Checks and remaining work

Run the focused suite without creating bytecode:

`PYTHONDONTWRITEBYTECODE=1 python3 -m unittest tests.test_release_policy0115 -v`

Coverage includes same visible version/distinct Build, duplicate Build, omitted and
non-boolean policy, strict shapes/types/bounds/hashes, the actual 010/011 contract
pairs, unknown contracts, incomplete chains, untrusted verification claims, changed
content digests, development identity, terrain refusal including same-Build and
invented-terrain cases, truthful absence of migration, and input immutability.

Fresh Python-only check on 2026-10-06: 29 policy tests passed, plus the 6 existing
`tests.test_package010` tests (35 total). A separate 390-case alternate/malformed
field smoke check returned bounded reports without exceptions and never allowed
loading or writing. These checks do not establish Godot/runtime or formal-package
acceptance; no engine was started.

Remaining 011.5 work requires separately authorized design and implementation:
authoritative user policy/provenance, real registry and package manifest linkage,
original-byte descriptor extraction, completed compatibility evidence gates, actual
loader integration, any new save schema, immutable verified pre-migration backup,
temporary conversion and full validation, atomic promotion, and failure/cancel/
interrupt restoration preserving the original save and old Build. No such work or
formal Build assignment/publication is performed by this slice.

## Explicit schema4 entry extension

The independent technical schema4 entry stores authority/world/actors plus the complete typed terrain component under envelope2/scalar_bits_le_v1. Proposal planning now recognizes that exact inventory; schema3 cannot claim terrain, schema4 cannot omit it, and 3→4 has no automatic migration or generation route. All planner permission/verification flags remain false. The new runtime source and its file gate are tracked in 011_SCHEMA4_TERRAIN_SAVE.md; recognizing the descriptor is not runtime acceptance or a formal Build assignment.
