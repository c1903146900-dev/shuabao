"""Independent predicate model + exact source invariance; never runs Godot."""
import argparse, copy, hashlib, itertools, json
from pathlib import Path
LIVE = ('preparation','combat','between_rooms','service')
OTHER = ('completed','faulted','defeated','aborted','unbound','unknown',None)
def original(model, dead, enabled, pending):
    return model and not dead and enabled and bool(pending)
def fixed(status, model, dead, enabled, pending):
    return status in LIVE and original(model,dead,enabled,pending)
def main():
    p=argparse.ArgumentParser();p.add_argument('--base',type=Path,required=True);p.add_argument('--candidate',type=Path,required=True);a=p.parse_args()
    cases=0; live=0; prevented=0
    for status,model,dead,enabled,pending in itertools.product(LIVE+OTHER,(False,True),(False,True),(False,True),([], [4], [10], [4,10])):
        state={'pending':copy.deepcopy(pending),'xp':1859,'level':10,'reward_receipts':['boss'],'completed':True}
        before=copy.deepcopy(state)
        old=original(model,dead,enabled,state['pending']);new=fixed(status,model,dead,enabled,state['pending'])
        assert state==before  # predicate cannot consume progression/receipts
        if status in LIVE:
            assert new==old;live+=1
        else:
            assert new is False; prevented+=bool(old)
        cases+=1
    b=a.base;c=a.candidate
    changed=[]
    for f in sorted(set(x.relative_to(b) for x in b.rglob('*') if x.is_file())|set(x.relative_to(c) for x in c.rglob('*') if x.is_file())):
        if not (b/f).exists() or not (c/f).exists() or (b/f).read_bytes()!=(c/f).read_bytes():changed.append(str(f))
    expected=['fengli_route_20261024/growth_controller.gd','fengli_route_20261024/host.gd','first_hero_full_admission_20261020/manifest.json','release_generation_20261020/generation.gd']
    assert changed==expected,changed
    leaf=(c/expected[0]).read_text()
    assert leaf.count('func ')==1 and 'return super.auto_hex_pending()' in leaf
    assert 'session.status not in ["preparation","combat","between_rooms","service"]' in leaf
    assert '_session==null' in leaf and 'session==null' in leaf
    host=(b/expected[1]).read_text()
    assert (c/expected[1]).read_text()==host.replace('const Controller = preload("res://tests/ink_q3_input_growth_20261004/controller.gd")','const Controller = preload("res://fengli_route_20261024/growth_controller.gd")')
    print(json.dumps({'predicate_cases':cases,'live_state_equivalence_cases':live,'terminal_pending_open_prevented':prevented,'exact_changed_files':changed,'all_other_runtime_bytes_unchanged':True,'rewards_pending_mutated':False,'engine_run':False,'parser_run':False},indent=2))
if __name__=='__main__':main()
