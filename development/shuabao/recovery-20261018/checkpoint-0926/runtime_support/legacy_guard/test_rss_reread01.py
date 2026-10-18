"""Deterministic pure tests. No subprocess, engine, real RSS or timing claims."""
import unittest, json, select
from unittest.mock import patch
from pathlib import Path
import safe_tree_guard_rss_reread01 as g

ROW={'pid':700,'start_ticks':99,'state':'R','ppid':1,'pgid':700,'sid':700}
class Clock:
    def __init__(self,step=.0001):self.value=0.;self.step=step
    def __call__(self):self.value+=self.step;return self.value
class Tests(unittest.TestCase):
    def run_case(self, reader, *, states=None, clock=None, fd_pid=700, events=0, records=True, rows=None):
        tree=object.__new__(g.OwnedTree)
        tree.records=[dict(ROW,fd=9)] if records else []
        tree.scan=lambda:{'rows':rows or [dict(ROW)]}
        state_reader=states or (lambda pid:dict(ROW,pid=pid))
        with patch.object(g,'read_stat',side_effect=state_reader),patch.object(g,'pidfd_pid',return_value=fd_pid),patch.object(g,'pidfd_events',return_value=events),patch.object(g.time,'monotonic',side_effect=clock or Clock()):
            try:return tree,tree.sample(reader)
            finally:self.last_tree=tree
    def missing(self,row):raise g.MissingVmRSS('absent')
    def sequence(self,*items):
        iterator=iter(items)
        def read(row):
            x=next(iterator)
            if isinstance(x,BaseException):raise x
            return x
        return read
    def test_measured_RSS_after_missing(self):
        t,(_,rows)=self.run_case(self.sequence(g.MissingVmRSS('absent'),12345))
        self.assertEqual(rows[0]['rss'],12345);self.assertEqual(t.rss_reread_evidence[-1]['proof'],'same_identity_measured_VmRSS')
    def test_unchanged_normal_reader(self):
        t,(_,rows)=self.run_case(lambda row:12345)
        self.assertEqual(rows[0]['rss'],12345);self.assertEqual(len(t.rss_reread_evidence),0)
    def test_confirmed_Z(self):
        _,(_,rows)=self.run_case(self.missing,states=lambda pid:dict(ROW,state='Z'))
        self.assertEqual(rows[0]['rss'],0)
    def test_confirmed_X(self):
        _,(_,rows)=self.run_case(self.missing,states=lambda pid:dict(ROW,state='X'))
        self.assertEqual(rows[0]['rss'],0)
    def test_pidfd_terminal(self):
        t,(_,rows)=self.run_case(self.missing,events=select.POLLIN)
        self.assertEqual(rows[0]['rss'],0);self.assertIn('pidfd',t.rss_reread_evidence[-1]['proof'])
    def test_live_missing_timeout(self):
        with self.assertRaisesRegex(g.GuardError,'10ms_timeout'):self.run_case(self.missing,clock=Clock(.004))
        self.assertFalse(self.last_tree.rss_reread_evidence[-1]['resolved'])
    def test_attempt_bound(self):
        with self.assertRaisesRegex(g.GuardError,'attempt_bound'):self.run_case(self.missing,clock=Clock(.000001))
        self.assertEqual(self.last_tree.rss_reread_evidence[-1]['attempts'],128)
    def test_identity_reuse(self):
        with self.assertRaisesRegex(g.GuardError,'identity_changed'):self.run_case(self.missing,states=lambda pid:dict(ROW,start_ticks=100))
    def test_no_held_descriptor(self):
        with self.assertRaisesRegex(g.GuardError,'no_unique'):self.run_case(self.missing,records=False)
    def test_pidfd_mismatch(self):
        with self.assertRaisesRegex(g.GuardError,'pidfd_identity_changed'):self.run_case(self.missing,fd_pid=701)
    def test_permission_immediately_red(self):
        with self.assertRaises(PermissionError):self.run_case(self.sequence(g.MissingVmRSS('absent'),PermissionError('denied')))
        self.assertEqual(self.last_tree.rss_reread_evidence[-1]['attempts'],1)
    def test_IO_immediately_red(self):
        with self.assertRaises(OSError):self.run_case(self.sequence(g.MissingVmRSS('absent'),OSError(5,'I/O')))
    def test_malformed_immediately_red(self):
        with self.assertRaisesRegex(g.GuardError,'missing_or_invalid'):self.run_case(self.sequence(g.GuardError('missing_or_invalid_live_RSS:700')))
        self.assertEqual(len(self.last_tree.rss_reread_evidence),0)
    def test_slow_read_result_not_accepted(self):
        with self.assertRaisesRegex(g.GuardError,'10ms_timeout'):self.run_case(self.sequence(g.MissingVmRSS('absent'),400),clock=Clock(.0035))
    def test_reuse_after_valid_RSS(self):
        calls=[0]
        def state(pid):
            calls[0]+=1;return dict(ROW,start_ticks=99 if calls[0]==1 else 100)
        with self.assertRaisesRegex(g.GuardError,'identity_changed'):self.run_case(self.sequence(g.MissingVmRSS('absent'),400),states=state)
    def test_second_missing_row_does_not_get_new_deadline(self):
        tree=object.__new__(g.OwnedTree);tree.records=[dict(ROW,fd=9),dict(ROW,pid=701,fd=10)]
        tree.scan=lambda:{'rows':[dict(ROW),dict(ROW,pid=701)]}
        attempts={700:0,701:0}
        def reader(row):
            attempts[row['pid']]+=1
            if attempts[row['pid']]==1:raise g.MissingVmRSS('absent')
            return 50
        with patch.object(g,'read_stat',side_effect=lambda pid:dict(ROW,pid=pid)),patch.object(g,'pidfd_pid',side_effect=lambda fd:700 if fd==9 else 701),patch.object(g,'pidfd_events',return_value=0),patch.object(g.time,'monotonic',side_effect=Clock(.0012)):
            with self.assertRaisesRegex(g.GuardError,'10ms_timeout'):tree.sample(reader)
        self.assertEqual(len(tree.rss_reread_evidence),2)
        self.assertEqual(tree.rss_reread_evidence[0]['deadline'],tree.rss_reread_evidence[1]['deadline'])
    def test_absent_and_invalid_fields_distinct(self):
        with patch.object(g.Path,'read_text',return_value='Name: fake\n'):
            with self.assertRaises(g.MissingVmRSS):g.read_rss(ROW)
        for text in ['VmRSS: nonsense\n','VmRSS: 1 kB\nVmRSS: 2 kB\n']:
            with patch.object(g.Path,'read_text',return_value=text):
                with self.assertRaises(g.GuardError) as caught:g.read_rss(ROW)
                self.assertNotIsInstance(caught.exception,g.MissingVmRSS)
    def test_outer_resource_limits_unchanged(self):
        folder=Path(__file__).parent
        old=(folder/'real_resource_guard_vanished_child01.py').read_text()
        new=(folder/'real_resource_guard_rss_reread01.py').read_text()
        normalized=new.replace('from safe_tree_guard_rss_reread01 import OwnedTree, read_rss','from safe_tree_guard_vanished_child01 import OwnedTree')
        normalized=normalized.replace("        report['rss_reread_evidence']=list(getattr(tree,'rss_reread_evidence',[]))\n        report['rss_reread_evidence_count']=getattr(getattr(tree,'rss_reread_evidence',None),'total',0)\n",'')
        self.assertEqual(normalized,old)
if __name__=='__main__':unittest.main(verbosity=2)
