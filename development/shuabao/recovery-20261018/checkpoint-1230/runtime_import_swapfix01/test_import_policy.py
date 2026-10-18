"""Pure file-policy tests; never calls run, Popen, or an engine."""
import importlib.util,json,tempfile
from pathlib import Path
R=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('import_candidate',R/'official_import_guard.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
checks=[]
def ok(name,condition):
    assert condition,name
    checks.append(name)
def rejects(name,fn):
    try:fn()
    except (RuntimeError,ValueError):checks.append(name);return
    raise AssertionError(name)
before={'project.godot':'a','art.png':'b','art.png.import':'c'}
ok('fixed_normal_editor_flags',m.fixed_args([])==['--editor','--import','--quit'])
for flag in ['--headless','--path','--script','--quit-after']:
    rejects('reject_extra_'+flag,lambda:m.fixed_args([flag]))
ok('unchanged',m.post_diff(before,dict(before))['accepted'])
for key in before:
    changed=dict(before);changed[key]='d';ok('changed_reject_'+key,not m.post_diff(before,changed)['accepted'])
missing=dict(before);missing.pop('art.png');ok('removed_reject',not m.post_diff(before,missing)['accepted'])
ok('new_cache_allowed',m.post_diff(before,{**before,'.godot/imported/a.ctex':'d'})['accepted'])
ok('new_associated_uid_allowed',m.post_diff(before,{**before,'art.png.uid':'d'})['accepted'])
for rel in ['unrelated.uid','art.png.import.uid','new.gd','new.png','.godot']:
    ok('unknown_add_reject_'+rel,not m.post_diff(before,{**before,rel:'d'})['accepted'])
with tempfile.TemporaryDirectory() as d:
    root=Path(d);(root/'a').write_text('x');ok('inventory_actual',m.inventory(root)=={'a':m.sha(root/'a')})
    (root/'link').symlink_to(root/'a');rejects('symlink_reject',lambda:m.inventory(root))
result={'status':'PURE_POLICY_ONLY_NO_PROCESS_OR_ENGINE','count':len(checks),'checks':checks}
(R/'PURE_IMPORT_RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
