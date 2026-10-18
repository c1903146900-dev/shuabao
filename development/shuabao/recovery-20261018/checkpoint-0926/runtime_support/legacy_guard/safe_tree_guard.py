"""Loot guard candidate2: explicit owned lineage, pidfds and held cleanup.

Only a dedicated controller with no preexisting children may use this module.
No engine command or private resource threshold is selected here.
"""
from pathlib import Path
import json,math,os,select,signal,subprocess,time
from memory_budget_v2 import budget
from safe_group_guard import GuardError,LocalSubreaper,read_stat,read_rss


class BoundedHistory(list):
    def __init__(self):super().__init__();self.total=0
    def append(self,item):
        self.total+=1;super().append(item)
        if len(self)>128:del self[:-128]


def pairs(text):
    result={}
    for line in text.splitlines():
        fields=line.split()
        if len(fields)!=2 or fields[0] in result or not fields[1].isdigit():
            raise GuardError('invalid_or_duplicate_counter')
        result[fields[0]]=int(fields[1])
    return result


def system_sample():
    folder=Path('/sys/fs/cgroup')
    raw={key:(folder/key).read_text().strip() for key in
         ['memory.max','memory.high','memory.current','memory.stat','memory.events']}
    if not raw['memory.max'].isdigit() or int(raw['memory.max'])<=0 or not raw['memory.current'].isdigit():
        raise GuardError('invalid_finite_max_or_current')
    if raw['memory.high']!='max' and not raw['memory.high'].isdigit():raise GuardError('invalid_memory_high')
    stat=pairs(raw['memory.stat']);events=pairs(raw['memory.events'])
    required={key:events[key] for key in ['high','max','oom','oom_kill','oom_group_kill']}
    return {'raw_fields':raw,'maximum':int(raw['memory.max']),'current':int(raw['memory.current']),
            'budget':budget(raw['memory.max'],raw['memory.current'],stat),'events':required}


def children():
    # task/*/children is absent on the dot desktop. Never interpret that
    # unsupported interface as an empty inventory. Use same-namespace PPid.
    inventory=proc_inventory()
    return {pid for pid,row in inventory.items() if row['ppid']==os.getpid()}


def proc_inventory():
    rows={}
    for name in os.listdir('/proc'):
        if not name.isdigit():continue
        try:rows[int(name)]=read_stat(int(name))
        except FileNotFoundError:continue
    own_pid=os.getpid()
    self_pid=int(Path('/proc/self/stat').read_text().split(' ',1)[0])
    if own_pid!=self_pid or own_pid not in rows:raise GuardError('proc_inventory_namespace_or_completeness_unproved')
    return rows


def exited(fd):
    poll=select.poll();poll.register(fd,select.POLLIN|select.POLLHUP)
    return bool(poll.poll(0))


def pidfd_pid(fd):
    values=[line.split(':',1)[1].strip() for line in Path(f'/proc/self/fdinfo/{fd}').read_text().splitlines() if line.startswith('Pid:')]
    if len(values)!=1:raise GuardError('missing_pidfd_identity')
    return int(values[0])


class DeferredCancellation:
    def __init__(self):self.requests=BoundedHistory();self.previous={}
    def __enter__(self):
        def receive(number,_frame):self.requests.append({'signal':number,'at':time.monotonic()})
        for number in [signal.SIGINT,signal.SIGTERM,signal.SIGHUP]:
            self.previous[number]=signal.signal(number,receive)
        return self
    def __exit__(self,*_):
        for number,handler in self.previous.items():signal.signal(number,handler)


