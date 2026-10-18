from pathlib import Path
import ast,json
p=Path(__file__).parent;s=(p/'owned_runtime_guard.py').read_text();old=(p.parent/'runtime_spawnfix01/owned_runtime_guard.py').read_text()
assert s.replace('CLEANUP_AT, KILL_AT = 25., 30.','CLEANUP_AT, KILL_AT = 595., 600.')==old
ns={};tree=ast.parse(s)
for node in tree.body:
 if isinstance(node,ast.Assign) and any(isinstance(t,ast.Tuple) and [x.id for x in t.elts]==['CLEANUP_AT','KILL_AT'] for t in node.targets):exec(compile(ast.Module(body=[node],type_ignores=[]),'<pure>','exec'),ns)
assert 0<ns['CLEANUP_AT']<ns['KILL_AT']<=600
assert ns['CLEANUP_AT']<=595
checks=[]
for elapsed,c,k in [(0,False,False),(24.999,False,False),(25,True,False),(29.999,True,False),(30,True,True),(600,True,True)]:
 assert (elapsed>=ns['CLEANUP_AT'])==c and (elapsed>=ns['KILL_AT'])==k;checks.append(elapsed)
print(json.dumps({'passed':True,'boundary_cases':checks,'single_constant_diff':True,'native_status':'NOT_RUN','kernel_hard_guarantee':False}))
