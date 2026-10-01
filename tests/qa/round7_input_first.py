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
 move(controls[name]['point']);button(1);time.sleep(.05);button(0);time.sleep(.08)
def capture(label):
 samples[label]=v
 (out/'os-samples.json').write_text(json.dumps(samples,ensure_ascii=False,indent=2));note('sample '+label)
def wheel(down):
 for _ in range(3):
  t.XTestFakeButtonEvent(d,5 if down else 4,1,0);t.XTestFakeButtonEvent(d,5 if down else 4,0,0)
 flush();note('scroll '+str(down))
def item_index(item):return next((i for i,z in enumerate(g['inventory']) if z['id']==item),None)
K=lambda sym:('key',sym)
C=lambda label:('capture',label)
B=lambda item:('buy',item)
U=lambda item:('use',item)
E=0xff0d;KP=0xff8d;ESC=0xff1b
steps=[C('initial'),K(ord('k')),('click','learn_q'),K(ESC),C('closed_learning'),K(0xff09),C('tab_focus'),K(E),C('tab_enter_gui'),K(ESC),K(E),C('enter_short'),('fight','room1',True),K(ESC),K(ord('p')),B('iron_blade'),C('iron'),K(ESC),('hold',KP,.85),C('kp_long'),('fight','room2',False),K(ESC),('hold',E,.85),K(E),K(E),C('enter_long_repeated'),('fight','room3',False),K(ESC),K(ord('p')),C('before_HP'),B('blood_crystal'),C('HP_equipped')]
steps += [B('normal_tonic')]*4
steps += [C('normals_bought'),B('special_tonic'),C('holding_mutex'),('click','tab_1'),C('before_normal')]
steps += [U('normal_tonic'),C('normal1'),U('normal_tonic'),C('normal2'),U('normal_tonic'),C('normal3'),U('normal_tonic'),C('normal_full_reject'),('sell','normal_tonic'),('click','tab_0'),B('special_tonic'),C('special_bought'),K(ESC),K(KP),C('kp_short'),('click','equip_2'),C('combat_bag'),U('special_tonic'),C('combat_use_blocked'),K(ESC),('hurt',110),('fight','room4',True),K(ESC),K(ord('p')),B('special_tonic'),B('special_tonic'),C('three_specials'),('click','tab_1'),C('before_special'),U('special_tonic'),C('special1'),U('special_tonic'),C('special2'),U('special_tonic'),C('special3_rejected'),K(ESC),K(E),C('room5_reset'),('fight','room5',False),K(ESC),('click','equip_2'),U('special_tonic'),C('special_new_room'),('click','tab_0'),B('mainspring'),C('AS_equipped'),K(ESC),K(E),('fight','room6',False),K(ESC),K(ord('p')),B('cooling_core'),C('CDR_equipped'),('click','tab_2'),C('hex_offer'),('click','hex_0'),C('hex_selected'),K(ESC),K(E),('key',0xffe1),C('CDR_dash'),('fight','room7',False),C('done')]
seen=set();samples={};mouse=False;started=time.time();deadline=started+650;current=0;last_q=0
while time.time()<deadline and current<len(steps):
 files=sorted(out.glob('step-*-execute_game_script.json'),key=lambda p:p.stat().st_mtime)
 if not files or files[-1].name in seen:time.sleep(.06);continue
 f=files[-1]
 try:
  v=json.loads(json.loads(f.read_text())['content'][0]['text'])
  if isinstance(v,str):v=json.loads(v.replace('\\"','"'))
 except (ValueError,KeyError):time.sleep(.1);continue
 if 'viewport' not in v:raise RuntimeError('MCP read failed: '+str(v))
 seen.add(f.name);win=locate();view=v['viewport'];controls=v['controls'];x.XSetInputFocus(d,win[0],1,0);flush()
 state=v['state'];g=state['growth'];phase=state['combat']['phase'];step=steps[current];op=step[0]
 note('step '+str(current)+' '+str(step)+' phase='+phase+' room='+str(state['room_number'])+' source='+f.name)
 if op=='capture':capture(step[1])
 elif op=='key':tap(step[1])
 elif op=='hold':key(step[1],1);time.sleep(step[2]);key(step[1],0)
 elif op=='click':click(step[1])
 elif op=='buy':
  name='buy_'+step[1];point=controls[name]['point'];rect=v['scroll']
  if point[1]<rect[1]+10 or point[1]>rect[1]+rect[3]-10:
   move([rect[0]+rect[2]/2,rect[1]+rect[3]/2]);wheel(point[1]>rect[1]+rect[3]-10);continue
  click(name)
 elif op in ['use','sell']:
  idx=item_index(step[1])
  if idx is None:capture('missing_item_'+str(current));break
  click(op+'_'+str(idx))
 elif op=='hurt':
  if state['combat']['hero']['hp']>step[1] and phase=='combat':continue
  capture('hurt_before_room4_finish')
 elif op=='fight':
  if phase=='combat':
   if state['panel_open']:capture('unexpected_combat_panel_'+step[1]);break
   if v['targets']:
    move(min(v['targets'],key=lambda z:z['distance'])['screen'])
    if not mouse:button(1);mouse=True
    if step[2] and time.time()-last_q>.4:tap(ord('q'));last_q=time.time()
   continue
  button(0);mouse=False;capture(step[1]+'_victory')
  if phase!='victory':capture('unexpected_terminal');break
 current+=1
if mouse:button(0)
(out/'os-finish.json').write_text(json.dumps({'completed':current==len(steps),'step':current,'elapsed':time.time()-started,'next':steps[current] if current<len(steps) else None,'samples':list(samples)},indent=2))
x.XCloseDisplay.argtypes=[C.c_void_p];x.XCloseDisplay(d)
