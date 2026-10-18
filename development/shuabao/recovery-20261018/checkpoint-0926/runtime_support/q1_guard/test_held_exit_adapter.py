import errno, os, select, sys, unittest
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'legacy_guard'))
import held_exit_adapter as h
class Tests(unittest.TestCase):
 def setUp(self):
  self.t=h.OwnedTree(os.readlink('/proc/self/ns/pid'));self.row=dict(pid=42,start_ticks=7,state='R');self.t.records=[dict(self.row,fd=99)]
 def call(self,kernel=-1,mask=select.POLLIN,state=None):
  state=state if state is not None else FileNotFoundError(errno.ENOENT,'gone')
  with patch.object(h,'pidfd_pid',return_value=kernel),patch.object(h,'pidfd_events',return_value=mask),patch.object(h,'read_stat',side_effect=state if isinstance(state,BaseException) else None,return_value=state):
   self.t.terminal_omission(self.row,h.GuardError('RSS_reread_pidfd_identity_changed'))
 def test_absent(self):
  self.call();self.assertFalse(self.t.held_exit_evidence[-1]['RSS_zero_substituted']);self.assertEqual(len(self.t.records),1)
 def test_zombie(self):self.call(kernel=42,state=dict(self.row,state='Z'))
 def test_live_rejected(self):
  with self.assertRaises(h.GuardError):self.call(state=self.row)
 def test_unreadable_rejected(self):
  with self.assertRaises(h.GuardError):self.call(mask=0)
 def test_reused_pidfd_rejected(self):
  with self.assertRaises(h.GuardError):self.call(kernel=43)
 def test_reused_proc_rejected(self):
  with self.assertRaises(h.GuardError):self.call(state=dict(self.row,start_ticks=8,state='Z'))
 def test_permission_rejected(self):
  with self.assertRaises(PermissionError):self.call(state=PermissionError(errno.EACCES,'denied'))
 def test_ambiguous_rejected(self):
  self.t.records*=2
  with self.assertRaises(h.GuardError):self.call()
 def test_second_read_live_rejected(self):
  with patch.object(h,'pidfd_pid',return_value=-1),patch.object(h,'pidfd_events',return_value=select.POLLIN),patch.object(h,'read_stat',side_effect=[FileNotFoundError(errno.ENOENT,'gone'),self.row]):
   with self.assertRaises(h.GuardError):self.t.terminal_omission(self.row,RuntimeError())
 def test_sample_exact_race_omits(self):
  with patch.object(self.t,'scan',return_value={'rows':[self.row]}),patch.object(self.t,'_resolve_missing',side_effect=h.GuardError('RSS_reread_pidfd_identity_changed')),patch.object(h,'pidfd_pid',return_value=-1),patch.object(h,'pidfd_events',return_value=select.POLLIN),patch.object(h,'read_stat',side_effect=FileNotFoundError(errno.ENOENT,'gone')):
   self.assertEqual(self.t.sample(lambda r: (_ for _ in ()).throw(h.MissingVmRSS()))[1],[])
 def test_sample_resolve_ENOENT_omits(self):
  with patch.object(self.t,'scan',return_value={'rows':[self.row]}),patch.object(self.t,'_resolve_missing',side_effect=FileNotFoundError(errno.ENOENT,'gone')),patch.object(h,'pidfd_pid',return_value=-1),patch.object(h,'pidfd_events',return_value=select.POLLIN),patch.object(h,'read_stat',side_effect=FileNotFoundError(errno.ENOENT,'gone')):
   self.assertEqual(self.t.sample(lambda r: (_ for _ in ()).throw(h.MissingVmRSS()))[1],[])
 def test_sample_other_guard_error_red(self):
  with patch.object(self.t,'scan',return_value={'rows':[self.row]}):
   with self.assertRaises(h.GuardError):self.t.sample(lambda r: (_ for _ in ()).throw(h.GuardError('malformed_RSS')))
if __name__=='__main__':unittest.main()
