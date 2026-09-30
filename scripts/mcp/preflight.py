"""Read-only preflight for a new Shuabao cloud checkout; no package installation."""
import shutil
import subprocess
import sys
from pathlib import Path

missing = [name for name in ['git','node','npm','uv','godot','blender','Xorg','xauth','xdpyinfo','import'] if not shutil.which(name)]
if missing:
    print('MISSING:', ', '.join(missing))
    sys.exit(1)
for name, prefix in [('godot','4.6.3'),('blender','Blender 4.3.2')]:
    result=subprocess.run([name,'--version'],text=True,capture_output=True,timeout=20)
    first=result.stdout.splitlines()[0] if result.stdout else ''
    print(name, first)
    if result.returncode or not first.startswith(prefix):
        raise SystemExit('Unexpected application version; resolve explicitly before testing')
if not Path('/usr/lib/xorg/modules/drivers/dummy_drv.so').is_file():
    raise SystemExit('Missing Xorg dummy driver; install distro xserver-xorg-video-dummy before testing')
print('PREFLIGHT_PASS: required binaries and pinned application versions present')
