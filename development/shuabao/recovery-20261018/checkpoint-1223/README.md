# Recovery and narrowly scoped validation checkpoint

Includes new WIP P3 integration02, historical integration01 patch records, single Host reconstruction, guard cleanup fixtures and source-only base recovery verification. Code remains independently reviewable; no full-game or Windows release acceptance is claimed.

p3_core_native01 records only the isolated P3 pure-rule test: 19 checks, exit 0, three increasing rendered frames, 0.729744649 seconds, eight source hashes and sixteen guard files checked. Raw output had zero script errors, one ALSA error and two warnings. This is not real Sim/Model/Session integration or full-floor validation. Raw machine-path logs are excluded.

The native test's unchanged four Catalog/Tuning dependencies are in the fixed candidate43 base at 708454b99a631adac381417f820aabe6798c148c; its P3 core pair is in checkpoint-0928/core01 (under p3_reimplementation). Copy only after SOURCE_PINS verification into a new isolated stage. New runner/project files are preserved here.

Guard evidence covers a real short owned Python cleanup fixture and the isolated core test, not a general guarantee or whole-game test. Base restoration verifies only existing historical 3031 files and does not replace the missing latest source.
