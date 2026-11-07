from pathlib import Path
import time,json
out=Path('/workspace/scratch/73ebae91a474/scheduling_review_20261107/idle01.json')
assert not out.exists()
def read(p):
 try:return Path(p).read_text()
 except OSError:return None
start=time.monotonic();last=start;gaps=[]
before={p:read(p) for p in ['/proc/pressure/cpu','/proc/pressure/memory','/sys/fs/cgroup/cpu.stat','/proc/loadavg']}
while time.monotonic()-start<60:
 time.sleep(.05);now=time.monotonic();gaps.append(now-last);last=now
after={p:read(p) for p in before}
out.write_text(json.dumps({'seconds':time.monotonic()-start,'max_gap':max(gaps),'over_02':sum(g>.2 for g in gaps),'samples':len(gaps),'before':before,'after':after,'scope':'Read-only idle scheduler observation; not engine guard replacement or promise of future stability.'},indent=2))
