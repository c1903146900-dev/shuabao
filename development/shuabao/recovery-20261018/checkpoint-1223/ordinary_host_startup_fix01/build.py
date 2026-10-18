from pathlib import Path
import hashlib, json, difflib
R = Path(__file__).resolve().parent
B = R.parent / 'base'
G = B / 'game'
sha = lambda b: hashlib.sha256(b).hexdigest()
manifest = json.loads((B / 'PUBLIC_SOURCE_MANIFEST.json').read_text())
pins = {v['path'].removeprefix('game/'): v for v in manifest['files']}
HOST = 'tests/ink_ordinary_visuals_20261007/candidate01/host.gd'
DONOR = 'visual_rework_20261009/runtime_host.gd'
ACTOR = 'visual_rework_20261009/runtime_actor.gd'
BRUSH = 'tests/ink_ultimate_brush_art_20261008/candidate01/hero_view.gd'
PARENT = 'tests/ink_ultimate_presentation_art_20261006/dual_v03/imported_gate01/consumer_candidate.gd'
CONVERSION = 'runtime_converted_assets/r2_conversion_binding.json'
inputs = {}
for path in [HOST, DONOR, ACTOR, BRUSH, PARENT, CONVERSION]:
 data = (G / path).read_bytes()
 assert len(data) == pins[path]['bytes'] and sha(data) == pins[path]['sha256'], path
 inputs[path] = sha(data)
base = (G / HOST).read_text()
donor = (G / DONOR).read_text()
def one_line(text, prefix):
 rows = [v for v in text.splitlines(True) if v.startswith(prefix)]
 assert len(rows) == 1, prefix
 return rows[0]
marker = '# Exact continuation of the unchanged root-return and Q2 constructor source seals.\n'
assert donor.count(marker) == 1 and 'func _return_binding_errors' not in base
tail = donor.split(marker, 1)[1]
assert tail.count('func ') == 1 and tail.startswith('func _return_binding_errors() -> Array[String]:\n')
tail = marker + tail
prefixes = ['const OrdinaryVisualActor = ', 'const VISUAL_ACTOR_PATH := ', 'const VISUAL_ACTOR_SHA := ', ' var exact_actor: bool = ']
added = ['const OriginalBrushActor=', 'const OriginalBrushSHA=']
result = base
for prefix in prefixes:
 result = result.replace(one_line(base, prefix), one_line(donor, prefix), 1)
anchor = one_line(donor, 'const VISUAL_ACTOR_PATH := ')
result = result.replace(anchor, anchor + ''.join(one_line(donor, p) for p in added), 1)
result += '\n' + tail
# Reverse only the admitted changes to prove the original Host survives exactly.
reverse = result[:-len('\n' + tail)]
for prefix in added: reverse = reverse.replace(one_line(donor, prefix), '', 1)
for prefix in prefixes: reverse = reverse.replace(one_line(donor, prefix), one_line(base, prefix), 1)
assert reverse == base
assert inputs[ACTOR] in one_line(result, 'const VISUAL_ACTOR_SHA := ')
assert inputs[BRUSH] in one_line(result, 'const OriginalBrushSHA=')
assert (G / ACTOR).read_text().startswith('extends "res://' + BRUSH + '"\n')
assert (G / BRUSH).read_text().startswith('extends "res://' + PARENT + '"\n')
conversion = json.loads((G / CONVERSION).read_text())
conversion_actual = {}
for path,h in conversion['files'].items():
 if (G/path).exists():
  actual=sha((G/path).read_bytes());assert actual==h==pins[path]['sha256'];conversion_actual[path]=actual
out = R / 'payload' / HOST
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(result)
assert out.read_bytes() == result.encode()
(R / 'SOURCE_DELTA.diff').write_text(''.join(difflib.unified_diff(base.splitlines(True),result.splitlines(True),fromfile='restored3031/'+HOST,tofile='candidate/'+HOST)))
report = {
 'classification': 'NEW_BYTE_VERIFIED_SELECTION_OF_EXISTING_STARTUP_SUCCESSORS',
 'status': 'STATIC_CANDIDATE_NATIVE_NOT_RUN',
 'target': HOST, 'before': inputs[HOST], 'after': sha(out.read_bytes()),
 'payload': 'payload/' + HOST, 'bytes': out.stat().st_size,
 'parent_manifest_sha256': sha((B/'PUBLIC_SOURCE_MANIFEST.json').read_bytes()),
 'inputs_verified': inputs, 'donor_tail_sha256': sha(tail.encode()),
 'exact_replaced_line_prefixes': prefixes, 'exact_added_line_prefixes': added,
 'original_host_reverse_diff_exact': True, 'source_files_changed': 1,
 'base_written': False, 'engine_started': False,
 'converted_binding_schema': conversion['schema'],
 'converted_five_files_actual_sha_verified': conversion_actual,
 'converted_files_still_missing': sorted(set(conversion['files'])-set(conversion_actual)),
 'p3_gate': 'Not produced here. P3 author must preserve original preimage/before and bind this exact new Host after in the unified migration.',
}
(R / 'MANIFEST.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,ensure_ascii=False))
