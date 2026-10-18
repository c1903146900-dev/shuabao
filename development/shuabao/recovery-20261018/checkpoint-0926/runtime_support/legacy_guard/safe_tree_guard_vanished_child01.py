"""Prospective vanished, never-pinned direct child classification.
No child terminal-handle claim, signal, reap, zero-RSS substitution or peak proof.
A complete fresh inventory, retained live parent and reserved original group
must independently support this one-sample omission. Frozen held-row path stays.
"""
import ctypes,errno,os
from safe_tree_guard import GuardError,BoundedHistory,proc_inventory,read_stat,pidfd_pid,exited
from safe_tree_guard_reaped_trace02 import OwnedTree as TraceTree

def subreaper_enabled():
    libc=ctypes.CDLL(None,use_errno=True);value=ctypes.c_int()
    if libc.prctl(37,ctypes.byref(value),ctypes.c_ulong(0),ctypes.c_ulong(0),ctypes.c_ulong(0))!=0:
        raise OSError(ctypes.get_errno(),'PR_GET_CHILD_SUBREAPER')
    return value.value==1

class OwnedTree(TraceTree):
    def _prove_reaped_inventory_row(self,row,error):
        # Any previous child identity uses the original strict held-handle path.
        if any(record['pid']==row['pid'] for record in self.records):
            return super()._prove_reaped_inventory_row(row,error)
        if not hasattr(self,'reaped_inventory_evidence'):self.reaped_inventory_evidence=BoundedHistory()
        evidence={'classification':'vanished_unpinned_child_inventory_only',
                  'pid':row['pid'],'start_ticks':row['start_ticks'],'cached_row':dict(row),
                  'excluded':False,'child_pidfd_acquired':False,'child_terminal_identity_proven':False,
                  'child_peak_RSS_observed':False,'RSS_zero_substituted':False,'reaped_by_probe':False,
                  'signal_sent_by_probe':False,'ownership_tombstone_only':True,
                  'limitation':'Short-lived child peak was not sampled; no inference of zero RSS'}
        try:
            if error.errno!=errno.ESRCH:raise error
            if os.readlink('/proc/self/ns/pid')!=self.namespace:raise GuardError('vanished_child_namespace_changed')
            if row['pgid']!=self.pgid or row['sid']!=self.pgid:
                raise GuardError('vanished_child_outside_reserved_group')
            self.assert_group_owned()
            if not subreaper_enabled():raise GuardError('vanished_child_subreaper_not_retained')
            parents=[r for r in self.records if r['pid']==row['ppid'] and not r.get('reaped',False)]
            if len(parents)!=1:raise GuardError('vanished_child_parent_not_uniquely_held')
            parent=parents[0]
            if row['start_ticks']<parent['start_ticks']:raise GuardError('vanished_child_predates_parent')
            def verify_parent():
                if pidfd_pid(parent['fd'])!=parent['pid'] or exited(parent['fd']):
                    raise GuardError('vanished_child_parent_not_live')
                current=read_stat(parent['pid'])
                if current['pid']!=parent['pid'] or current['start_ticks']!=parent['start_ticks'] or current['state'] in ['Z','X']:
                    raise GuardError('vanished_child_parent_identity_changed')
                if current['pgid']!=self.pgid or current['sid']!=self.pgid:
                    raise GuardError('vanished_child_parent_left_group')
                return {key:current[key] for key in ['pid','ppid','pgid','sid','start_ticks','state']}
            evidence['parent_before']=verify_parent()
            try:current=read_stat(row['pid'])
            except FileNotFoundError as absent:
                if absent.errno!=errno.ENOENT:raise
            else:raise GuardError('vanished_child_stat_present_or_reused')
            fresh=proc_inventory() # Same-namespace complete inventory or exception.
            if row['pid'] in fresh:raise GuardError('vanished_child_present_in_fresh_inventory')
            parent_fresh=fresh.get(parent['pid'])
            if parent_fresh is None or parent_fresh['start_ticks']!=parent['start_ticks']:
                raise GuardError('vanished_child_parent_missing_from_inventory')
            if any(item['ppid']==row['pid'] for item in fresh.values()):
                raise GuardError('vanished_child_unresolved_descendant')
            held={(r['pid'],r['start_ticks'])for r in self.records if not r.get('reaped',False)}
            if any(item['ppid']==os.getpid() and (item['pid'],item['start_ticks'])not in held for item in fresh.values()):
                raise GuardError('vanished_child_unresolved_adopted_child')
            evidence['parent_after']=verify_parent()
            self.assert_group_owned()
            if not subreaper_enabled():raise GuardError('vanished_child_subreaper_lost')
            evidence['complete_inventory_rows']=len(fresh)
            evidence['fresh_stat_absent']=True
            evidence['no_unresolved_dependents']=True
            return True
        except BaseException as problem:
            evidence['proof_error']=repr(problem);raise
        finally:self.reaped_inventory_evidence.append(evidence)

    def scan(self):
        result=super().scan()
        # Never rename an unpinned disappearance as held-pidfd terminal proof.
        classified={(e['pid'],e['start_ticks'])for e in getattr(self,'reaped_inventory_evidence',[])
                    if e.get('excluded') and e.get('classification')=='vanished_unpinned_child_inventory_only'}
        rows=result.get('proven_reaped_rows_excluded',[])
        result['vanished_unpinned_rows_excluded']=[r for r in rows if (r['pid'],r['start_ticks'])in classified]
        result['proven_reaped_rows_excluded']=[r for r in rows if (r['pid'],r['start_ticks'])not in classified]
        return result
