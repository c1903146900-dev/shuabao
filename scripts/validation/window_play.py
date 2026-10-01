"""Record a continuous real X11 window using OS XTest input, not Godot InputEvents.
No gameplay state mutation, MCP plugin, public port, audio capture, or deployment.
Run against a standalone Linux export, or --source for a clearly labeled source run.
"""
import argparse, ctypes as C, hashlib, json, os, re, secrets, signal, subprocess, time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--app',default='build/linux-window/shuabao-client.x86_64');p.add_argument('--source',action='store_true');p.add_argument('--output',default='build/window-play');a=p.parse_args()
out=(ROOT/a.output).resolve();out.mkdir(parents=True,exist_ok=True)
if Path('/tmp/.X98-lock').exists():raise SystemExit('Display :98 in use; refusing to disturb it')
env=os.environ.copy();env.update(DISPLAY=':98',XAUTHORITY=str(out/'Xauthority'),XDG_CACHE_HOME=str(ROOT/'.local/cache'),XDG_DATA_HOME=str(ROOT/'.local/data'),XDG_CONFIG_HOME=str(ROOT/'.local/config'))
Path(env['XAUTHORITY']).touch(mode=0o600)
subprocess.run(['xauth','-f',env['XAUTHORITY'],'add',':98','MIT-MAGIC-COOKIE-1',secrets.token_hex(16)],check=True)
procs=[];logs=[];actions=[];start=0;rec=None;display=None

def launch(name,cmd):
 f=(out/(name+'.log')).open('w');logs.append(f)
 pr=subprocess.Popen(cmd,env=env,stdout=f,stderr=f,start_new_session=True);procs.append(pr);return pr

