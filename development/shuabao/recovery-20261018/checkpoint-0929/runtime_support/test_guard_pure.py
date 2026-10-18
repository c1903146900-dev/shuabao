"""Pure tests only: no Popen, engine, signals, pidfds, or subreaper calls."""
import importlib.util,json,tempfile,hashlib
from pathlib import Path
from unittest.mock import patch
R=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('candidate_guard',R/'owned_runtime_guard.py');g=importlib.util.module_from_spec(spec);spec.loader.exec_module(g)
checks=[]
def ok(name,test):
    assert test(),name;checks.append(name)
def reject(name,call):
    try:call()
    except (g.GuardError,RuntimeError):checks.append(name);return
    raise AssertionError(name)
ok('memory_kib',lambda:g.parse_kib('MemAvailable: 2097152 kB\n','MemAvailable')==g.MIN_AVAILABLE)
for text in ['','VmSwap: nope kB','VmSwap: 2 MB','VmSwap: 2 kB\nVmSwap: 3 kB']:
    reject('memory_bad_'+repr(text),lambda text=text:g.parse_kib(text,'VmSwap'))
ok('exact_policy',lambda:(g.CAP,g.CLEANUP_AT,g.KILL_AT,g.INTERVAL,g.MAX_GAP)==(1536*1024**2,595.,600.,.05,.2))
ok('normal_script',lambda:g.functional_args(['--script','res://test.gd','--','--evidence=/tmp/new'])==['--script','res://test.gd','--','--evidence=/tmp/new'])
ok('normal_resolution',lambda:g.functional_args(['--resolution','1280x720'])==['--resolution','1280x720'])
for args in [['--headless'],['--headless=true'],['--editor'],['-e'],['--path','/tmp'],['--script','../test.gd'],['--script','res://../bad.gd'],['--resolution','0x1']]:
    reject('cli_reject_'+str(args),lambda args=args:g.functional_args(args))
with tempfile.TemporaryDirectory() as d:
    r=Path(d)/'project';r.mkdir();(r/'a').write_bytes(b'a');p=Path(d)/'pins.json';p.write_text(json.dumps({'a':g.sha(r/'a')}));digest=g.sha(p)
    ok('exact_tree',lambda:g.verify_tree(r,p,digest)==1)
    (r/'a').write_bytes(b'b');reject('modified_tree',lambda:g.verify_tree(r,p,digest));(r/'a').write_bytes(b'a')
    (r/'extra').write_text('x');reject('extra_file',lambda:g.verify_tree(r,p,digest));(r/'extra').unlink()
    (r/'link').symlink_to(r/'a');reject('symlink',lambda:g.verify_tree(r,p,digest))
class Fake:
    def __init__(self):self.process=None;self.records=[];self.sent=[];self.n=0
    def pin(self,row,direct=False):assert direct;self.records.append(dict(row,fd=1));return self.records[-1]
    def attach(self,p):self.process=p
    def scan(self):return {'rows':[]}
    def signal_owned(self,n):self.sent.append(n)
    def reap(self):return {'direct_children_empty':True,'original_group_empty':True}
f=Fake();alarm=g.LaunchDeadline(f,0,Path('/not-written'))
row={'pid':7,'ppid':123,'pgid':7,'sid':7,'start_ticks':20}
with patch.object(g.time,'monotonic',return_value=595.),patch.object(g.os,'getpid',return_value=123),patch.object(g,'proc_inventory',return_value={7:row}):alarm.tick()
ok('launch595_owned_TERM',lambda:alarm.expired and alarm.root_identity==(7,20) and f.sent==[g.signal.SIGTERM])
with patch.object(g.time,'monotonic',return_value=600.),patch.object(g,'proc_inventory',side_effect=OSError('inventory failed')),patch.object(g,'write_json',side_effect=OSError('disk full')):alarm.tick()
ok('launch600_inventory_disk_failure_still_KILL',lambda:f.sent[-1]==g.signal.SIGKILL)
f=Fake();f.process=object();f.records=[{'fd':1}]
def scan():
    f.n+=1
    if f.n==1:raise OSError('temporary scan')
    return {'rows':[]}
f.scan=scan
clock=iter([0.,2.,2.05,2.10])
with patch.object(g.time,'monotonic',side_effect=lambda:next(clock)),patch.object(g.time,'sleep'),patch.object(g,'exited',return_value=True),patch.object(g,'write_json',side_effect=OSError('disk full')):
    result=g.cleanup(f,Path('/not-written'),0)
ok('cleanup_disk_failure_retains_until_reaped',lambda:result['direct_children_empty'] and bool(result['errors']) and f.sent[0]==g.signal.SIGKILL)
report={'status':'PURE_TESTS_ONLY_NO_CHILDREN_OR_ENGINE','checks':checks,'count':len(checks)}
(R/'PURE_TEST_RESULT.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
