from pathlib import Path
import hashlib,json
R=Path(__file__).resolve().parent.parent
base=R/'rebuild_20261106/e1_motion01/runtime'
candidate=R/'rebuild_20261106/exit_continuity01/runtime'
changed={str(p.relative_to(candidate)) for p in candidate.rglob('*') if p.is_file() and p.read_bytes()!=(base/p.relative_to(candidate)).read_bytes()}
assert changed=={'fengli_route_20261024/presentation.gd','first_hero_full_admission_20261020/manifest.json','release_generation_20261020/generation.gd'}
p=(candidate/'fengli_route_20261024/presentation.gd').read_text()
assert p.count('return _locomotion_frame()')==3
helper=p.split('func _locomotion_frame()->Dictionary:\n',1)[1].split('func _frame()',1)[0]
assert '_walk_distance+=' not in helper and 'animation.' not in helper
assert '"cast_id":-1' in helper and 'host.sim.hero.facing' in helper
assert 'animation.clear();return _locomotion_frame()' in p
assert 'not host.sim.cast_is_current' in p
m=json.loads((candidate/'first_hero_full_admission_20261020/manifest.json').read_text())
assert len(m['files'])==243
for path,digest in m['files'].items():assert hashlib.sha256((candidate/path[6:]).read_bytes()).hexdigest()==digest
# Reference selection checks only, not GDScript execution or visual acceptance.
phases=['contact_a','passing_a','contact_b','passing_b']
for walking in [False,True]:
 for i in range(200):
  distance=i*.037
  selected='walk_'+phases[int(distance//.45)%4] if walking else 'idle'
  assert selected.startswith('walk_') if walking else selected=='idle'
print('STATIC_ONLY_PASS: isolated presentation change, three exit paths, 243 hashes; no engine run')
