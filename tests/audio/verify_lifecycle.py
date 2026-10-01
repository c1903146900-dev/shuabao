"""Exit codes alone cannot establish leak-free shutdown. Inspect unfiltered logs."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'tests/audio/evidence/lifecycle'
def result(log,prefix):
    return json.loads(next(line[len(prefix):] for line in log.splitlines() if line.startswith(prefix)))

def main():
    logs={n:(OUT/(n+'.log')).read_text() for n in ['native-immediate','native-drained','cycles']}
    assert 'resources still in use' in logs['native-immediate'], 'Native immediate-exit control did not reproduce'
    runtime=(OUT.parent/'runtime.log').read_text()
    for name,log in [('runtime',runtime)]+[(n,logs[n]) for n in ['native-drained','cycles']]:
        assert not any(x in log for x in ['SCRIPT ERROR','ERROR:', 'instances leaked', 'resources still in use']),name
    behavior=result(runtime,'AUDIO_TEST_RESULT ');assert behavior['passed'] and behavior['checks']==142
    drain=result(runtime,'AUDIO_DRAIN_RESULT ');assert drain['passed'] and drain['remaining']==0
    native=result(logs['native-drained'],'NATIVE_DRAINED ');assert not any(native.values())
    cycles=result(logs['cycles'],'AUDIO_LIFECYCLE_RESULT ')
    assert cycles['passed'] and cycles['component_cycles']==220 and cycles['scene_round_trips']==20
    assert cycles['max_active']==8 and cycles['samples'][0]['rss_kb']>0
    summary={'behavior':behavior,'shutdown_drain':drain,'native_drained':native,'lifecycle':cycles}
    (OUT/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    print('LIFECYCLE_VERIFIED',json.dumps({'cycles':220,'scene_round_trips':20,'static_delta':cycles['static_delta'],'rss_delta_kb':cycles['rss_delta_kb'],'remaining':0}))
if __name__=='__main__':main()