class OwnedTree:
    def __init__(self,namespace):
        self.namespace=namespace;self.process=None;self.pgid=None;self.records=[]
        self.leader=None;self.leader_reaped=False;self.signals=BoundedHistory();self.reaps=[]
    def attach(self,process):
        self.process=process;self.pgid=process.pid
    def pin(self,row,direct=False,group=False,parent=None):
        for record in self.records:
            if record['pid']==row['pid'] and record['start_ticks']==row.get('start_ticks') and pidfd_pid(record['fd'])==row['pid']:
                if not exited(record['fd']) or row.get('state')=='Z':return record
        descriptor=os.pidfd_open(row['pid'],0)
        try:
            if direct:
                # ECHILD means this fd is NOT our current adopted/direct child.
                os.waitid(os.P_PIDFD,descriptor,os.WEXITED|os.WNOHANG|os.WNOWAIT)
            elif parent is not None:
                if pidfd_pid(parent['fd'])!=row['ppid'] or exited(parent['fd']):
                    raise GuardError('lineage_parent_no_longer_live')
                parent_now=read_stat(parent['pid'])
                if parent_now['start_ticks']!=parent['start_ticks']:raise GuardError('lineage_parent_identity_changed')
            else:
                if not group:raise GuardError('no_ownership_proof_for_pidfd')
                self.assert_group_owned()
            after=read_stat(row['pid'])
            for key in ['pid','ppid','pgid','sid','start_ticks']:
                if after[key]!=row[key]:raise GuardError('identity_changed_while_pinning')
            if pidfd_pid(descriptor)!=row['pid']:raise GuardError('pidfd_identity_changed_while_pinning')
            if parent is not None and (pidfd_pid(parent['fd'])!=row['ppid'] or exited(parent['fd'])):
                raise GuardError('lineage_parent_changed_during_pin')
            record=dict(after,fd=descriptor,proof='kernel_direct_child' if direct else 'verified_parent_pidfd_lineage' if parent is not None else 'held_original_session_group')
            self.records.append(record);return record
        except BaseException:
            os.close(descriptor);raise
    def establish(self):
        row=read_stat(self.process.pid)
        self.leader=self.pin(row,direct=True)
        self.assert_group_owned()
    def assert_group_owned(self):
        if self.leader_reaped or self.process is None:raise GuardError('no_reserved_leader')
        os.waitid(os.P_PID,self.process.pid,os.WEXITED|os.WNOHANG|os.WNOWAIT)
        if os.getpgid(self.process.pid)!=self.pgid or os.getsid(self.process.pid)!=self.pgid:
            raise GuardError('leader_group_or_session_changed')
        if self.leader is not None:
            row=read_stat(self.process.pid)
            if row['start_ticks']!=self.leader['start_ticks']:raise GuardError('leader_identity_changed')
    def leader_done(self):
        if self.leader is None:return False
        return exited(self.leader['fd'])
    def scan(self):
        if os.readlink('/proc/self/ns/pid')!=self.namespace:raise GuardError('namespace_changed')
        inventory=proc_inventory();direct=children()
        # New direct children can only be this Popen leader or descendants
        # adopted by our dedicated process-local subreaper.
        for pid in direct:
            if pid not in inventory:raise GuardError('direct_child_missing_stat')
            self.pin(inventory[pid],direct=True)
        try:self.assert_group_owned();held=True
        except (ChildProcessError,ProcessLookupError,GuardError):held=False
        if held:
            for row in inventory.values():
                if row['pgid']==self.pgid:
                    if row['sid']!=self.pgid:raise GuardError('foreign_session_in_original_group')
                    self.pin(row,group=True)
        roots={record['pid'] for record in self.records if pidfd_pid(record['fd'])==record['pid'] and record['pid'] in inventory and
               inventory[record['pid']]['start_ticks']==record['start_ticks']}
        lineage=set(roots)
        for _ in range(len(inventory)+1):
            added={pid for pid,row in inventory.items() if row['ppid'] in lineage}-lineage
            if not added:break
            for pid in added:
                row=inventory[pid]
                parent=next(record for record in self.records if record['pid']==row['ppid'] and pidfd_pid(record['fd'])==row['ppid'])
                self.pin(row,parent=parent)
            lineage.update(added)
        rows=[inventory[pid] for pid in lineage if pid in inventory]
        escaped=[row for row in rows if row['pgid']!=self.pgid or row['sid']!=self.pgid]
        return {'rows':rows,'direct':direct,'escaped':escaped,'held_leader':held,'inventory':inventory}
    def sample(self,rss_reader):
        scan=self.scan();output=[]
        for row in scan['rows']:
            try:value=rss_reader(row)
            except (FileNotFoundError,GuardError):
                current=read_stat(row['pid'])
                if current['start_ticks']==row['start_ticks'] and current['state']=='Z':value=0
                else:raise
            if not isinstance(value,int) or isinstance(value,bool) or value<0:raise GuardError('invalid_live_RSS_sample')
            current=read_stat(row['pid'])
            if current['start_ticks']!=row['start_ticks']:raise GuardError('RSS_identity_changed')
            output.append(dict(current,rss=value))
        return scan,output
    def signal_owned(self,number):
        group_sent=False;failures=[]
        try:
            self.assert_group_owned();os.killpg(self.pgid,number);group_sent=True
            self.signals.append({'kind':'reserved_original_group','pgid':self.pgid,'signal':number,'at':time.monotonic()})
        except (ChildProcessError,ProcessLookupError,GuardError):
            pass  # ECHILD/stale PGID never grants a group signal.
        except BaseException as error:
            failures.append('group_signal:'+repr(error))
        for record in list(self.records):
            if exited(record['fd']):continue
            # A retained pidfd targets that exact proven-owned process even
            # after it changes group/session. Never kill its new group.
            try:
                signal.pidfd_send_signal(record['fd'],number,None,0)
                self.signals.append({'kind':'owned_pidfd','pid':record['pid'],'start_ticks':record['start_ticks'],
                                     'proof':record['proof'],'signal':number,'at':time.monotonic()})
            except ProcessLookupError:pass
            except BaseException as error:failures.append('pidfd_signal:'+repr(error))
        if failures:raise GuardError(';'.join(failures))
        return group_sent
    def reap(self):
        # Called only after two successful whole-lineage quiescent scans.
        for record in sorted(self.records,key=lambda r:r['pid']==self.process.pid):
            if record.get('reaped'):continue
            try:status=os.waitid(os.P_PIDFD,record['fd'],os.WEXITED|os.WNOHANG)
            except ChildProcessError:
                if not exited(record['fd']):raise GuardError('live_child_not_waitable')
                continue
            if status is None:raise GuardError('child_became_live_before_reap')
            self.reaps.append({'pid':record['pid'],'start_ticks':record['start_ticks'],'si_code':status.si_code,'si_status':status.si_status})
            record['reaped']=True
            if record['pid']==self.process.pid:
                self.process.returncode=status.si_status if status.si_code==os.CLD_EXITED else -status.si_status
                self.leader_reaped=True
        if not self.leader_reaped:raise GuardError('leader_wait_not_verified')
        remaining=children();inventory=proc_inventory()
        original_group=[row for row in inventory.values() if row['pgid']==self.pgid]
        if remaining or original_group:raise GuardError('post_reap_inventory_not_empty_HOLD')
        return {'leader_reaped':True,'owned_descendants_reaped_or_confirmed_exited':True,
                'direct_children_empty':True,'original_group_empty':True,'reaps':self.reaps}
    def close_fds(self):
        for record in self.records:os.close(record['fd'])


