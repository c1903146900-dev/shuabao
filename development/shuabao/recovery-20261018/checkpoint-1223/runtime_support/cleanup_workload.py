"""Owned cleanup fixture workload. Eight-second SIGALRM self-limit; no engine."""
import json,os,signal,subprocess,sys,time
from pathlib import Path
signal.signal(signal.SIGTERM,signal.SIG_IGN)
signal.signal(signal.SIGALRM,signal.SIG_DFL)
signal.alarm(8)
out=Path(sys.argv[1]);child_mode=len(sys.argv)>2 and sys.argv[2]=='child'
if child_mode:
    temp=out/'child_ready.tmp';temp.write_text(json.dumps({'pid':os.getpid(),'ppid':os.getppid()}));temp.replace(out/'child_ready.json')
else:
    child=subprocess.Popen([sys.executable,'-I','-B',str(Path(__file__).resolve()),str(out),'child'],stdin=subprocess.DEVNULL)
    temp=out/'leader_ready.tmp';temp.write_text(json.dumps({'pid':os.getpid(),'child_pid':child.pid}));temp.replace(out/'leader_ready.json')
while True:time.sleep(.05)
