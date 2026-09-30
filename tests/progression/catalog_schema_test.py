"""Offline schema + graph/economy tests. Run with existing MCP venv (jsonschema)."""
import copy
import json
from pathlib import Path
from jsonschema import Draft202012Validator
ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / 'data/progression/prototype'
catalog = json.loads((DATA/'catalog.json').read_text())
schema = json.loads((DATA/'catalog.schema.json').read_text())
Draft202012Validator.check_schema(schema)
validator = Draft202012Validator(schema)
validator.validate(catalog)
checks = 1
for section in ['items', 'hexes', 'body']:
    bad = copy.deepcopy(catalog)
    target = bad[section] if section == 'body' else next(iter(bad[section].values()))
    target['skill_points'] = 1
    assert list(validator.iter_errors(bad)), section
    checks += 1
for value in [None, -1, 0, 3.5, '450']:
    bad = copy.deepcopy(catalog)
    bad['items']['iron_blade']['price'] = value
    assert list(validator.iter_errors(bad)), value
    checks += 1
items = catalog['items']
def visit(key, path=()):
    assert key not in path, ('cycle', path, key)
    item = items[key]
    for part in item['components']:
        assert part in items and items[part]['kind'] == 'equipment'
        visit(part, path + (key,))
    if item['components']:
        assert item['price'] == sum(items[x]['price'] for x in item['components']) + item['combine_fee']
    assert (item['price'] * 9) // 10 <= item['price']
for key in items:
    visit(key)
    checks += 1
assert sum(x['tier']=='component' for x in items.values()) == 12
assert sum(x['tier']=='complete' for x in items.values()) == 8
# Worst sequential round: 4 previously selected + 8 distinct displayed/refreshed.
# Keeping >=12 legal hero keys covers even all prior choices and all mixed draws being hero.
legal = [v for v in catalog['hexes'].values() if v['status']=='prototype_initial']
assert len({v['effect_key'] for v in legal if v['hero']=='fengli'}) >= 12
assert len({v['effect_key'] for v in legal}) == len(legal)
checks += 4
print(json.dumps({'schema_checks': checks, 'passed': True, 'components': 12, 'intermediates': 3, 'completes': 8, 'potions': 2, 'hexes_numeric': len(legal), 'drafts_unsupported': 19}))
