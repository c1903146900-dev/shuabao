# R2 peaks candidate01

Source-only independent base-R2 mechanics extending the frozen E1 reform-pause
candidate. Parent implementation, ordinary host/chooser, and original design
sources remain unchanged. The three implementation files were checkpointed as
real bytes before writing the four finite affected groups. Checkpoint01 is
preserved; final source corrections appear in checkpoint02, with dependency
hashes instead of copied old project/assets trees.

Sources: `sim.gd`, `tuning.gd`, `peak_geometry.gd`. Read SOURCE_BASIS.md for exact
original/decision/authoring precedence, geometry boundaries and production choices.

Coordinator-owned sequence (no author engine process has run):

1. `python tests/ink_r2_peaks_20261006/candidate01/verify_source.py`
2. Stage into an already materialized, outside-source runtime project whose
   inherited dependency bytes match:
   `python tests/ink_r2_peaks_20261006/candidate01/stage_delta.py --dest STAGE`
   then the same command with `--apply --receipt RECEIPT`
3. Run the existing project import/index seam, then Godot headless parse:
   `--path STAGE --headless -s res://tests/ink_r2_peaks_20261006/candidate01/parse_gate.gd`
4. Run finite API/callback gate:
   `--path STAGE --headless -s res://tests/ink_r2_peaks_20261006/candidate01/finite_gate.gd -- --r2-result=ABS_RESULT`
5. Feed unedited raw stdout/stderr, exit/reap receipts and matching written report
   to `raw_error_gate.py --binding STAGE_BINDING --parse-raw PARSE_RAW
   --parse-exit PARSE_EXIT --finite-raw FINITE_RAW --finite-exit FINITE_EXIT
   --finite-report FINITE_REPORT --output OUTPUT`.

The four groups cover source admission/all four ranks, dense locked selection and
clipped footprint, first/last-packet pauses and retirement, inherited world clocks
and passive isolation. This is not a full legacy matrix rerun, native input,
ordinary progression/level-6 learning, visual approval or balance sign-off.
Source audit PASS does not establish GDScript parse or runtime PASS. Only current
source-bound coordinator raw evidence can establish those results.
