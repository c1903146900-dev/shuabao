"""Narrow RSS-exit evidence extension. Frozen ownership/cleanup code is unchanged.

No retry/sleep/reap. Missing RSS remains red without current same-identity
Z/X state or a retained owned pidfd/non-reaping waitid exit proof.
"""
import os,select,json
from safe_tree_guard import (GuardError,OwnedTree as FrozenOwnedTree,BoundedHistory,
    DeferredCancellation,LocalSubreaper,children,validate_limits,validate_memory,
    system_sample,read_rss,read_stat,cleanup_held,pidfd_pid)

def pidfd_events(fd):
    poll=select.poll();poll.register(fd,select.POLLIN|select.POLLHUP)
    events=poll.poll(0)
    if any(item_fd!=fd for item_fd,_ in events):raise GuardError('unexpected_pidfd_poll_identity')
    mask=0
    for _,value in events:mask|=value
    if mask&(select.POLLNVAL|select.POLLERR):raise GuardError('invalid_pidfd_poll_events')
    return mask

def waitid_without_reap(fd):
    return os.waitid(os.P_PIDFD,fd,os.WEXITED|os.WNOHANG|os.WNOWAIT)

class OwnedTree(FrozenOwnedTree):
    def missing_rss_exit_proof(self,row,error):
        if not hasattr(self,'rss_exit_evidence'):self.rss_exit_evidence=BoundedHistory()
        evidence={'pid':row['pid'],'start_ticks':row['start_ticks'],'sampled_state':row['state'],
                  'original_error':str(error),'confirmed':False,'reaped_by_probe':False}
        try:
            current=read_stat(row['pid']);evidence['reread_state']=current['state']
            if current['pid']!=row['pid'] or current['start_ticks']!=row['start_ticks']:
                raise GuardError('RSS_exit_identity_changed')
            if current['state'] in ('Z','X'):
                evidence.update(confirmed=True,proof='same_identity_'+current['state']);return current,evidence
            records=[r for r in self.records if r['pid']==row['pid'] and r['start_ticks']==row['start_ticks'] and not r.get('reaped')]
            if len(records)!=1:raise GuardError('RSS_exit_owned_pidfd_missing_or_ambiguous')
            record=records[0];fd=record['fd'];kernel_pid=pidfd_pid(fd);evidence['pidfd_kernel_pid']=kernel_pid
            if kernel_pid!=row['pid']:raise GuardError('RSS_exit_pidfd_identity_changed')
            mask=pidfd_events(fd);evidence['pidfd_events']=mask
            if mask&select.POLLIN:
                evidence.update(confirmed=True,proof='same_identity_owned_pidfd_readable');return current,evidence
            try:info=waitid_without_reap(fd)
            except ChildProcessError as problem:
                evidence['waitid_error']=type(problem).__name__;raise GuardError('RSS_exit_no_kernel_exit_proof')from problem
            evidence['waitid']=None if info is None else {'pid':info.si_pid,'code':info.si_code,'status':info.si_status}
            if info is not None and info.si_pid==row['pid'] and info.si_code in (os.CLD_EXITED,os.CLD_KILLED,os.CLD_DUMPED):
                evidence.update(confirmed=True,proof='same_identity_WNOWAIT_exit');return current,evidence
            raise GuardError('RSS_exit_still_live_or_unproved')
        except BaseException as problem:
            evidence['proof_error']=repr(problem);raise
        finally:self.rss_exit_evidence.append(evidence)

    def sample(self,rss_reader):
        scan=self.scan();output=[]
        for row in scan['rows']:
            evidence=None
            try:value=rss_reader(row)
            except (FileNotFoundError,GuardError)as error:
                if isinstance(error,GuardError)and not str(error).startswith('missing_or_invalid_live_RSS:'):raise
                current,evidence=self.missing_rss_exit_proof(row,error);value=0
            if not isinstance(value,int)or isinstance(value,bool)or value<0:raise GuardError('invalid_live_RSS_sample')
            current=read_stat(row['pid'])
            if current['pid']!=row['pid']or current['start_ticks']!=row['start_ticks']:raise GuardError('RSS_identity_changed')
            item=dict(current,rss=value)
            if evidence is not None:item['rss_exit_proof']=evidence
            output.append(item)
        return scan,output
