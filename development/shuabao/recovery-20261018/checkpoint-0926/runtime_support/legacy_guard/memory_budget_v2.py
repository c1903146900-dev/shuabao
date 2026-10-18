"""Root-reviewed cgroup accounting correction; no admission thresholds here."""
REQUIRED = ('file', 'shmem', 'inactive_file', 'file_dirty', 'file_writeback', 'file_mapped', 'slab_reclaimable')

def budget(maximum, current, stats):
    values = {key: int(stats[key]) for key in REQUIRED}
    if any(value < 0 for value in values.values()):
        raise ValueError('negative cgroup memory.stat field')
    raw = int(maximum) - int(current)
    file_backed = max(0, values['file'] - values['shmem'])
    eligible = max(0, min(values['inactive_file'], file_backed)
                   - values['file_dirty'] - values['file_writeback'] - values['file_mapped'])
    return {'raw': raw, 'eligible': eligible,
            'effective': raw + .5 * eligible + min(.25 * values['slab_reclaimable'], 128 * 1024 * 1024)}

def self_check():
    baseline = dict(file=150, shmem=50, inactive_file=100, file_dirty=5,
                    file_writeback=5, file_mapped=10, slab_reclaimable=0)
    assert budget(1000, 900, baseline) == {'raw':100, 'eligible':80, 'effective':140.0}
    assert budget(1000, 900, dict(baseline, file=80))['eligible'] == 10
    assert budget(1000, 900, dict(baseline, file=30))['eligible'] == 0
    assert budget(1000, 900, dict(baseline, inactive_file=10))['eligible'] == 0
    assert budget(1000, 900, dict(baseline, active_file=10**12)) == budget(1000, 900, baseline)
    assert budget(1000, 900, dict(baseline, slab_reclaimable=1024**3))['effective'] == 140 + 128 * 1024 * 1024
    missing = dict(baseline); missing.pop('file')
    try: budget(1000, 900, missing)
    except KeyError: pass
    else: raise AssertionError('missing file must fail closed')
    try: budget(1000, 900, dict(baseline, inactive_file=-1))
    except ValueError: pass
    else: raise AssertionError('negative stats must fail closed')
    return {'passed': True, 'checks': 8, 'active_file_credit': 0,
            'thresholds_changed': False, 'runtime_guard_changed': False}

if __name__ == '__main__':
    import json
    print(json.dumps(self_check()))
