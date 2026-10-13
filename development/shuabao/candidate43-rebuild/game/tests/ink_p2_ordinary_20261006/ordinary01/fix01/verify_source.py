#!/usr/bin/env python3
"""Existing source preflight plus deterministic Godot name/reflection checks."""
from pathlib import Path
import argparse,ast,hashlib,importlib.util,json,re
D=Path(__file__).resolve().parent;P=D.parent;R=D.parents[3]
PARENT_SHA='6847fc2c3bcb41646198279ff6d48c14bd363b993509b657cab44fb5297869c8'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def relative(path):
 p=Path(path.removeprefix('res://'));assert not p.is_absolute() and '..' not in p.parts and '.godot' not in p.parts;return p
def encode(v):return json.dumps(v,ensure_ascii=False,indent=2)+'\n'
def original():
 spec=importlib.util.spec_from_file_location('p2_original_ordinary_source',P/'verify_source.py')
 module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
 module.verify();return module.collect()

# No separate test framework or engine invocation: these are source preconditions.
BUILTINS=set('AABB Array Basis Callable Color Dictionary NodePath Object PackedByteArray PackedColorArray PackedFloat32Array PackedFloat64Array PackedInt32Array PackedInt64Array PackedStringArray PackedVector2Array PackedVector3Array PackedVector4Array Plane Projection Quaternion Rect2 Rect2i RID Signal String StringName Transform2D Transform3D Vector2 Vector2i Vector3 Vector3i Vector4 Vector4i bool int float Script GDScript Resource Node Control RefCounted SceneTree'.split())
DECL=re.compile(r'(?m)^\s*(?:const|var)\s+(\w+)\b')
PRELOAD=re.compile(r'\bconst\s+(\w+)\s*(?::\s*\w+\s*)?:?=\s*preload\("res://[^"\n]+\.gd"\)')
def static_issues(path):
 source=path.read_text();issues=[]
 for name in DECL.findall(source):
  if name in BUILTINS:issues.append('builtin_member:'+name)
 for name in PRELOAD.findall(source):
  for method in ['get_base_script','can_instantiate','resource_path']:
   if re.search(r'\b'+re.escape(name)+r'\s*\.\s*'+method+r'\b',source):issues.append('class_resource_reflection:'+name+'.'+method)
 return issues

def static_check():
 old=static_issues(P/'finite_gate.gd')
 assert 'builtin_member:Projection' in old and 'class_resource_reflection:Production.get_base_script' in old,old
 files=json.loads(re.search(r'const FILES := (\[[^\n]+\])',(D/'parse_gate.gd').read_text()).group(1))
 issues={path:static_issues(R/relative(path)) for path in files}
 issues['res://'+str((D/'parse_gate.gd').relative_to(R))]=static_issues(D/'parse_gate.gd')
 assert not any(issues.values()),issues
 safe=(D/'finite_gate.gd').read_text()
 assert 'var production_script: Script = load("res://scripts/integration/yanguizhou_first_floor.gd")' in safe
 assert 'production_script.get_base_script().resource_path' in safe
 return {'original_bad_copy_rejected':old,'active_scripts_checked':len(issues),'active_issues':{k:v for k,v in issues.items() if v}}

def collect():
 assert sha(P/'source_binding.json')==PARENT_SHA
 parent,mapped,aliases=original();mapped=mapped.copy()
 mapped['res://'+str((P/'source_binding.json').relative_to(R))]=PARENT_SHA
 for path in D.iterdir():
  if path.is_file() and path.suffix in ['.gd','.py','.md']:mapped['res://'+str(path.relative_to(R))]=sha(path)
 b=json.loads((D/'source_binding.json').read_text())
 assert b['runtime_map']==dict(sorted(mapped.items())) and b['source_aliases']==aliases and b['ancestor_pin_replacements']==parent['ancestor_pin_replacements']
 assert b['runtime_source_binding_sha256']==PARENT_SHA and b['required_groups']==parent['required_groups']
 return b,mapped,aliases

def verify():
 b,mapped,aliases=collect();scan=static_check()
 for path,digest in mapped.items():assert sha(R/relative(aliases.get(str(relative(path)),str(relative(path)))))==digest,path
 for p in D.glob('*.py'):ast.parse(p.read_text())
 old=(P/'finite_gate.gd').read_text();new=(D/'finite_gate.gd').read_text()
 assert old.count('check(')==new.count('check(') and old.count('near(')==new.count('near(')
 return {'schema':'p2-ordinary-test-parse-fix01-source','passed':True,'source_binding_sha256':sha(D/'source_binding.json'),'runtime_source_binding_sha256':PARENT_SHA,'closure_files':len(mapped),'static_gd_preflight':scan,'production_source_changed':False,'old_runtime_source_changed':False,'godot_parse':'NOT_RUN','finite_runtime':'NOT_RUN'}

def freeze():
 assert not (D/'source_binding.json').exists()
 assert sha(P/'source_binding.json')==PARENT_SHA
 parent,mapped,aliases=original();mapped=mapped.copy()
 mapped['res://'+str((P/'source_binding.json').relative_to(R))]=PARENT_SHA
 for p in D.iterdir():
  if p.is_file() and p.suffix in ['.gd','.py','.md']:mapped['res://'+str(p.relative_to(R))]=sha(p)
 b={'schema':'p2-ordinary-test-parse-fix01','status':'SOURCE_ONLY_NOT_RUN','runtime_source_binding_sha256':PARENT_SHA,'runtime_map':dict(sorted(mapped.items())),'source_aliases':aliases,'ancestor_pin_replacements':parent['ancestor_pin_replacements'],'required_groups':parent['required_groups'],'repair_sha256':{name:{'before_path':'res://'+str((P/name).relative_to(R)),'before':sha(P/name),'after_path':'res://'+str((D/name).relative_to(R)),'after':sha(D/name),'stage_update':'add distinct successor; old source bytes unchanged'} for name in ['finite_gate.gd','parse_gate.gd']}}
 (D/'source_binding.json').write_text(encode(b))
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--freeze',action='store_true');a=p.parse_args()
 if a.freeze:freeze()
 print(encode(verify()),end='')
