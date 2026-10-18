"""Narrow held-pidfd inventory exit race. Frozen ownership modules unchanged.
Only an already-pinned same PID/start identity, terminal readable pidfd and a
fresh absent stat permit one stale row to leave this sample. No reaping/signals,
retry, missing-RSS zero, threshold change or discarded cleanup record.
"""
import errno,os,select
from safe_tree_guard import (GuardError,BoundedHistory,proc_inventory,children,
                            read_stat,pidfd_pid,exited)
from safe_tree_guard_rss_exit01 import OwnedTree as RSSExitOwnedTree,pidfd_events

class OwnedTree(RSSExitOwnedTree):
    def _prove_reaped_inventory_row(self,row,error):
        if not hasattr(self,'reaped_inventory_evidence'):self.reaped_inventory_evidence=BoundedHistory()
        evidence={'pid':row['pid'],'start_ticks':row['start_ticks'],'original_errno':error.errno,
                  'excluded':False,'reaped_by_probe':False,'RSS_zero_substituted':False,'cleanup_record_retained':True}
        try:
            if error.errno!=errno.ESRCH:raise error
            records=[record for record in self.records if record['pid']==row['pid'] and record['start_ticks']==row['start_ticks'] and not record.get('reaped',False)]
            if len(records)!=1:raise GuardError('reaped_inventory_missing_or_ambiguous_held_identity')
            record=records[0];descriptor=record['fd']
            kernel_pid=pidfd_pid(descriptor);evidence['pidfd_kernel_pid']=kernel_pid
            if kernel_pid not in (row['pid'],-1):raise GuardError('reaped_inventory_pidfd_identity_changed')
            mask=pidfd_events(descriptor);evidence['pidfd_events']=mask
            if not mask&select.POLLIN:raise GuardError('reaped_inventory_pidfd_not_terminal')
            try:current=read_stat(row['pid'])
            except FileNotFoundError as absent:
                if absent.errno!=errno.ENOENT:raise
                evidence['fresh_stat_absent']=True
            else:
                evidence['fresh_stat_identity']={'pid':current['pid'],'start_ticks':current['start_ticks'],'state':current['state']}
                if current['pid']!=row['pid'] or current['start_ticks']!=row['start_ticks']:
                    raise GuardError('reaped_inventory_PID_reused_or_identity_changed')
                raise GuardError('reaped_inventory_stat_still_present')
            evidence['terminal_identity_proven']=True;return True
        except BaseException as problem:
            evidence['proof_error']=repr(problem);raise
        finally:self.reaped_inventory_evidence.append(evidence)

    def pin(self,row,direct=False,group=False,parent=None):
        # Frozen pin logic, with only the pidfd_open ESRCH call site extended.
        for record in self.records:
            if record['pid']==row['pid'] and record['start_ticks']==row.get('start_ticks') and pidfd_pid(record['fd'])==row['pid']:
                if not exited(record['fd']) or row.get('state')=='Z':return record
        try:descriptor=os.pidfd_open(row['pid'],0)
        except ProcessLookupError as error:
            self._prove_reaped_inventory_row(row,error)
            return None
        try:
            if direct:
                os.waitid(os.P_PIDFD,descriptor,os.WEXITED|os.WNOHANG|os.WNOWAIT)
            elif parent is not None:
                if pidfd_pid(parent['fd'])!=row['ppid'] or exited(parent['fd']):raise GuardError('lineage_parent_no_longer_live')
                parent_now=read_stat(parent['pid'])
                if parent_now['start_ticks']!=parent['start_ticks']:raise GuardError('lineage_parent_identity_changed')
            else:
                if not group:raise GuardError('no_ownership_proof_for_pidfd')
                self.assert_group_owned()
            after=read_stat(row['pid'])
            for key in ['pid','ppid','pgid','sid','start_ticks']:
                if after[key]!=row[key]:raise GuardError('identity_changed_while_pinning')
            if pidfd_pid(descriptor)!=row['pid']:raise GuardError('pidfd_identity_changed_while_pinning')
            if parent is not None and (pidfd_pid(parent['fd'])!=row['ppid'] or exited(parent['fd'])):raise GuardError('lineage_parent_changed_during_pin')
            record=dict(after,fd=descriptor,proof='kernel_direct_child' if direct else 'verified_parent_pidfd_lineage' if parent is not None else 'held_original_session_group')
            self.records.append(record);return record
        except BaseException:
            os.close(descriptor);raise

    def scan(self):
        # Frozen scan order and proof paths; only proven vanished rows are
        # removed from this local snapshot before lineage/RSS uses it.
        if os.readlink('/proc/self/ns/pid')!=self.namespace:raise GuardError('namespace_changed')
        inventory=proc_inventory();direct=children();excluded=[]
        def pin_current(row,**proof):
            record=self.pin(row,**proof)
            if record is not None:return True
            if excluded:raise GuardError('multiple_reaped_inventory_rows_in_one_sample')
            if any(candidate['ppid']==row['pid'] for candidate in inventory.values()):
                raise GuardError('reaped_inventory_parent_has_unresolved_children')
            excluded.append({'pid':row['pid'],'start_ticks':row['start_ticks']})
            inventory.pop(row['pid'],None);direct.discard(row['pid'])
            self.reaped_inventory_evidence[-1]['excluded']=True
            return False
        for pid in tuple(direct):
            if pid not in inventory:raise GuardError('direct_child_missing_stat')
            pin_current(inventory[pid],direct=True)
        try:self.assert_group_owned();held=True
        except (ChildProcessError,ProcessLookupError,GuardError):held=False
        if held:
            for row in tuple(inventory.values()):
                if row['pgid']==self.pgid:
                    if row['sid']!=self.pgid:raise GuardError('foreign_session_in_original_group')
                    pin_current(row,group=True)
        roots={record['pid'] for record in self.records if pidfd_pid(record['fd'])==record['pid'] and record['pid'] in inventory and inventory[record['pid']]['start_ticks']==record['start_ticks']}
        lineage=set(roots)
        for _ in range(len(inventory)+1):
            added={pid for pid,row in inventory.items() if row['ppid'] in lineage}-lineage
            if not added:break
            admitted=set()
            for pid in added:
                row=inventory[pid]
                parent=next(record for record in self.records if record['pid']==row['ppid'] and pidfd_pid(record['fd'])==row['ppid'])
                if pin_current(row,parent=parent):admitted.add(pid)
            lineage.update(admitted)
        rows=[inventory[pid] for pid in lineage if pid in inventory]
        escaped=[row for row in rows if row['pgid']!=self.pgid or row['sid']!=self.pgid]
        return {'rows':rows,'direct':direct,'escaped':escaped,'held_leader':held,'inventory':inventory,'proven_reaped_rows_excluded':excluded}
