"""Stage exact external dependency under ignored .local; never change progression sources."""
from pathlib import Path
import subprocess
import shutil
ROOT = Path(__file__).resolve().parents[2]
PIN = '607bf6385f5f668155aa76f5df6eb184e5685cea'
subprocess.run(['python3', str(ROOT/'tests/ui/prepare_fixture.py')], cwd=ROOT, check=True)
fixture = ROOT/'.local/mcp-fixture'
paths = subprocess.check_output(['git','ls-tree','-r','--name-only',PIN,'scripts/progression','data/progression'],cwd=ROOT,text=True).splitlines()
for path in paths:
    if path.startswith('scripts/progression/') and Path(path).name not in ('model.gd', 'model.gd.uid'):
        continue
    target = fixture/path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(subprocess.check_output(['git','show',f'{PIN}:{path}'],cwd=ROOT))
for path in (ROOT/'tests/ui').glob('*.gd'):
    shutil.copy2(path, fixture/'tests/ui'/path.name)
print('Exact progression dependency staged:', PIN)
