"""Narrow try/finally wrapper around the coordinator's EXISTING process guard.

Use after that guard creates its evidence directory and admits the software
window. This module does not launch or manage Godot/Blender or other software.
"""
from contextlib import contextmanager
from pathlib import Path
import subprocess,sys
D=Path(__file__).resolve().parent

@contextmanager
def two_entry_aliases(stage: Path,evidence: Path):
 evidence=evidence.resolve();assert evidence.is_dir()
 backup=evidence/'entry_preimages'
 tool=[sys.executable,str(D/'stage_alias.py'),'--stage',str(stage.resolve()),'--backup-dir',str(backup)]
 subprocess.run(tool+['--temporary-apply','--receipt',str(evidence/'stage_alias_applied.json')],check=True)
 try:
  yield # Only the existing coordinator parse/lifecycle guarded loop belongs here.
 finally:
  receipts=[evidence/name/'exit.json' for name in ['parse','finite'] if (evidence/name/'exit.json').is_file()]
  if not receipts:
   raise RuntimeError('No process receipt: do not claim cleanup; coordinator must confirm no engine started before explicit --no-engine-started restoration')
  command=tool+['--restore','--receipt',str(evidence/'stage_alias_restored.json')]
  for receipt in receipts:command+=['--exit-receipt',str(receipt)]
  # Exit1/error receipts are valid for restoration once the existing guard
  # proves reap and empty group. A red parse/gate still reaches this finally.
  subprocess.run(command,check=True)
