"""ROOT-EXECUTED real own-process cleanup test. Not run by preparation scripts."""
import argparse,fcntl,importlib.util,json,os,signal,subprocess,sys,time
from pathlib import Path
R=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('guard_candidate',R/'owned_runtime_guard.py');g=importlib.util.module_from_spec(spec);spec.loader.exec_module(g)

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--out',required=True);args=parser.parse_args()
    out=Path(args.out).resolve()
    if out.exists():raise RuntimeError('fresh_output_required')
    out.mkdir(parents=True)
    report={'status':'REAL_OWNED_PYTHON_CLEANUP_FIXTURE','accepted':False,'engine_started':False,'reason':'','workload_ttl_seconds':8,'readiness_seconds':2}
    tree=g.OwnedTree(os.readlink('/proc/self/ns/pid'));old_alarm=signal.getsignal(signal.SIGALRM)
    with (R/'single_engine.lock').open('a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        if g.children() or len(list(Path('/proc/self/task').iterdir()))!=1 or g.engines():raise RuntimeError('dedicated_no_engine_required')
        if g.available_bytes()<g.MIN_AVAILABLE:raise RuntimeError('low_memory_preflight')
        with g.DeferredCancellation() as cancellation,g.LocalSubreaper() as reaper,(out/'raw.log').open('w') as log:
            started=time.monotonic();launch=g.LaunchDeadline(tree,started,out);leader=None;leaf=None
            try:
                launch.arm()
                process=subprocess.Popen([sys.executable,'-I','-B',str(R/'cleanup_workload.py'),str(out)],stdin=subprocess.DEVNULL,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
                launch.stop();tree.attach(process)
                if launch.root_identity is not None and launch.root_identity!=(process.pid,g.read_stat(process.pid)['start_ticks']):raise RuntimeError('launch_identity_changed')
                if launch.expired:raise RuntimeError('launch_deadline')
                tree.establish();last=started
                while time.monotonic()<started+2:
                    scan,rows=tree.sample(g.read_rss)
                    own=g.read_stat(os.getpid());total=g.read_rss(own)+g.swap_bytes(own)+sum(r['rss']+g.swap_bytes(r) for r in rows)
                    now=time.monotonic();gap=now-last;last=now
                    if total>g.CAP or g.available_bytes()<g.MIN_AVAILABLE or gap>g.MAX_GAP:raise RuntimeError('resource_or_gap_limit')
                    if cancellation.requests:raise RuntimeError('cancelled')
                    if scan['escaped']:raise RuntimeError('unexpected_escape')
                    if (out/'leader_ready.json').exists() and (out/'child_ready.json').exists():
                        leader=json.loads((out/'leader_ready.json').read_text());leaf=json.loads((out/'child_ready.json').read_text())
                        if leader['pid']!=process.pid or leader['child_pid']!=leaf['pid'] or leaf['ppid']!=process.pid:raise RuntimeError('ready_identity_mismatch')
                        if not all(any(r['pid']==pid and g.pidfd_pid(r['fd'])==pid for r in tree.records) for pid in [process.pid,leaf['pid']]):raise RuntimeError('ready_not_owned')
                        break
                    time.sleep(.025)
                if leaf is None:raise RuntimeError('readiness_deadline')
            except BaseException as error:report['reason']=type(error).__name__+':'+str(error)
            finally:
                launch.stop();report['cleanup']=g.cleanup(tree,out,started)
                report['exit']=tree.process.returncode if tree.process else None
                report['signals']=list(tree.signals);report['cancellation_requests']=list(cancellation.requests)
                report['elapsed']=time.monotonic()-started
                signal.signal(signal.SIGALRM,old_alarm)
            if cancellation.requests:report['reason']=report['reason'] or 'cancelled_during_cleanup'
        report['subreaper_restored']=reaper.restored
        tree.close_fds()
        reaps=report['cleanup'].get('reaps',[])
        killed=leaf is not None and all(any(r['pid']==pid and r['si_code']==os.CLD_KILLED and r['si_status']==signal.SIGKILL for r in reaps) for pid in [leader['pid'],leaf['pid']])
        report['both_real_owned_processes_killed_and_reaped']=killed
        report['accepted']=not report['reason'] and report['exit']==-signal.SIGKILL and killed and report['cleanup'].get('direct_children_empty',False) and not report['cleanup'].get('errors') and report['elapsed']<8 and reaper.restored
        g.write_json(out/'report.json',report)
    print('OWNED_CLEANUP_FINAL '+json.dumps(report));return 0 if report['accepted'] else 4
if __name__=='__main__':raise SystemExit(main())