def validate_limits(limits):
    for key in ['own_rss','start_raw','start_effective','runtime_raw','runtime_effective','wall_seconds','max_sample_gap']:
        value=limits[key]
        if not isinstance(value,(int,float)) or isinstance(value,bool) or not math.isfinite(value) or value<=0:
            raise GuardError('invalid_limit:'+key)
    if limits['wall_seconds']<=2.6:raise GuardError('no_cleanup_reserve')


def validate_memory(sample,baseline,limits,admission=False):
    for key in ['maximum','current']:
        if not isinstance(sample[key],int) or isinstance(sample[key],bool) or sample[key]<0:raise GuardError('invalid_memory_value:'+key)
    if sample['maximum']<=0:raise GuardError('invalid_memory_maximum')
    for key in ['raw','effective']:
        if not isinstance(sample['budget'][key],(int,float)) or not math.isfinite(sample['budget'][key]):raise GuardError('invalid_budget_sample')
    for key in ['high','max','oom','oom_kill','oom_group_kill']:
        if not isinstance(sample['events'][key],int) or isinstance(sample['events'][key],bool) or sample['events'][key]<0:raise GuardError('invalid_event_counter:'+key)
        if baseline is not None and sample['events'][key]!=baseline['events'][key]:raise GuardError('memory_event_changed:'+key)
    if baseline is not None and sample['maximum']!=baseline['maximum']:raise GuardError('memory_limit_changed')
    if admission:
        if sample['budget']['raw']<=limits['start_raw'] or sample['budget']['effective']<=limits['start_effective']:raise GuardError('admission_refused')
    elif sample['budget']['raw']<limits['runtime_raw'] or sample['budget']['effective']<limits['runtime_effective']:
        raise GuardError('runtime_reserve')


