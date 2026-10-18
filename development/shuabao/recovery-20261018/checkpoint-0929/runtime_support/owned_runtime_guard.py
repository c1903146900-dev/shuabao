#!/usr/bin/env python3
"""Reimplementation after rollback. Sampled limits; no hard-kernel termination claim."""
import argparse, fcntl, hashlib, json, os, signal, subprocess, sys, time
from pathlib import Path
from types import SimpleNamespace
HERE = Path(__file__).resolve().parent
LEGACY_SHA = '6a9399e9febda7db6936bf46203017335b3b908cfa0cbfd0597ea41b641e8e30'
MIB = 1024**2
CAP = 1536*MIB
MIN_AVAILABLE = 2048*MIB
CLEANUP_AT, KILL_AT = 595., 600.
INTERVAL, MAX_GAP = .05, .2

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def verify_legacy():
    manifest = HERE/'CODE_PINS.json'
    if sha(manifest) != LEGACY_SHA: raise RuntimeError('legacy_manifest_changed')
    if any(p.name == '__pycache__' or p.suffix in ('.pyc','.pyo') for p in HERE.rglob('*')):
        raise RuntimeError('unexpected_bytecode_cache')
    for rel, row in json.loads(manifest.read_text()).items():
        path = HERE/rel
        if path.is_symlink() or sha(path) != row['sha256'] or path.stat().st_size != row['bytes']:
            raise RuntimeError('legacy_changed:'+rel)

verify_legacy()
sys.path[:0] = [str(HERE/'q1_guard'), str(HERE/'legacy_guard')]
from safe_tree_guard import GuardError, LocalSubreaper, DeferredCancellation, children, read_stat, proc_inventory, exited, pidfd_pid
from safe_tree_guard_rss_reread01 import read_rss
from held_exit_adapter import OwnedTree

class Deadline(BaseException): pass

def write_json(path, value):
    Path(path).write_text(json.dumps(value, indent=2)+'\n')

def safe_hold(output, reason, errors):
    try: write_json(output/'HOLD.json', {'status':'OWNERSHIP_HOLD','reason':reason,'errors':errors[-16:], 'no_new_engine':True,'kernel_termination_proven':False})
    except BaseException: pass  # Do not surrender ownership because the disk is full.

def parse_kib(text, key):
    rows = [line.split() for line in text.splitlines() if line.startswith(key+':')]
    if len(rows)!=1 or len(rows[0])!=3 or rows[0][2]!='kB' or not rows[0][1].isdigit():
        raise GuardError('invalid_memory_field:'+key)
    return int(rows[0][1])*1024

def swap_bytes(row):
    if row['state'] in ('Z','X'): return 0
    value = parse_kib(Path(f"/proc/{row['pid']}/status").read_text(), 'VmSwap')
    after = read_stat(row['pid'])
    if after['start_ticks'] != row['start_ticks']: raise GuardError('swap_identity_changed')
    return value

def available_bytes():
    return parse_kib(Path('/proc/meminfo').read_text(), 'MemAvailable')

def engines():
    result=[]
    for pid in proc_inventory():
        try: name=Path(f'/proc/{pid}/comm').read_text().strip().lower()
        except FileNotFoundError: continue
        if 'godot' in name: result.append(pid)
    return result

def foreign_engines(tree):
    foreign=[]
    for pid in engines():
        try: row=read_stat(pid)
        except FileNotFoundError: continue
        if not any(r['pid']==pid and r['start_ticks']==row['start_ticks'] and pidfd_pid(r['fd'])==pid for r in tree.records): foreign.append(pid)
    return foreign

def verify_tree(root, pinfile, expected):
    if sha(pinfile)!=expected: raise GuardError('stage_manifest_changed')
    pins=json.loads(Path(pinfile).read_text())
    actual={p.relative_to(root).as_posix():p for p in root.rglob('*') if p.is_file()}
    if any(p.is_symlink() for p in root.rglob('*')) or set(actual)!=set(pins): raise GuardError('stage_pathset_changed')
    for rel,digest in pins.items():
        if not isinstance(digest,str) or sha(actual[rel])!=digest: raise GuardError('stage_bytes_changed:'+rel)
    return len(pins)

