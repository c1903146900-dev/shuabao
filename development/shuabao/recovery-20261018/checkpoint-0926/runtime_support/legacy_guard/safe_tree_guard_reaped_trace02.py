"""Diagnostic only for rejected pidfd-open rows. No admission/proof relaxation."""
import os
from safe_tree_guard import read_stat,pidfd_pid,exited
from safe_tree_guard_reaped_row01 import OwnedTree as ReapedRowTree

class OwnedTree(ReapedRowTree):
    def pin(self,row,direct=False,group=False,parent=None):
        previous=getattr(self,'_pin_diagnostic_context',None)
        self._pin_diagnostic_context={'direct_child_path':bool(direct),'held_group_path':bool(group),
                                     'parent_pid':parent.get('pid')if parent is not None else None,
                                     'parent_start_ticks':parent.get('start_ticks')if parent is not None else None}
        try:return super().pin(row,direct=direct,group=group,parent=parent)
        finally:self._pin_diagnostic_context=previous

    def _prove_reaped_inventory_row(self,row,error):
        try:return super()._prove_reaped_inventory_row(row,error)
        except BaseException:
            # These reads provide failure evidence only. All paths rethrow the
            # exact original error; no descriptor acquisition, wait/reap or signal.
            try:
                evidence=self.reaped_inventory_evidence[-1]
                diagnostic={'stage':'pidfd_open_ESRCH_proof_rejected',
                            'failed_row':{key:row.get(key)for key in ['pid','ppid','pgid','sid','start_ticks','state']},
                            'pin_path':getattr(self,'_pin_diagnostic_context',None),
                            'held_record_matches':sum(r['pid']==row['pid']and r['start_ticks']==row['start_ticks']and not r.get('reaped',False)for r in self.records)}
                evidence['rejected_row_diagnostic']=diagnostic
                try:
                    self.assert_group_owned();diagnostic['held_original_leader_group_proven']=True
                except BaseException as problem:
                    diagnostic['held_original_leader_group_proven']=False;diagnostic['leader_proof_error']=type(problem).__name__
                try:
                    current=read_stat(row['pid']);diagnostic['fresh_stat']={'present':True,**{key:current.get(key)for key in ['pid','ppid','pgid','sid','start_ticks','state']}}
                except FileNotFoundError as problem:diagnostic['fresh_stat']={'present':False,'errno':problem.errno}
                except BaseException as problem:diagnostic['fresh_stat']={'read_error':type(problem).__name__,'errno':getattr(problem,'errno',None)}
                parents=[r for r in self.records if r['pid']==row['ppid']and not r.get('reaped',False)]
                diagnostic['retained_parent_count']=len(parents);diagnostic['retained_parents']=[]
                for parent in parents[:2]:
                    item={key:parent.get(key)for key in ['pid','ppid','pgid','sid','start_ticks','state']}
                    diagnostic['retained_parents'].append(item)
                    try:
                        item['pidfd_kernel_pid']=pidfd_pid(parent['fd']);item['pidfd_terminal']=exited(parent['fd'])
                        current=read_stat(parent['pid']);item['fresh_start_ticks']=current['start_ticks'];item['same_identity']=current['start_ticks']==parent['start_ticks']and current['pid']==parent['pid']
                    except BaseException as problem:item['proof_read_error']=type(problem).__name__
            except BaseException:
                try:self.reaped_inventory_evidence[-1]['diagnostic_capture_failed']=True
                except BaseException:pass
            raise