def cleanup_held(tree,output,emergency,fixture_hook=None,observe=None):
    """Never returns while cleanup/ownership is uncertain. No stale-PGID kill.

    Persistent HOLD keeps this live controller, subreaper and pidfds resident.
    It is a failure requiring coordination, not a successful timeout return.
    """
    start=time.monotonic();last_status=0.;errors=BoundedHistory();quiet=0;rounds=0
    while True:
        now=time.monotonic();elapsed=now-start
        try:
            if fixture_hook:fixture_hook(rounds)
            if observe:
                try:observe()
                except BaseException as error:
                    errors.append('cleanup_resources:'+repr(error));emergency=True
            scan=tree.scan()
            live=[row for row in scan['rows'] if row['state']!='Z']
            live_fds=[row for row in tree.records if not exited(row['fd'])]
            quiet=quiet+1 if not live and not live_fds else 0
            if quiet>=2:return dict(tree.reap(),errors=errors,error_count=errors.total,held_seconds=elapsed)
            sig=signal.SIGKILL if emergency or elapsed>=.30 else signal.SIGINT if elapsed<.15 else signal.SIGTERM
            if live or live_fds:tree.signal_owned(sig)
        except BaseException as error:
            quiet=0;errors.append(type(error).__name__+':'+str(error))
            # Existing, pinned identities remain safe even if discovery failed.
            try:tree.signal_owned(signal.SIGKILL if emergency or elapsed>=.30 else signal.SIGTERM)
            except BaseException as signal_error:errors.append('signal:'+repr(signal_error))
        # Neither a receipt write failure nor repeated cancellation may unwind
        # this live ownership controller. All paths stay inside the hold loop.
        try:
            if elapsed>=1.5 and now-last_status>=1.0:
                (output/'HOLD.json').write_text(json.dumps({'status':'PERSISTENT_OWNERSHIP_HOLD','leader_pid':tree.process.pid,
                 'leader_reaped':tree.leader_reaped,'namespace':tree.namespace,'seconds':elapsed,'recent_errors':errors[-20:],
                 'no_later_engine_allowed':True,'controller_retains_pidfds_and_subreaper':True},indent=2));last_status=now
            time.sleep(.025 if elapsed<1.5 else .25)
        except BaseException as error:errors.append('hold_notification_or_wait:'+repr(error))
        rounds+=1