def functional_args(args):
    # Before -- only an exact res script or a normal-window resolution is admitted.
    result=[]; index=0
    while index<len(args):
        item=args[index]
        if item=='--': return result+args[index:]
        if item not in ('--script','--resolution') or index+1>=len(args): raise GuardError('unsupported_engine_argument')
        value=args[index+1]
        if item=='--script':
            if not value.startswith('res://') or not value.endswith('.gd') or '..' in value[6:].split('/'): raise GuardError('unsafe_script_path')
        elif not (len(value.split('x'))==2 and all(v.isdigit() and int(v)>0 for v in value.split('x'))): raise GuardError('invalid_resolution')
        result.extend([item,value]);index+=2
    return result

class LaunchDeadline:
    """Non-throwing during Popen: retain actual direct-child pidfds before signaling."""
    def __init__(self, tree, started, output):
        self.tree=tree;self.started=started;self.output=output;self.expired=False;self.errors=[];self.root_identity=None
    def tick(self, number=None, frame=None):
        elapsed=time.monotonic()-self.started
        if elapsed<CLEANUP_AT:return
        self.expired=True
        try:
            inventory=proc_inventory()
            direct=[row for row in inventory.values() if row['ppid']==os.getpid()]
            for row in direct:self.tree.pin(row,direct=True)
            if self.tree.process is None:
                leaders=[row for row in direct if row['pid']==row['pgid']==row['sid']]
                candidate=leaders[0] if len(leaders)==1 else direct[0] if len(direct)==1 else None
                if candidate:
                    self.root_identity=(candidate['pid'],candidate['start_ticks'])
                    self.tree.attach(SimpleNamespace(pid=candidate['pid'],returncode=None))
                else:self.errors.append('launch_root_not_unique')
            self.tree.scan()
        except BaseException as error:self.errors.append(repr(error))
        finally:
            try:self.tree.signal_owned(signal.SIGKILL if elapsed>=KILL_AT else signal.SIGTERM)
            except BaseException as error:self.errors.append(repr(error))
            self.errors=self.errors[-32:]
            if elapsed>=KILL_AT:safe_hold(self.output,'Popen_not_returned_at_600s',self.errors)
    def arm(self):
        signal.signal(signal.SIGALRM,self.tick)
        signal.setitimer(signal.ITIMER_REAL,max(.001,CLEANUP_AT-(time.monotonic()-self.started)),INTERVAL)
    def stop(self):signal.setitimer(signal.ITIMER_REAL,0)

def cleanup(tree, output, started):
    began=time.monotonic();quiet=0;errors=[]
    while True:
        now=time.monotonic();elapsed=now-began
        try:
            scan=tree.scan()
            live=any(r['state'] not in ('Z','X') for r in scan['rows']) or any(not exited(r['fd']) for r in tree.records)
            quiet=quiet+1 if not live else 0
            if quiet>=2:
                if tree.process is None:
                    if tree.records or children():raise GuardError('unknown_root_owned_cleanup_HOLD')
                    return {'direct_children_empty':True,'original_group_empty':True,'not_launched':True,'errors':errors[-16:]}
                return dict(tree.reap(),errors=errors[-16:],seconds=elapsed)
        except BaseException as error:quiet=0;errors.append(repr(error))
        try:tree.signal_owned(signal.SIGKILL if elapsed>=.3 or now-started>=KILL_AT else signal.SIGTERM)
        except BaseException as error:errors.append(repr(error))
        errors=errors[-32:]
        if elapsed>=1.5 or now-started>=KILL_AT:safe_hold(output,'owned_exit_not_yet_proven',errors)
        time.sleep(.025 if elapsed<1.5 else .05)

