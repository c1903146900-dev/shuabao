"""XTest window inputs; state setup/readback exclusively via recorded MCP workflows."""
import ctypes as C, os, re, subprocess, sys, time, json
from pathlib import Path
out=Path(sys.argv[1]);os.environ['DISPLAY']=':97';os.environ['XAUTHORITY']=str(out/'Xauthority')
x=C.CDLL('libX11.so.6');t=C.CDLL('libXtst.so.6');x.XOpenDisplay.restype=C.c_void_p
for i in range(1600):
 d=x.XOpenDisplay(None)
 if d:break
 time.sleep(.1)
if not d:raise RuntimeError('Display unavailable')
x.XSetInputFocus.argtypes=[C.c_void_p,C.c_ulong,C.c_int,C.c_ulong];x.XFlush.argtypes=[C.c_void_p]
x.XKeysymToKeycode.argtypes=[C.c_void_p,C.c_ulong];x.XKeysymToKeycode.restype=C.c_uint
for name,args in [('XTestFakeMotionEvent',[C.c_void_p,C.c_int,C.c_int,C.c_int,C.c_ulong]),('XTestFakeButtonEvent',[C.c_void_p,C.c_uint,C.c_int,C.c_ulong]),('XTestFakeKeyEvent',[C.c_void_p,C.c_uint,C.c_int,C.c_ulong])]:getattr(t,name).argtypes=args
events=[]
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

def click(name):
 move(controls[name]);button(1);time.sleep(.05);button(0);time.sleep(.12)
def remember(name,v):
 samples[name]=v
 (out/'os-samples.json').write_text(json.dumps(samples,ensure_ascii=False,indent=2))
 note('sample '+name)
stage='initial';seen=set();samples={};started=time.time();deadline=started+520;freeze_start=0;frozen_death=0;last_q=0;mouse_held=False;retry_time=0
while time.time()<deadline:
 files=sorted(out.glob('step-*-execute_game_script.json'),key=lambda p:p.stat().st_mtime)
 if not files or files[-1].name in seen:
  time.sleep(.08);continue
 f=files[-1]
 try:
  v=json.loads(json.loads(f.read_text())['content'][0]['text'])
  if isinstance(v,str):v=json.loads(v.replace('\\"','"'))
 except (ValueError,KeyError):time.sleep(.1);continue
 seen.add(f.name)
 win=locate();view=v['viewport'];controls=v['controls'];x.XSetInputFocus(d,win[0],1,0);flush()
 s=v['state'];phase=s['combat']['phase'];g=s['growth']
 note('observe '+stage+' phase='+phase+' room='+str(s['room_number'])+' kills='+str(s['kills'])+' source='+f.name)
 if stage=='initial':
  remember('initial',v);tap(ord('k'));stage='learn'
 elif stage=='learn':click('learn_q');stage='learned'
 elif stage=='learned':
  remember('learned',v);tap(0xff1b);time.sleep(.2);click('start');stage='room1'
 elif stage in ['room1','room2','room3_one']:
  if phase=='combat':
   if stage=='room3_one' and s['kills']>=1:
    button(0);mouse_held=False;remember('room3_paid_kill',v);stage='wait_down'
   elif v['targets']:
    target=min(v['targets'],key=lambda a:a['distance']);move(target['screen'])
    if not mouse_held:button(1);mouse_held=True
    if stage=='room1' and time.time()-last_q>.35:tap(ord('q'));last_q=time.time()
  elif phase=='victory':
   button(0);mouse_held=False;remember(stage+'_victory',v)
   if stage=='room1':freeze_start=time.time();stage='freeze1'
   elif stage=='room2':tap(0xff1b);time.sleep(.2);click('start');stage='room3_one'
  elif phase in ['downed','true_dead']:
   button(0);remember('unexpected_terminal_'+stage,v);stage='unexpected';break
 elif stage=='freeze1' and time.time()-freeze_start>=62:
  remember('room1_frozen',v);tap(0xff1b);tap(ord('k'));stage='upgrade'
 elif stage=='upgrade':click('learn_q');stage='upgraded'
 elif stage=='upgraded':
  remember('upgraded',v);tap(0xff1b);tap(ord('p'));stage='shop'
 elif stage=='shop':click('iron_blade');stage='bought'
 elif stage=='bought':
  remember('purchased',v);tap(0xff1b);time.sleep(.2);click('start');stage='room2start'
 elif stage=='room2start':remember('room2_start',v);stage='room2'
 elif stage=='wait_down' and phase=='downed':
  remember('downed',v);tap(0xff1b);tap(0x20);stage='rescued'
 elif stage=='rescued':remember('rescued',v);stage='wait_dead'
 elif stage=='wait_dead' and phase=='true_dead':
  remember('true_dead',v);frozen_death=time.time();stage='dead_freeze'
 elif stage=='dead_freeze' and time.time()-frozen_death>=62:
  remember('dead_frozen',v);tap(0xff1b);tap(0xffc2);retry_time=time.time();stage='retry'
 elif stage=='retry':
  remember('retry',v);tap(0xffc2);tap(0xffc2);stage='retry_repeated'
 elif stage=='retry_repeated':
  remember('retry_repeated',v);stage='done';break
(out/'os-finish.json').write_text(json.dumps({'stage':stage,'elapsed':time.time()-started,'samples':list(samples)},indent=2))
if mouse_held:button(0)
x.XCloseDisplay.argtypes=[C.c_void_p];x.XCloseDisplay(d)
