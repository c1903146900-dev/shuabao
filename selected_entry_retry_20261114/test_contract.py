"""Deterministic contract/model checks, NOT GDScript execution."""
from pathlib import Path
import unittest
import os
B=Path(os.environ.get('BASE_RUNTIME', '/not-provided'))/'fengli_route_20261024'
C=Path(os.environ.get('CANDIDATE_RUNTIME', '/not-provided'))/'fengli_route_20261024'
def fn(text,name):
 return text.split('func '+name+'(',1)[1].split('\nfunc ',1)[0]
class Model:
 def __init__(self):self.status='awaiting';self.room=False;self.safe=True;self.selection=0;self.commits=0;self.gold=99
 def click(self,node='A'):
  if self.status=='selected':
   if node!='A' or not self.safe or self.room:return False
  elif self.status=='awaiting' and self.safe:self.status='selected';self.selection+=1
  else:return False
  return True
 def enter(self,second=True,commit=True):
  if not self.safe or self.room or self.status!='selected' or not second or not commit:return False
  self.commits+=1;self.room=True;self.status='entered';return True
class Tests(unittest.TestCase):
 @unittest.skipUnless(B.is_dir() and C.is_dir(), "Requires BASE_RUNTIME and CANDIDATE_RUNTIME; models alone do not verify source")
 def test_original_authority_unchanged(self):
  a=(B/'session.gd').read_text();b=(C/'session.gd').read_text()
  for n in ['select_node','next_room_preflight','_enter_selected_node_without_rest','enter_selected_node','_authority','_safe_boundary_reason']:
   if 'func '+n+'(' in a:self.assertEqual(fn(a,n),fn(b,n),n)
  for n in ['row_state.gd']:
   rel='tests/ink_first_floor_user_route_20261005/runtime01/'+n
   self.assertEqual((B.parent/rel).read_bytes(),(C.parent/rel).read_bytes())
 def test_rejections_then_same_retry(self):
  for where in ['first','second','commit']:
   x=Model();self.assertTrue(x.click());x.safe=where!='first'
   self.assertFalse(x.enter(second=where!='second',commit=where!='commit'))
   self.assertEqual((x.selection,x.commits,x.gold),(1,0,99))
   x.safe=True;self.assertFalse(x.click('B'));self.assertTrue(x.click());self.assertTrue(x.enter())
   for _ in range(10):self.assertFalse(x.click());self.assertFalse(x.enter())
   self.assertEqual((x.selection,x.commits,x.gold),(1,1,99))
 def test_committed_but_not_recorded(self):
  x=Model();x.click();x.room=True;x.commits=1
  self.assertFalse(x.click());self.assertFalse(x.enter());self.assertEqual(x.commits,1)
if __name__=='__main__':unittest.main()