def run(args):
    project=Path(args.project).resolve();output=Path(args.out).resolve();binary=Path(args.binary).resolve()
    if output==project or project in output.parents or output.exists():raise GuardError('fresh_external_output_required')
    command=[str(binary),'--path',str(project)]+functional_args(args.engine_args[1:] if args.engine_args[:1]==['--'] else args.engine_args)
    if sha(binary)!=args.binary_sha256:raise GuardError('binary_changed')
    verify_tree(project,args.pins,args.pins_sha256)
    output.mkdir(parents=True,exist_ok=False)
    report={'status':'REIMPLEMENTATION_NOT_PRIOR_GUARD','command':command,'passed':False,'reason':'','rss_plus_swap_cap':CAP,'min_available':MIN_AVAILABLE,'sample_interval':INTERVAL,'max_allowed_gap':MAX_GAP,'cleanup_at':CLEANUP_AT,'kill_request_at':KILL_AT,'hard_kernel_guarantee':False,'peak_rss_plus_swap':0,'max_sample_gap':0}
    tree=OwnedTree(os.readlink('/proc/self/ns/pid'));reaper=None;started=None;owned_clean=False;old_alarm=signal.getsignal(signal.SIGALRM)
    with (HERE/'single_engine.lock').open('a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        if children() or len(list(Path('/proc/self/task').iterdir()))!=1 or engines():raise GuardError('dedicated_no_existing_engine_required')
        if available_bytes()<MIN_AVAILABLE:raise GuardError('low_memory_preflight')
        with DeferredCancellation() as cancel, LocalSubreaper() as reaper, (output/'raw.log').open('w') as log, (output/'samples.jsonl').open('w') as samples:
            started=time.monotonic();launch=LaunchDeadline(tree,started,output)
            try:
                launch.arm()
                process=subprocess.Popen(command,stdin=subprocess.DEVNULL,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
                launch.stop()
                tree.attach(process);report['pid']=process.pid
                mismatch=launch.root_identity is not None and launch.root_identity!=(process.pid,read_stat(process.pid)['start_ticks'])
                if mismatch:raise GuardError('launch_root_identity_mismatch')
                if launch.expired:raise GuardError('launch_deadline_exceeded')
                def deadline(number,frame):raise Deadline('595s_cleanup_reserve')
                signal.signal(signal.SIGALRM,deadline)
                signal.setitimer(signal.ITIMER_REAL,max(.001,CLEANUP_AT-(time.monotonic()-started)))
                tree.establish();last=started
                while True:
                    tick=time.monotonic();scan,rows=tree.sample(read_rss)
                    own=read_stat(os.getpid());own_rss=read_rss(own);own_swap=swap_bytes(own)
                    total=own_rss+own_swap+sum(row['rss']+swap_bytes(row) for row in rows)
                    available=available_bytes();now=time.monotonic();gap=now-last;last=now
                    report['peak_rss_plus_swap']=max(report['peak_rss_plus_swap'],total);report['max_sample_gap']=max(report['max_sample_gap'],gap)
                    samples.write(json.dumps({'elapsed':now-started,'rss_plus_swap':total,'available':available,'gap':gap,'owned':len(rows)})+'\n');samples.flush()
                    if total>CAP:raise GuardError('rss_plus_swap_cap')
                    if available<MIN_AVAILABLE:raise GuardError('low_system_memory')
                    if gap>MAX_GAP:raise GuardError('sample_gap_untrusted')
                    if scan['escaped']:raise GuardError('owned_process_escaped_session')
                    if foreign_engines(tree):raise GuardError('unowned_engine_detected_no_signal_to_it')
                    if cancel.requests:raise GuardError('cancel_requested')
                    if tree.leader_done():break
                    time.sleep(max(0,INTERVAL-(time.monotonic()-tick)))
            except BaseException as error:report['reason']=type(error).__name__+':'+str(error)
            finally:
                signal.setitimer(signal.ITIMER_REAL,0)
                # Never release lock/subreaper/fds until actual owned cleanup returns.
                report['cleanup']=cleanup(tree,output,started);owned_clean=True
                report['exit']=tree.process.returncode if tree.process else None
                report['signals']=list(tree.signals);report['launch_errors']=launch.errors
                report['cancellation_requests']=list(cancel.requests)
                if cancel.requests and not report['reason']:report['reason']='cancel_requested_during_cleanup'
                report['elapsed']=time.monotonic()-started
                if report['elapsed']>=KILL_AT and not report['reason']:report['reason']='600s_deadline_exceeded'
                signal.signal(signal.SIGALRM,old_alarm)
        report['subreaper_restored']=reaper.restored
        if owned_clean:tree.close_fds()
        try:report['post_files']=verify_tree(project,args.pins,args.pins_sha256)
        except BaseException as error:report['reason']=report['reason'] or 'post_seal:'+str(error)
        report['passed']=not report['reason'] and report['exit']==0 and report['cleanup'].get('direct_children_empty',False) and not report['cleanup'].get('errors')
        write_json(output/'exit.json',report)
    return report

def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name in ['project','out','pins','pins-sha256','binary','binary-sha256']:p.add_argument('--'+name,required=True)
    p.add_argument('--mode',choices=['functional'],default='functional')
    p.add_argument('engine_args',nargs=argparse.REMAINDER)
    result=run(p.parse_args());print(json.dumps(result));return 0 if result['passed'] else 4
if __name__=='__main__':raise SystemExit(main())