def run_guarded(command,output,limits,*,environment=None,_fixture_system=None,_fixture_rss=None,
                _fixture_hook=None,_fixture_cleanup_hook=None):
    output=Path(output);output.mkdir(parents=True,exist_ok=False)
    memory_reader=_fixture_system or system_sample;rss_reader=_fixture_rss or read_rss
    report={'schema':'loot-owned-tree-guard-2','command':command,'limits':limits,
            'namespace':os.readlink('/proc/self/ns/pid'),'started':False,'reason':'','peak_owned_rss':0,
            'peak_leader_rss':0,'max_observed_sample_gap':0.,'max_observed_rss_burst':0,
            'max_observed_cgroup_current_burst':0,'cgroup_burst_is_observed_delta_not_hard_rate_bound':True,
            'fixture_injections':bool(_fixture_system or _fixture_rss or _fixture_hook or _fixture_cleanup_hook)}
    tree=OwnedTree(report['namespace']);reaper=None;started=time.monotonic();baseline=None
    raw_tail=b'';raw_offset=0;raw_errors=set()
    markers=[b'Traceback',b'AssertionError',b'SCRIPT ERROR',b'SHADER ERROR',b'ERROR:',b'Parse Error',b'Compile Error',b'resources still in use',b'ObjectDB instances leaked']
    def raw_chunk():
        nonlocal raw_tail,raw_offset
        path=output/'raw.log'
        if not path.exists():return False
        with path.open('rb') as stream:stream.seek(raw_offset);block=stream.read(65536)
        raw_offset+=len(block);joined=raw_tail+block
        for marker in markers:
            if marker in joined:raw_errors.add(marker.decode())
        raw_tail=joined[-160:];return bool(block)
    try:
        validate_limits(limits)
        if len(list(Path('/proc/self/task').iterdir()))!=1:raise GuardError('dedicated_controller_not_single_threaded')
        if children():raise GuardError('dedicated_controller_has_preexisting_children')
        baseline=memory_reader();validate_memory(baseline,None,limits,True);report['before']=baseline
        with DeferredCancellation() as cancellation,LocalSubreaper() as reaper, (output/'raw.log').open('w') as log, (output/'samples.jsonl').open('w') as samples:
            last_end=None;previous_rss=0;previous_current=baseline['current'];emergency=False
            try:
                last_end=time.monotonic()  # First observation includes launch and identity establishment.
                process=subprocess.Popen(command,stdin=subprocess.DEVNULL,stdout=log,stderr=subprocess.STDOUT,start_new_session=True,env=environment)
                tree.attach(process);report['started']=True;report['pid']=process.pid;report['pgid']=process.pid
                tree.establish()
                while True:
                    begin=time.monotonic();scan,rows=tree.sample(rss_reader);memory=memory_reader();end=time.monotonic()
                    gap=begin-last_end;interval=end-last_end;aggregate=sum(row['rss'] for row in rows)
                    burst=max(0,aggregate-previous_rss)
                    current_delta=memory['current']-previous_current
                    report['peak_owned_rss']=max(report['peak_owned_rss'],aggregate)
                    report['peak_leader_rss']=max(report['peak_leader_rss'],next((r['rss'] for r in rows if r['pid']==process.pid),0))
                    report['max_observed_rss_burst']=max(report['max_observed_rss_burst'],burst)
                    report['max_observed_cgroup_current_burst']=max(report['max_observed_cgroup_current_burst'],current_delta)
                    samples.write(json.dumps({'monotonic_start':begin,'monotonic_end':end,'gap':gap,'duration':end-begin,
                        'observation_interval':interval,'cgroup_current_delta':current_delta,
                        'owned_rss':aggregate,'rss_burst':burst,'members':rows,'escaped':scan['escaped'],'memory':memory})+'\n');samples.flush()
                    written=time.monotonic();through_write=written-last_end
                    report['max_observed_sample_gap']=max(report['max_observed_sample_gap'],through_write)
                    report.setdefault('timing',[]).append({'observation_end':end,'trace_flushed_at':written,
                        'trace_write_seconds':written-end,'interval_through_trace_write':through_write})
                    last_end=end;previous_rss=aggregate;previous_current=memory['current']
                    if _fixture_hook:_fixture_hook(rows)
                    validate_memory(memory,baseline,limits)
                    if aggregate>limits['own_rss'] or burst>limits['own_rss']:emergency=True;raise GuardError('owned_aggregate_RSS')
                    if through_write>limits['max_sample_gap']:emergency=True;raise GuardError('sample_gap_untrusted')
                    if scan['escaped']:emergency=True;raise GuardError('owned_descendant_escaped_group')
                    if cancellation.requests:raise GuardError('controller_cancel_requested')
                    raw_chunk()
                    if raw_errors:raise GuardError('raw_error')
                    if time.monotonic()-started>=limits['wall_seconds']-2.5:raise GuardError('wall_cleanup_reserve')
                    if tree.leader_done():
                        if any(row['pid']!=process.pid and row['state']!='Z' for row in rows):raise GuardError('leader_exited_with_live_descendant')
                        break
                    time.sleep(.05)
            except BaseException as error:
                report['reason']=type(error).__name__+':'+str(error)
                if any(term in report['reason'] for term in ['RSS','memory','sample','counter','reserve']):emergency=True
            finally:
                if tree.process is not None:
                    def cleanup_observe():
                        point=memory_reader();validate_memory(point,baseline,limits)
                        samples.write(json.dumps({'phase':'cleanup','monotonic':time.monotonic(),'memory':point})+'\n');samples.flush()
                    report['cleanup']=cleanup_held(tree,output,emergency,_fixture_cleanup_hook,cleanup_observe)
                    report['exit']=tree.process.returncode;report['signals']=tree.signals
                    report['signal_count']=tree.signals.total
                report['cancellation_requests']=cancellation.requests
                report['cancellation_count']=cancellation.requests.total
    except BaseException as error:
        report['reason']=report['reason'] or type(error).__name__+':'+str(error)
    finally:
        # A returned call has no unresolved live owned process: cleanup_held
        # would still be holding the controller instead of reaching here.
        try:
            after=memory_reader();report['after']=after
            if baseline is not None:validate_memory(after,baseline,limits)
        except BaseException as error:report['reason']+='|terminal_memory:'+repr(error)
        try:
            while raw_chunk():pass
        except BaseException as error:report['reason']+='|terminal_log:'+repr(error)
        report['raw_errors']=sorted(raw_errors)
        if raw_errors:report['reason']=report['reason'] or 'raw_error_after_exit'
        report['local_subreaper_restored']=reaper.restored if reaper is not None else None
        report['elapsed']=time.monotonic()-started
        clean=report.get('cleanup',{})
        if clean.get('errors') and not report['reason']:report['reason']='cleanup_errors_preserved'
        report['passed']=not report['reason'] and report.get('exit')==0 and clean.get('leader_reaped',False) and clean.get('direct_children_empty',False) and clean.get('original_group_empty',False) and not clean.get('errors')
        tree.close_fds()
        (output/'exit.json').write_text(json.dumps(report,indent=2))
    return report
