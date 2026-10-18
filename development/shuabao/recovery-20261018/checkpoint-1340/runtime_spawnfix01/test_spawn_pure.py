from pathlib import Path
import ast,errno,json
s=Path(__file__).with_name('owned_runtime_guard.py').read_text();t=ast.parse(s)
ns={'errno':errno,'GuardError':RuntimeError};exec(compile(ast.Module(body=[x for x in t.body if isinstance(x,ast.FunctionDef) and x.name=='foreign_engines'],type_ignores=[]),'<pure>','exec'),ns)
class Tree: records=[]
row={'pid':10,'start_ticks':3,'ppid':1,'pgid':10,'sid':10,'state':'S','comm':'Godot'}
checks=[]
def run(name,current,records,fd,expected):
 def read(pid):
  if isinstance(current,Exception):raise current
  return current
 ns['read_stat']=read;ns['pidfd_pid']=lambda f:fd;tree=Tree();tree.records=records;e=[]
 try: result=ns['foreign_engines'](tree,[row],e);got='foreign' if result else 'clear'
 except Exception:got='error'
 assert got==expected,(name,got);checks.append(name)
held=[{'pid':10,'start_ticks':3,'fd':7}]
run('spawn_pinned_by_sample',row,held,10,'clear')
run('unowned_same_session_reject',row,[],10,'foreign')
run('reused_pid_reject',dict(row,start_ticks=4),held,10,'foreign')
run('wrong_pidfd_reject',row,held,11,'foreign')
run('wrong_record_start_reject',row,[{'pid':10,'start_ticks':2,'fd':7}],10,'foreign')
run('gone_ENOENT',FileNotFoundError(errno.ENOENT,'gone'),[],10,'clear')
run('permission_failure',PermissionError(errno.EACCES,'denied'),held,10,'error')
run('non_ENOENT_failure',FileNotFoundError(errno.EIO,'io'),held,10,'error')
run('unowned_zombie_reject',dict(row,state='Z'),[],10,'foreign')
assert s.index('engine_rows=engine_snapshot();scan,rows=tree.sample(read_rss)')<s.index('foreign=foreign_engines(tree,engine_rows,engine_evidence)');checks.append('snapshot_then_full_sample_then_classify')
print(json.dumps({'passed':True,'checks':checks,'native_status':'NOT_RUN'}))
