"""Verify actual tools/call payloads, not merely process exit/isError flags."""
import argparse
import json
from pathlib import Path

def payload(path):
    data=json.loads(path.read_text())
    assert not data.get('isError') and not data.get('application_error'),path
    text=next(c['text'] for c in data['content'] if c['type']=='text')
    value=json.loads(text)
    if isinstance(value,str) and value.lstrip().startswith('{'):
        # Upstream runtime stringifies Godot Variants; StringName uses &"...".
        value=json.loads(value.replace('&"','"'))
    if isinstance(value,dict) and set(value)=={'result'}:value=value['result']
    return value

def verify(folder):
    def step(n):return payload(next(folder.glob(f'step-{n:02}-*.json')))
    inventory=step(1)
    assert inventory['imported']==15
    assert all(x['format']==1 and x['rate']==32000 and not x['stereo'] and x['loop_mode']==0 and .1<x['length']<1 for x in inventory['files'])
    for i in range(4,17):
        row=step(i);assert row['passed'] and row['accepted'] and row['state']['active']==1
        assert row['state']['voices'][0]['playing']
    assert step(17)=={'same_tick_100_accepted':1,'global_active':8,'ninth_rejected':True,'passed':True}
    assert step(18)['passed']
    advance=step(19);assert advance['active']==1 and advance['voices'][0]['position']>.1
    assert step(20)['active']==0
    native=step(22);assert native['passed'] and native['key']==69 and native['state']['voices'][0]['id']=='e_overload'
    report=step(23);assert report['passed'] and report['checks']==16 and all(r['passed'] for r in report['results'])
    lifecycle_path = folder/'step-26-execute_game_script.json'
    if lifecycle_path.exists():
        lifecycle = payload(lifecycle_path)
        assert lifecycle['done'] and lifecycle['passed'] and not lifecycle['failures']
        assert lifecycle['component_cycles']==220 and lifecycle['scene_round_trips']==20 and lifecycle['max_active']==8
        (folder/'lifecycle-summary.json').write_text(json.dumps(lifecycle,indent=2)+'\n')
    log=(folder/'godot-editor.log').read_text()
    assert 'SCRIPT ERROR' not in log and 'Parse Error' not in log
    if lifecycle_path.exists():
        assert 'instances leaked' not in log and 'resources still in use' not in log
    summary={'passed':True,'imported_files':15,'runtime_groups':16,'clock_advanced_to':advance['voices'][0]['position'],
        'driver':report['driver'],'listening_test':False,'script_errors':0}
    (folder/'verified-summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    print(json.dumps(summary))

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('folder',type=Path);args=parser.parse_args();verify(args.folder)
