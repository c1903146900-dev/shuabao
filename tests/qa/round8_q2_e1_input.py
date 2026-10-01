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
 move(controls[name]['point']);button(1);time.sleep(.04);button(0);time.sleep(.09)
def capture(label):
 samples[label]=v;(out/'os-samples.json').write_text(json.dumps(samples,ensure_ascii=False,indent=2));note('sample '+label)
def aim():
 if v['targets']:move(min(v['targets'],key=lambda z:z['distance'])['screen'])
K=lambda sym:('key',sym)
CAP=lambda label:('capture',label)
E=0xff0d;ESC=0xff1b
steps=[CAP('initial'),K(ord('k')),('open_option','Q'),('choose','Q',1),('click','learn_Q'),K(ESC),K(E),('q2_window',),('wait_q2',),('fight','room1'),K(ESC),K(ord('k')),('click','learn_E'),K(ESC),K(E),('e1_cast',),('mark_recast',),('recast_done',),('fight','room2'),K(ESC),K(E),('e1_cast',),('mark_attack',),('target_dead',),('fight','room3'),CAP('done')]
seen=set();samples={};mouse=False;started=time.time();deadline=started+200;current=0;tag_time=0
while time.time()<deadline and current<len(steps):
 files=sorted(out.glob('step-*-execute_game_script.json'),key=lambda p:p.stat().st_mtime)
 if not files or files[-1].name in seen:time.sleep(.03);continue
 f=files[-1]
 try:
  v=json.loads(json.loads(f.read_text())['content'][0]['text'])
  if isinstance(v,str):v=json.loads(v.replace('\\"','"'))
 except (ValueError,KeyError):time.sleep(.05);continue
 if 'viewport' not in v:raise RuntimeError(str(v))
 seen.add(f.name);win=locate();view=v['viewport'];controls=v['controls'];
 if not any(z.get('visible') for z in v.get('choices',{}).values()):x.XSetInputFocus(d,win[0],1,0);flush()
 state=v['state'];hero=state['combat']['hero'];phase=state['combat']['phase'];cs=hero['cast_state'];step=steps[current];op=step[0]
 note('step '+str(current)+' '+str(step)+' phase='+phase+' source='+f.name)
 if op=='capture':capture(step[1])
 elif op=='key':tap(step[1])
 elif op=='click':click(step[1])
 elif op=='open_option':click('options_'+step[1])
 elif op=='choose':
  pop=v['choices'][step[1]]
  if not pop['visible']:capture('popup_missing');break
  pt=[pop['position'][0]+pop['size'][0]/2,pop['position'][1]+4+(pop['size'][1]-8)/pop['count']*(step[2]+.5)]
  if pop['embedded']:move(pt)
  else:t.XTestFakeMotionEvent(d,-1,int(pt[0]),int(pt[1]),0);flush();note('native popup choice '+str(pt))
  button(1);time.sleep(.04);button(0)
 elif op=='q2_window':
  warnings=[z for z in v['targets'] if z['state']=='warning' and z['timer']>.18]
  if not warnings:continue
  if state['growth']['skills']['Q']['candidate']!='Q2':capture('wrong_Q_candidate');break
  capture('before_q2');aim();time.sleep(max(0,min(z['timer'] for z in warnings)-.13));tap(ord('q'))
 elif op=='wait_q2':
  if not any(z['event']['kind']=='q2_finished' for z in v['events']):
   if phase!='combat':capture('Q2_not_completed');break
   continue
  capture('q2_finished')
 elif op=='e1_cast':aim();tap(ord('e'))
 elif op in ['mark_recast','mark_attack']:
  if cs.get('e1',{}).get('stage')!='marked':
   if phase!='combat':capture('unexpected_e1_terminal');break
   continue
  capture(op);aim()
  if op=='mark_recast':tap(ord('e'));tag_time=time.time()
  else:button(1);mouse=True
 elif op=='recast_done':
  if 'e1' in cs or time.time()-tag_time<.3:continue
  capture('e1_recast_finished')
 elif op=='target_dead':
  if 'e1' in cs:continue
  button(0);mouse=False;capture('marked_target_dead');tap(ord('e'));tag_time=time.time()
 elif op=='fight':
  if phase=='combat':
   if v['targets']:
    aim()
    if not mouse:button(1);mouse=True
   continue
  button(0);mouse=False;capture(step[1]+'_victory')
  if phase!='victory':capture('unexpected_terminal');break
 current+=1
if mouse:button(0)
(out/'os-finish.json').write_text(json.dumps({'completed':current==len(steps),'step':current,'next':steps[current] if current<len(steps) else None,'elapsed':time.time()-started,'samples':list(samples)},indent=2))
x.XCloseDisplay.argtypes=[C.c_void_p];x.XCloseDisplay(d)
