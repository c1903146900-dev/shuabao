# Q3 溪山行旅 / H05 重峦 / H06 山崩: isolated mechanic foundation

Source-only authoring, above the exact a79fc intermediate-stat Sim/Bridge chain.
No Godot, Blender, import, browser/CUA, Library, host edits, production rewrite,
art assets, or capability promotion were performed by this author.

## Source and declared conventions

`source_contract.json` independently binds original DOCX paragraphs 71/93/94,
14 parameter IDs and 74 original numeric workbook cells. The reviewed G18 map
already names `mountain_raise_burst` and `mountain_collapse`; Q2's three held
rules remain unchanged. All relevant existing input/hero/common/commerce
sources are frozen before authoring.

The parent technically confirmed the implementation conventions in
`implementation_conventions.json`: the point is the mountain center; its long
axis is perpendicular to caster→point and exposed by `q3_preview`; coincident
point uses the last valid facing; actual raise starts cooldown; live recast
reuses the same root, bypassing only its cooldown. These are adjustable
implementation choices, not falsely quoted source rules or user playtest
acceptance. Existing .35-second knockback transport is explicit tuning and
adds no standalone stun. H06 alone adds its exact .8-second stun.

## Mechanic scope

- Six-rank range, raise damage/size/lifetime, collapse rectangle/damage/push/CD
  are loaded from the existing source parameter adapter
- H05 changes mountain length only; neither Q3-7 length nor Q3-8 collapse width
  is enlarged. H06 acts only on collapse hits, with shared tenacity and no
  invented Boss stun immunity. Existing Boss push immunity is retained
- Birth and collapse are exact finite-width rectangle/circle contacts. The
  collapse points from the existing mountain to the current manual mouse
- A selected Q3 call passes through the inherited transaction/action/cast
  service. Recast shares its original identity, G25 budget and completed-cast
  lifecycle; existing damage/crit/lifesteal/mitigation/common pipeline is reused
- Ordinary movement (including pounce, push and pull through inherited methods)
  is clipped against the mountain. Elite/Boss movement, players, friendly
  projectiles and existing Q1 paths are not newly blocked. Ordinary actors born
  overlapping terrain can reduce penetration without an unsourced ejection;
  they cannot tunnel deeper through it
- Actual director bolt, hex_bolt and lob families are swept before interception.
  A nearer existing wall or player hit keeps its original outcome. Blocked lob
  entities cannot create their original landing zone. Already-landed enemy zones
  are not projectiles and remain unchanged. No invented aerial exception
- Source-time lifetime follows inherited actor time, including fractional-tick
  contact/expiry order. Pause/hitstop freeze terrain. Natural expiry causes no
  collapse damage. Cancellation, death/room reset and rebuild invalidate terrain
- Debug snapshot/preview are detached neutral geometry data, not authored VFX

The new `ink_q3_bridge.gd` differs from its frozen original in only its exact Sim
path admission. It retains the existing model, adapter, HP journal, ledger and
six common hook consumer. Q3/H05/H06 are deliberately absent from public catalog
and capability admission. Finite tests select the candidate directly. This is
not an ordinary entry or first-floor promotion.

## Finite verification owned by main

1. `python tests/ink_q3_foundation_20261004/verify_source.py --write` freezes the
   authored candidate once; without `--write` verifies the stored binding
2. `python tests/ink_q3_foundation_20261004/prepare_stage.py --dest <new-empty-dir>`
   materializes only bound sources, starts no engine and never reuses a stage
3. Main runs serial finite gates under its resource guard:
   - `q3_gate.gd`: six ranks, both personal Hex, source semantics, actual enemy
     families/IDs, exact rounded geometry, clocks, one-root budgets, callbacks,
     before/after Q1/H01/H02/BASIC/Shift event and state parity; narrow Q3
     raise/recast actual-stun, pause, stale-generation, actual-death rejection
     and live WASD acceptance
   - `q1_regression_gate.gd`, `control_regression_gate.gd`, `h02_regression_gate.gd`
   - `common_regression_gate.gd`, `hp_regression_gate.gd`
4. `inspect_engine_results.py --stage ... --runs ...` checks actual complete logs,
   exit codes, terminal reports, case completion and unchanged staged hashes

`regression_rebindings.patch` preserves every inherited test assertion, changing
only explicit candidate paths, report identity and result destinations. Existing
results are not reused. Source verification is not Godot syntax/runtime proof.
Full 11 Ink skills, 16 personal Hex, all 30 common Hex, ordinary controls/art,
12-row first-floor/Boss, Windows, balance and user acceptance remain separate.

`source_draft01/` preserves the pre-admission-addendum authoring draft and its
unrun source binding; it is excluded from the final runtime stage.
