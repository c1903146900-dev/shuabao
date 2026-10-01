import json,os,re,subprocess,time
from pathlib import Path
out=Path(__file__).parent/'evidence/round6-two-room-final'
os.environ['DISPLAY']=':97';os.environ['XAUTHORITY']=str(out/'Xauthority')
end=time.time()+160
while time.time()<end:
 try:s=json.loads((out/'os-samples.json').read_text())
 except (FileNotFoundError,ValueError):s={}
 if 'retry' in s:
  tree=subprocess.check_output(['xwininfo','-root','-tree'],text=True)
  line=next(l for l in tree.splitlines() if 'QA_CHECKPOINT_WINDOW' in l and 'Godot_Engine' in l)
  window=re.search(r'0x[0-9a-f]+',line)[0]
  subprocess.run(['import','-window',window,str(out/'os-retry.png')],check=True)
  (out/'os-retry-capture.json').write_text(json.dumps({'method':'ImageMagick capture of XTest-controlled Godot game window','window':window,'wall_epoch':time.time(),'latest_observer_wall':s['retry']['wall']},indent=2))
  break
 time.sleep(.05)
else:raise RuntimeError('retry not observed before deadline')
