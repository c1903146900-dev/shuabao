# Ordinary chooser and tooltip correction

Presentation-only successor to native-tested b0c0. The exact Sim, four mechanism
layers, input adapter, numbers, curves, Catalog, Design and source documents are
unchanged. preimage_native01 stores the 27 prior source files plus their hashes.

The chooser note, chooser skill line and runtime scope read the existing
Catalog's admitted candidates through one small runtime_text helper. They now
include E2/P1 and the effective rest rule: full HP, clear Buffs/cooldowns, no base
bottle refill. Other heroes' notes remain unchanged. The unlearned Q prompt also
derives its Q candidates from that same list, including Q2.

Only the exact obsolete implementation sentence is replaced, only for admitted
skills. Source audit found it in Q1, E1 and P1 descriptions; Q2/R1/E2 currently do
not contain it. Existing cards and growth controls are corrected after their
normal refresh, keeping text, model and hover synchronized. Closed skills,
closed Hexes, unfinished art/audio and unverified routes keep their statements.
The global Design data and original skill descriptions are not rewritten.

The new explicit Binding retains every parent pin except the exact chooser and
production adapter successors. Session, Bridge and navigation select it without
changing their owner or startup body. Production changes only its extends line.
The chooser changes only its note/skill-line source; its event lifecycle remains.

Run verify_source.py, then stage_delta.py --dest STAGE (preflight) or --apply.
Run parse_gate.gd, then finite_gate.gd -- --text-result=FRESH_ABSOLUTE_RESULT.
Both paths are under res://tests/ink_e2_boundary_20261006/ordinary01/text01/.
Use the existing serialized guard (30 seconds/768 MiB suggested). Require exit0,
reaped PID, all three groups, exact binding/gate hashes, and clean raw logs with
no script errors, leaks, OOM or guard stops. No engine was run during authoring.

The narrow gate checks actual chooser/hover text, source and closed-skill
boundaries, real original-one-SP learning/undo controls, repeated text refresh,
and same-owner menu Continue. It does not repeat mechanics/old GUI matrices or
claim native input, visual layout, final art, natural growth or full-floor play.
