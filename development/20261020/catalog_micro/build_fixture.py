"""Build the exact GUI microbenchmark from pinned small scripts and existing base data.
No downloads, game launch, pack modification, or production integration.
"""
from pathlib import Path
import argparse,hashlib,json,shutil
p=argparse.ArgumentParser()
p.add_argument('--base-root',required=True,help='Existing extracted, verified source06 resource root')
p.add_argument('--output',help='New empty/nonexistent standalone project directory')
p.add_argument('--verify-only',action='store_true')
a=p.parse_args()
here=Path(__file__).resolve().parent
pins=json.loads((here/'INPUTS.json').read_text())
base=Path(a.base_root).resolve()
def check(path,expected):
    if not path.is_file():raise SystemExit('Missing input: '+str(path))
    if hashlib.sha256(path.read_bytes()).hexdigest()!=expected:raise SystemExit('SHA256 mismatch: '+str(path))
for n,h in pins['fixture_files'].items():check(here/'fixture'/n,h)
for n,h in pins['required_base_files'].items():check(base/n,h)
check(here/'report.json',pins['report_sha256'])
if a.verify_only:
    print('All published fixture files, report, and required base data verified; no files written.')
    raise SystemExit(0)
if not a.output:raise SystemExit('--output required unless --verify-only')
out=Path(a.output).absolute()
if out.exists() or out.is_symlink():raise SystemExit('Output must not already exist')
out.mkdir(parents=True,exist_ok=False)
for n in pins['fixture_files']:
    shutil.copyfile(here/'fixture'/n,out/n)
for n in pins['required_base_files']:
    target=out/n;target.parent.mkdir(parents=True,exist_ok=True)
    shutil.copyfile(base/n,target)
for n,h in pins['fixture_files'].items():check(out/n,h)
for n,h in pins['required_base_files'].items():check(out/n,h)
print('Standalone GUI fixture built and verified. Engine was not started.')
