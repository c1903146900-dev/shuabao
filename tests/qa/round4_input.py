"""XTest window inputs; state setup/readback exclusively via recorded MCP workflows."""
import ctypes as C, os, re, subprocess, sys, time, json
from pathlib import Path
out=Path(sys.argv[1]);os.environ['DISPLAY']=':97';os.environ['XAUTHORITY']=str(out/'Xauthority')
x=C.CDLL('libX11.so.6');t=C.CDLL('libXtst.so.6');x.XOpenDisplay.restype=C.c_void_p
for i in range(100):
 d=x.XOpenDisplay(None)
 if d:break
 time.sleep(.1)
if not d:raise RuntimeError('Display unavailable')
x.XSetInputFocus.argtypes=[C.c_void_p,C.c_ulong,C.c_int,C.c_ulong];x.XFlush.argtypes=[C.c_void_p]
x.XKeysymToKeycode.argtypes=[C.c_void_p,C.c_ulong];x.XKeysymToKeycode.restype=C.c_uint
for name,args in [('XTestFakeMotionEvent',[C.c_void_p,C.c_int,C.c_int,C.c_int,C.c_ulong]),('XTestFakeButtonEvent',[C.c_void_p,C.c_uint,C.c_int,C.c_ulong]),('XTestFakeKeyEvent',[C.c_void_p,C.c_uint,C.c_int,C.c_ulong])]:getattr(t,name).argtypes=args
stages=json.loads(Path(__file__).with_name(sys.argv[2] if len(sys.argv)>2 else 'round4_stages.json').read_text());events=[]
def note(msg):
 events.append({'time':time.time(),'input':msg});(out/'os-input.json').write_text(json.dumps(events,indent=2))
def wait_step(index):
 p=out/f'step-{index:02}-execute_game_script.json'
 for i in range(2000):
  if p.exists():
   try:
    v=json.loads(p.read_text())['content'][0]['text'];v=json.loads(v)
    if isinstance(v,str):v=json.loads(v.replace('\\"','"'))
    return v
   except (ValueError,KeyError):pass
  time.sleep(.1)
 raise RuntimeError(str(p)+' timeout')
def locate():
 tree=subprocess.check_output(['xwininfo','-root','-tree'],text=True);(out/'window-tree.txt').write_text(tree)
 for line in tree.splitlines():
  if 'QA_CHECKPOINT_WINDOW' in line:
   m=re.search(r'(0x[0-9a-f]+).*?(\d+)x(\d+)\+(-?\d+)\+(-?\d+)\s+\+(-?\d+)\+(-?\d+)',line)
   if m:return [int(m[1],16)]+[int(m[k]) for k in [2,3,6,7]]
 raise RuntimeError(tree)
def flush():x.XFlush(d)
def key(symbol,pressed):t.XTestFakeKeyEvent(d,x.XKeysymToKeycode(d,symbol),pressed,0);flush();note(f'key {symbol} {pressed}')
def tap(symbol):key(symbol,1);time.sleep(.04);key(symbol,0);time.sleep(.09)
def button(on):t.XTestFakeButtonEvent(d,1,on,0);flush();note(f'mouse_left {on}')
def move(p):
 xx=int(win[3]+p[0]*win[1]/view[0]);yy=int(win[4]+p[1]*win[2]/view[1]);t.XTestFakeMotionEvent(d,-1,xx,yy,0);flush();note(f'motion {p} screen {xx},{yy}')
for tag,index in stages.items():
 state=wait_step(index);win=locate();view=state['viewport'];controls=state['controls'];x.XSetInputFocus(d,win[0],1,0);flush();note('stage '+tag)
 move([200,350]);time.sleep(.1)
 if tag=='hover':
  key(ord('w'),1);time.sleep(.3);move(controls['allocation']);time.sleep(.3);move([200,350]);time.sleep(.8);key(ord('w'),0)
 elif tag=='panels':
  move(controls['aim']);button(1);time.sleep(.2)
  for i in range(20):
   tap(ord('k'));time.sleep(.10)
   if i==0:button(0)
   tap(0xff1b);time.sleep(.10)
  # fresh press is permitted; leave released
  button(1);time.sleep(.15);button(0)
 elif tag in ['e3','e2','r2','e1']:
  move(controls['aim']);tap(ord(tag[0]))
 elif tag in ['death','death_hold']:
  time.sleep(2);tap(0xff1b);time.sleep(.25)
  if tag=='death':tap(0x20)
  else:key(0x20,1);time.sleep(.85);key(0x20,0)
 elif tag=='victory':
  move(controls['aim']);button(1);time.sleep(1.4);button(0)
 elif tag=='restart':
  tap(0xff1b);tap(0xffc2) # F5
x.XCloseDisplay.argtypes=[C.c_void_p];x.XCloseDisplay(d)
