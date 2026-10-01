import json,subprocess,time,sys
from pathlib import Path
out=Path(sys.argv[1]);start=time.time();rows=[];had=False
while time.time()-start<240:
 auth=(out/'Xauthority').exists();had|=auth
 rows.append({'epoch':time.time(),'elapsed':time.time()-start,'xauthority':auth,'processes':[l.strip() for l in subprocess.check_output(['ps','-eo','pid,ppid,comm,stat,etime,pcpu,rss'],text=True).splitlines() if any(x in l.lower() for x in ['godot','blender','xorg','shuabao','刷宝'])]})
 (out/'process-monitor.json').write_text(json.dumps(rows,indent=2)) if out.exists() else None
 errors=[]
 for p in out.glob('step-*.json'):
  try:
   x=json.loads(p.read_text())
   if x.get('application_error'):errors.append({'call':p.name,'mtime':p.stat().st_mtime,'result':x})
  except ValueError:pass
 if errors:(out/'observed-tool-errors.json').write_text(json.dumps({'observed_at':time.time(),'since_monitor_start':time.time()-start,'errors':errors,'processes':rows[-1]},indent=2))
 if had and not auth:break
 time.sleep(2)
