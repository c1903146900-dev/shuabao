"""Pure actual legacy proof tests; no real pidfds, child processes, or signals."""
import errno,importlib.util,json,os,select,sys
from pathlib import Path
from types import SimpleNamespace,MethodType
from unittest.mock import patch
R=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('swap_candidate',R/'owned_runtime_guard.py');g=importlib.util.module_from_spec(spec);spec.loader.exec_module(g)
h=sys.modules['held_exit_adapter'];checks=[]
row={'pid':123,'start_ticks':7,'state':'S','rss':4096}
def make_tree(records=None):
    t=SimpleNamespace(namespace=os.readlink('/proc/self/ns/pid'),records=records if records is not None else [{'pid':123,'start_ticks':7,'fd':999}])
    t.terminal_omission=MethodType(h.OwnedTree.terminal_omission,t);return t
def call(t,stat_error=None,state='Z',start=7,events=select.POLLIN,swap_error=None):
    with patch.object(g,'swap_bytes',side_effect=swap_error or FileNotFoundError(errno.ENOENT,'gone')),patch.object(h,'pidfd_pid',return_value=123),patch.object(h,'pidfd_events',return_value=events),patch.object(h,'read_stat',side_effect=stat_error,return_value={'pid':123,'start_ticks':start,'state':state}):
        return g.owned_swap_bytes(t,row)
def reject(name,fn):
    try:fn()
    except (g.GuardError,OSError):checks.append(name);return
    raise AssertionError(name)
t=make_tree();assert call(t)==0 and row['rss']==4096 and len(t.held_exit_evidence)==1;checks.append('exact_held_terminal_twice_POLLIN_swap_zero_RSS_retained')
t=make_tree();assert call(t,stat_error=FileNotFoundError(errno.ENOENT,'gone'))==0;checks.append('exact_held_absent_twice_POLLIN')
reject('still_live_rejected',lambda:call(make_tree(),state='S'))
reject('PID_reused_rejected',lambda:call(make_tree(),start=8))
reject('pidfd_not_exited_rejected',lambda:call(make_tree(),events=0))
reject('no_owned_record_rejected',lambda:call(make_tree([])))
reject('duplicate_identity_rejected',lambda:call(make_tree([{'pid':123,'start_ticks':7,'fd':998},{'pid':123,'start_ticks':7,'fd':999}])))
reject('permission_denied_rejected',lambda:call(make_tree(),swap_error=PermissionError(errno.EACCES,'denied')))
reject('missing_VmSwap_live_rejected',lambda:call(make_tree(),swap_error=g.GuardError('invalid_memory_field:VmSwap')))
with patch.object(g,'swap_bytes',return_value=1024):assert g.owned_swap_bytes(make_tree([]),row)==1024
checks.append('normal_measured_swap_unchanged')
with patch.object(g.Path,'read_text',side_effect=FileNotFoundError(errno.ENOENT,'gone')):
    reject('self_swap_missing_stays_strict',lambda:g.swap_bytes(row))
result={'status':'PURE_FAKE_RACE_ONLY_NO_CHILDREN_ENGINE_OR_REAL_PIDFD','count':len(checks),'checks':checks};(R/'PURE_SWAP_RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
