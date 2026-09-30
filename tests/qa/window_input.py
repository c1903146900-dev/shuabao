"""Window-level XTest input, never engine Input.parse_input_event or combat APIs."""
import ctypes as C, os, re, subprocess, sys, time, json
from pathlib import Path
out=Path(sys.argv[1]); os.environ['DISPLAY']=':97'; os.environ['XAUTHORITY']=str(out/'Xauthority')
x=C.CDLL('libX11.so.6'); t=C.CDLL('libXtst.so.6')
x.XOpenDisplay.restype=C.c_void_p; d=x.XOpenDisplay(None)
if not d: raise RuntimeError('No authorized display')
x.XSetInputFocus.argtypes=[C.c_void_p,C.c_ulong,C.c_int,C.c_ulong]; x.XFlush.argtypes=[C.c_void_p]
x.XKeysymToKeycode.argtypes=[C.c_void_p,C.c_ulong]; x.XKeysymToKeycode.restype=C.c_uint
x.XDefaultRootWindow.argtypes=[C.c_void_p]; x.XDefaultRootWindow.restype=C.c_ulong
for name,args in [('XTestFakeMotionEvent',[C.c_void_p,C.c_int,C.c_int,C.c_int,C.c_ulong]),('XTestFakeButtonEvent',[C.c_void_p,C.c_uint,C.c_int,C.c_ulong]),('XTestFakeKeyEvent',[C.c_void_p,C.c_uint,C.c_int,C.c_ulong])]: getattr(t,name).argtypes=args
records=[]
def wait_file(pattern):
 for i in range(900):
  if list(out.glob(pattern)): return
  time.sleep(.1)
 raise RuntimeError(pattern+' timeout')
def window():
 tree=subprocess.check_output(['xwininfo','-root','-tree'],text=True)
 (out/'window-tree.txt').write_text(tree)
 for line in tree.splitlines():
  if 'QA_WINDOW_INPUT' in line:
   m=re.search(r'(0x[0-9a-f]+).*?(\d+)x(\d+)\+(-?\d+)\+(-?\d+)\s+\+(-?\d+)\+(-?\d+)',line)
   if m: return int(m[1],16),int(m[6]),int(m[7])
 raise RuntimeError(tree)
def flush(): x.XFlush(d)
def key(code,on): t.XTestFakeKeyEvent(d,x.XKeysymToKeycode(d,code),on,0);flush()
wait_file('step-02-execute_game_script.json'); wid,px,py=window();x.XSetInputFocus(d,wid,1,0);flush()
t.XTestFakeMotionEvent(d,-1,px+640,py+260,0);flush();time.sleep(.1)
t.XTestFakeButtonEvent(d,1,1,0);flush();time.sleep(1.25);t.XTestFakeButtonEvent(d,1,0,0);flush()
records.append({'input':'XTest left mouse hold','duration':1.25,'window':wid,'screen':[px+640,py+260]})
wait_file('step-05-execute_game_script.json'); key(ord('w'),1);time.sleep(.25)
x.XSetInputFocus(d,x.XDefaultRootWindow(d),1,0);flush();key(ord('w'),0);time.sleep(.2);x.XSetInputFocus(d,wid,1,0);flush()
records.append({'input':'W down / focus root / W up / focus game','held_seconds':.25})
(out/'window-input.json').write_text(json.dumps(records,indent=2));x.XCloseDisplay.argtypes=[C.c_void_p];x.XCloseDisplay(d)