def stamp(kind,**kw):actions.append(dict(at=round(time.monotonic()-start,3),kind=kind,**kw))
try:
 x=launch('xorg',['Xorg',':98','-config',str(ROOT/'scripts/mcp/xorg-dummy.conf'),'-nolisten','tcp','-auth',env['XAUTHORITY'],'-logfile',str(out/'xorg-server.log')])
 for _ in range(40):
  if subprocess.run(['xdpyinfo'],env=env,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL).returncode==0:break
  time.sleep(.25)
 else:raise RuntimeError('Xorg unavailable')
 cmd=['godot','--path',str(ROOT)] if a.source else [str((ROOT/a.app).resolve())]
 app=launch('game',['stdbuf','-oL']+cmd+['--display-driver','x11','--rendering-method','gl_compatibility','--rendering-driver','opengl3','--audio-driver','Dummy','--position','0,0','--resolution','1280x720','--print-fps','--max-fps','15','--quit-after','750'])
 window=None
 for _ in range(60):
  tree=subprocess.check_output(['xwininfo','-root','-tree'],env=env,text=True)
  matches=re.findall(r'(0x[0-9a-f]+) .*1280x720\+0\+0',tree)
  if matches:window=int(matches[-1],16);break
  if app.poll() is not None:raise RuntimeError('Game exited before window appeared')
  time.sleep(.25)
 if window is None:raise RuntimeError('1280x720 game window not found')
 for _ in range(120):
  info=subprocess.run(['xwininfo','-id',hex(window)],env=env,capture_output=True,text=True)
  if 'Map State: IsViewable' in info.stdout:break # Release stdout can remain buffered until normal close.
  if app.poll() is not None:raise RuntimeError('Game exited during readiness')
  time.sleep(.25)
 else:raise RuntimeError('Game window did not become viewable and ready')
 (out/'window-tree.txt').write_text(tree)
 # XOpenDisplay reads the same private Xauthority as the child processes.
 os.environ['XAUTHORITY']=env['XAUTHORITY']
 lib=C.CDLL('libX11.so.6');xt=C.CDLL('libXtst.so.6')
 lib.XOpenDisplay.argtypes=[C.c_char_p];lib.XOpenDisplay.restype=C.c_void_p
 lib.XStringToKeysym.argtypes=[C.c_char_p];lib.XStringToKeysym.restype=C.c_ulong
 lib.XKeysymToKeycode.argtypes=[C.c_void_p,C.c_ulong];lib.XKeysymToKeycode.restype=C.c_uint
 lib.XSetInputFocus.argtypes=[C.c_void_p,C.c_ulong,C.c_int,C.c_ulong]
 lib.XFlush.argtypes=[C.c_void_p];lib.XCloseDisplay.argtypes=[C.c_void_p]
 xt.XTestFakeKeyEvent.argtypes=[C.c_void_p,C.c_uint,C.c_int,C.c_ulong]
 xt.XTestFakeButtonEvent.argtypes=[C.c_void_p,C.c_uint,C.c_int,C.c_ulong]
 xt.XTestFakeMotionEvent.argtypes=[C.c_void_p,C.c_int,C.c_int,C.c_int,C.c_ulong]
 display=lib.XOpenDisplay(b':98');assert display
 errors=[]
 handler_type=C.CFUNCTYPE(C.c_int,C.c_void_p,C.c_void_p)
 @handler_type
 def x_error(_display,_event):errors.append('X11 error');return 0
 lib.XSetErrorHandler.argtypes=[handler_type];lib.XSetErrorHandler(x_error)
 lib.XSync.argtypes=[C.c_void_p,C.c_int]
 lib.XSetInputFocus(display,window,2,0);lib.XSync(display,0)
 if errors:raise RuntimeError("Cannot focus mapped game window")
 def key(name,down):
  code=lib.XKeysymToKeycode(display,lib.XStringToKeysym(name.encode()));assert code
  xt.XTestFakeKeyEvent(display,code,int(down),0);lib.XFlush(display);stamp('key',key=name,down=down)
 def tap(name):key(name,True);time.sleep(.10);key(name,False);time.sleep(.25)
 def move(x,y):xt.XTestFakeMotionEvent(display,0,x,y,0);lib.XFlush(display);stamp('pointer',x=x,y=y)
 def button(down):xt.XTestFakeButtonEvent(display,1,int(down),0);lib.XFlush(display);stamp('left_button',down=down)
 def shot(name):subprocess.run(['import','-window',hex(window),str(out/(name+'.png'))],env=env,check=True)
 time.sleep(2)
 rec=launch('ffmpeg',['ffmpeg','-y','-f','x11grab','-framerate','30','-video_size','1280x720','-i',':98.0+0,0','-an','-c:v','libx264','-preset','veryfast','-crf','23','-pix_fmt','yuv420p',str(out/'continuous-play.mp4')])
 start=time.monotonic();time.sleep(1);shot('initial')
 tap('k');tap('Tab');tap('Tab');tap('Return');time.sleep(.7);shot('learned');tap('Escape');tap('Return')
 key('w',True);time.sleep(.35);key('w',False)
 for room in range(2):
  move(640,370);button(True)
  for i in range(12):
   move([640,610,670][i%3],390);tap('q');time.sleep(.5)
  button(False);time.sleep(1);shot('room-'+str(room+1));tap('Escape')
  if room==0:
   # Second earned Q point through the actual focused UI, then next room.
   tap('k');tap('Tab');tap('Return');tap('Escape');tap('Return')
 time.sleep(2);shot('final')
 rec.send_signal(signal.SIGINT);rec.wait(timeout=15)
 assert rec.returncode in (0,255), "Unexpected recorder failure" # ffmpeg returns 255 on the requested SIGINT.
 probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(out/'continuous-play.mp4')],text=True))
 (out/'ffprobe.json').write_text(json.dumps(probe,indent=2))
 # The engine's normal iteration-budget quit runs cleanup without SIGTERM.
 # At max 15 render FPS, 750 iterations leave the gameplay recording plus idle
 # time for one-shot sounds to finish. No fixed simulation FPS is imposed.
 deadline=time.monotonic()+300
 while app.poll() is None and time.monotonic()<deadline:time.sleep(.25)
 assert app.poll()==0, 'Game failed normal engine iteration-budget exit'
 game_log=(out/'game.log').read_text()
 assert 'SHUABAO_INTEGRATION_READY checkpoint=3' in game_log, 'Missing startup marker after normal exit'
 assert not any(x in game_log for x in ['SCRIPT ERROR:', 'ERROR:', 'ObjectDB instances leaked', 'resources still in use']), 'Game log has errors or exit resource residue'
 assert int(probe['streams'][0]['nb_frames']) > 600 and float(probe['format']['duration']) > 20, 'Recording too short'
 video=out/'continuous-play.mp4'
 report={'source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'mode':'source window' if a.source else 'standalone Linux desktop export','executable':cmd[0],'executable_sha256':hashlib.sha256(Path(cmd[0]).read_bytes()).hexdigest() if Path(cmd[0]).is_file() else None,'input':'X11 XTest OS events; programmatic, not a human playtest','recording':'one continuous ffmpeg x11grab stream, no montage, no audio track','video_sha256':hashlib.sha256(video.read_bytes()).hexdigest(),'video_bytes':video.stat().st_size,'duration_seconds':probe['format']['duration'],'actions':actions,'game_exit':'normal Godot --quit-after 750 with --max-fps 15; exit 0, no errors or ObjectDB/resource residue; window-close button NOT verified'}
 (out/'recording.json').write_text(json.dumps(report,indent=2));print(json.dumps({k:v for k,v in report.items() if k!='actions'}))
finally:
 if display:
  for name in ['w','q','Return','Tab','Escape']:
   code=lib.XKeysymToKeycode(display,lib.XStringToKeysym(name.encode()));xt.XTestFakeKeyEvent(display,code,0,0)
  xt.XTestFakeButtonEvent(display,1,0,0);lib.XFlush(display);lib.XCloseDisplay(display)
 for pr in reversed(procs):
  if pr.poll() is None:
   os.killpg(pr.pid,signal.SIGTERM)
   try:pr.wait(timeout=8)
   except subprocess.TimeoutExpired:os.killpg(pr.pid,signal.SIGKILL);pr.wait()
 for f in logs:f.close()
 Path(env['XAUTHORITY']).unlink(missing_ok=True)
