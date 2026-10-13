# Narrow two-entry frontdoor successor, planned only

SOURCE ONLY. R and S have not been changed by this author; no engine/CUA/Blender was started. The new entry binding needs its own parse/lifecycle evidence. The green ordinary146/four-group result does not cover these new entry bytes. Default clicking, graphics warmup, window-close signal handling and native play remain separate/unverified.

## Exact two-line change plan

`planned_entries.json` and `planned_default.patch` are the reviewable whitelist. Full planned files are provided, but only one line changes in each target:

- `scripts/integration/yanguizhou_first_floor.gd`: first `extends` line moves from the R2 Host to this frontdoor Host. BeforeSHA `55b2863eb27215aa8fd113fdec296b88fa450e297312280fb19a506cd788bc29`; afterSHA `66183f90b6264f8b3f5f24348879968ed931b52c52b7cdb5c9fddb7db0ad2f13`
- `scripts/ui/hero_chooser.gd`: only `InkRuntimeText` moves from R2's runtime text to the unchanged green ordinary runtime text. BeforeSHA `d281f2f909c40e39a432557c1df146717e703426f09a867255dc064e34dc38ad`; afterSHA `a952aab7c78c1e8c604485a84d20b63d23c1eb4f7101aae0c038cbc4f6d104bc`

The adapter's complete remaining body and the chooser's complete remaining body, including all other hero branches, are byte-exact. No scene destination changes. The planned files are not applied to R or S by the source verifier.

## Why a narrow successor is necessary

The green ordinary runtime map pins both old entry hashes. A direct two-line cutover would invalidate its Binding, so this new Binding explicitly replaces only those two known before hashes. Every other parent map entry remains unchanged; the fixed parent manifest is verified; every mapped file, including this Host/Bridge/Session/navigation and planned entries, is SHA-verified. Static negative checks require exact whitelist cardinality, allowed paths, before/after relations and the unconditional full-map hash loop. No broad ancestor exemption is added.

The green ordinary Host already inherits the R2 production adapter. Placing another full adapter above it would duplicate frontdoor fields. This new Host preserves the ordinary Host's whole body but bases it on the R2 Host directly, with only Session/navigation/Binding paths rebound. The planned actual entry retains the one original frontdoor body above that Host. There is exactly one frontdoor layer.

The Sim remains `ordinary01/sim.gd` with the same script identity, derived from the passed H03/H04 ownership runtime. Original green Sim, Host, Session, UI, router, view and all gameplay source files remain frozen. New Session/Bridge/navigation copies reverse to their green bodies by undoing only binding/factory paths. Catalog/capability ceiling remains the same12 hooks and same candidates; P3 stays locked.

`ordinary_entry_ready=false` is the pre-existing candidate-scope field, retained from earlier bindings. It is not read by the chooser, Bridge or Session admission flow: chooser entry uses its unchanged `ROOMS`/`can_enter`, and Session uses the admission result's `accepted`. The finite gate checks that this field stays false while actual Session initialization/row entry succeed. It is not silently changed into a final readiness claim.

## Minimal gate, not a mechanics rerun

`finite_host.gd` inherits the actual temporarily staged default adapter path. It skips graphics warmup and replaces only the heavyweight diagnostic capture sink with a countable stub. `lifecycle_gate.gd` reuses the existing ordinary Host/Session setup helper, with only the Host constructor changed. Two groups check exact entry hashes/new admission/unchanged Sim and other hero availability, then real mandatory selection/Q2 learning/room entry and method-level suspend/resume/close idempotence. Original marker, clock, Session/ledger/director identity and teardown are checked. No full gameplay matrix, scene warmup, native click, render acceptance or file-capture proof is claimed.

## Temporary stage aliases and guaranteed normal-red restoration

`stage_alias.py` preflights the current parent stage, preserves both exact entry preimages in a new backup directory, adds only this candidate's files and temporarily replaces only the two whitelist entries. Copy/verification failure rolls the two entries back immediately. The new candidate binding is valid only while those after hashes are staged.

The coordinator must place its EXISTING guarded parse/lifecycle loop inside `stage_session.two_entry_aliases(stage, evidence_dir)`, after its existing software admission and evidence-directory creation. This narrow context manager uses `try/finally`; it does not launch/manage engines or replace the resource guard. The finally runs for green or red gates, requires the guard's actual exit/reaped/empty-group receipts and calls exact-preimage restoration. It writes `stage_alias_applied.json`, an actual `entry_preimages/BACKUP.json` plus both full files, and `stage_alias_restored.json`. Restoration rehashes the entire previous parent map, not just the two entry strings. Candidate files may remain additively in S, but its new entry binding is no longer admitted after restore.

If no process was started and no exit receipt exists, do not infer cleanup from missing evidence: the coordinator can explicitly restore using `--no-engine-started`. Unexpected unrelated changes to either entry are never overwritten. These tools do not modify R.

Coordinator calls, once a window is granted:

1. Preflight: `python3 .../frontdoor01/stage_alias.py --stage <S> --receipt <preflight.json>`
2. In the existing guard, use `with two_entry_aliases(S, O):` around its existing two-process loop. Its labels remain `parse` and `finite`; select `parse_gate.gd` then `lifecycle_gate.gd`, both in this frontdoor directory, with `--river-frontdoor-result=<O/result.json>`
3. Run local `raw_error_gate.py` with the normal parse/finite raw/exit/result arguments plus `--restore-receipt <O/stage_alias_restored.json>`. Strict PASS requires restored original entry hashes and complete old map in addition to error-free lifecycle evidence

Standalone alias apply/restore commands are available for recovery, but the normal two-process attempt belongs inside the context manager. Existing namespace, reaping, empty-group and384MiB/60s/512-128 limits remain owned by the current coordinator guard. No window is authorized by this README.
