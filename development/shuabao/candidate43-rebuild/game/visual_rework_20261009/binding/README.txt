Q1 free-curve successor binding — source preparation, not engine acceptance.

Exactly four existing resource changes are staged under postimages/. Copy these
onto a NEW composition project only. working_live02 and all historical sources
and manifests remain frozen. Copy the complete visual_rework directory there.

Run: python visual_rework_20261009/binding/seal_successor.py --project PROJECT
Run this after every final visual edit, not while another worker is still editing.
It refuses any inherited change outside the exact four before→after hashes.
Do not modify replacement_plan.json to admit accidental changes. A deliberate
additional change needs a reviewed, explicit successor amendment first.

The new bridge is the old live02 initializer verbatim except its Binding preload.
The new validator verifies the immutable live02 SHA, its inherited live01 SHA
and exact substitutions, all 1078 inherited pins, four exact replacements plus
preserved preimages, new helper/bridge/validator, and separate visual dependency
manifest. It keeps exact Sim, clock, director, capability candidates and hooks.
Old live02 validation still rejects new files, correctly. It is never disabled.

Visual manifest allows iteration without changing old gameplay manifests. Every
new visual source/resource is hashed; its manifest SHA is pinned in the successor.
This does NOT prove source parsing, graphics, native input, gameplay or artwork.

Required runtime evidence before acceptance:
1 Fresh single Sim/Session admits through new binding and bridge.
2 Old live02 validator rejects changed branch while original branch still passes.
3 Modified inherited unchanged file, four postimages, new helper, or visual
  resource each causes admission rejection; restore original bytes after tests.
4 Q1 actual baseline multi-bend input, 0.75s freeze, 11m ARC length freeze, moving
  hero fixed A, held-input frozen geometry, same-frame release, H01 length bonus.
