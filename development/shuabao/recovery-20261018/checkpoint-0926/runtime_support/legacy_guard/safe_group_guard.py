"""Loot-only process-group guard. No engine command or budget is built in.

Keep the Popen leader unreaped (waitid/WNOWAIT) until group termination, so
signals never use a recycled, merely remembered PID. Process-local subreaper
handles orphaned descendants. All real engine use awaits coordinator approval.
"""
from pathlib import Path
import ctypes
import json
import os
import re
import signal
import subprocess
import time
from memory_budget_v2 import budget


class GuardError(RuntimeError):
    pass


def read_stat(pid):
    text = Path(f'/proc/{pid}/stat').read_text(errors='surrogateescape')
    end = text.rfind(')')
    fields = text[end + 2:].split()
    if end < 0 or len(fields) < 20:
        raise GuardError(f'malformed_stat:{pid}')
    row = {'pid': int(text.split(' ', 1)[0]), 'state': fields[0],
           'ppid': int(fields[1]), 'pgid': int(fields[2]),
           'sid': int(fields[3]), 'start_ticks': int(fields[19])}
    if row['pid'] != pid or row['start_ticks'] < 0:
        raise GuardError(f'invalid_stat_identity:{pid}')
    return row


def parse_rss(text, pid):
    lines = [line for line in text.splitlines() if line.startswith('VmRSS:')]
    if len(lines) != 1 or not re.fullmatch(r'VmRSS:\s+\d+\s+kB\s*', lines[0]):
        raise GuardError(f"missing_or_invalid_live_RSS:{pid}")
    return int(lines[0].split()[1]) * 1024


def read_rss(row):
    # A kernel-confirmed zombie has no resident address space; it is not a
    # missing RSS sample from a live process.
    if row['state'] == 'Z':
        return 0
    text = Path(f"/proc/{row['pid']}/status").read_text()
    return parse_rss(text, row['pid'])


def system_sample():
    base = Path('/sys/fs/cgroup')
    raw = {name: (base / name).read_text().strip() for name in
           ('memory.max', 'memory.current', 'memory.stat', 'memory.events')}
    stat = {key: int(value) for key, value in
            (line.split() for line in raw['memory.stat'].splitlines())}
    events = {key: int(value) for key, value in
              (line.split() for line in raw['memory.events'].splitlines())}
    oom = {key: events[key] for key in ('oom', 'oom_kill', 'oom_group_kill')}
    if any(value < 0 for value in oom.values()):
        raise GuardError('negative_OOM_counter')
    return {'raw_fields': raw, 'budget': budget(raw['memory.max'], raw['memory.current'], stat), 'oom': oom}


class LocalSubreaper:
    def __enter__(self):
        self.restored = False
        self.libc = ctypes.CDLL(None, use_errno=True)
        old = ctypes.c_int()
        if self.libc.prctl(37, ctypes.byref(old), ctypes.c_ulong(0), ctypes.c_ulong(0), ctypes.c_ulong(0)) != 0:
            raise OSError(ctypes.get_errno(), 'PR_GET_CHILD_SUBREAPER')
        self.old = old.value
        if self.libc.prctl(36, ctypes.c_ulong(1), ctypes.c_ulong(0), ctypes.c_ulong(0), ctypes.c_ulong(0)) != 0:
            raise OSError(ctypes.get_errno(), 'PR_SET_CHILD_SUBREAPER')
        return self

    def __exit__(self, *_):
        if self.libc.prctl(36, ctypes.c_ulong(self.old), ctypes.c_ulong(0), ctypes.c_ulong(0), ctypes.c_ulong(0)) != 0:
            raise OSError(ctypes.get_errno(), 'restore_local_subreaper')
        self.restored = True


class OwnedGroup:
    def __init__(self, namespace):
        self.process = None
        self.pgid = None
        self.namespace = namespace
        self.reaped = False
        self.start_ticks = None
        self.signals = []
        self.adopted_reaped = []
    def attach(self, process):
        # Store the Popen handle before any fallible /proc inspection.
        self.process = process
        self.pgid = process.pid
    def establish(self):
        self.start_ticks = read_stat(self.process.pid)['start_ticks']
        self.assert_owned()

    def assert_owned(self):
        if self.reaped or os.readlink('/proc/self/ns/pid') != self.namespace:
            raise GuardError('ownership_lost_or_namespace_changed')
        # This verifies it is STILL our unreaped child, without collecting it.
        os.waitid(os.P_PID, self.process.pid, os.WEXITED | os.WNOHANG | os.WNOWAIT)
        if os.getpgid(self.process.pid) != self.pgid or os.getsid(self.process.pid) != self.pgid:
            raise GuardError('owned_leader_group_or_session_changed')
        try:
            row = read_stat(self.process.pid)
        except Exception as error:
            # Kernel waitid/getpgid/getsid above still prove this exact held
            # child owns the newly created group. Missing proc data is red,
            # but must not prevent killing that known group during cleanup.
            return {'pid': self.process.pid, 'pgid': self.pgid, 'sid': self.pgid,
                    'kernel_unreaped_child_verified': True, 'proc_identity_error': repr(error)}
        if self.start_ticks is not None and row['start_ticks'] != self.start_ticks:
            raise GuardError('leader_identity_changed')
        return row

    def leader_exited(self):
        self.assert_owned()
        return os.waitid(os.P_PID, self.process.pid,
                         os.WEXITED | os.WNOHANG | os.WNOWAIT) is not None

    def members(self, rss_reader=read_rss):
        rows = []
        for row in self.identities():
            rss = rss_reader(row)
            if not isinstance(rss, int) or isinstance(rss, bool) or rss < 0:
                raise GuardError(f"invalid_RSS_sample:{row['pid']}")
            after = read_stat(row['pid'])
            if any(after[key] != row[key] for key in ('pid', 'pgid', 'sid', 'start_ticks')):
                raise GuardError('member_changed_during_sample')
            rows.append(dict(after, rss=rss))
        return rows

    def identities(self):
        self.assert_owned()
        rows = []
        for name in os.listdir('/proc'):
            if not name.isdigit():
                continue
            try:
                row = read_stat(int(name))
            except FileNotFoundError:
                continue  # Vanished before membership was known, no live row.
            if row['pgid'] != self.pgid:
                continue
            if row['sid'] != self.pgid or (self.start_ticks is not None and row['start_ticks'] < self.start_ticks):
                raise GuardError('unexpected_member_identity')
            rows.append(row)
        if not any(row['pid'] == self.process.pid for row in rows):
            raise GuardError('owned_leader_missing_from_group')
        return rows

    def send(self, value):
        identity = self.assert_owned()
        os.killpg(self.pgid, value)
        self.signals.append({'signal': signal.Signals(value).name,
                             'time_monotonic': time.monotonic(), 'leader': identity})

    def quiet(self, seconds):
        deadline = time.monotonic() + seconds
        consecutive = 0
        while True:
            rows = self.identities()
            consecutive = consecutive + 1 if all(row['state'] == 'Z' for row in rows) else 0
            if consecutive >= 2:
                return True
            if time.monotonic() >= deadline:
                return False
            time.sleep(.02)

    def cleanup(self):
        errors = []
        try:
            stopped = self.quiet(.04)
        except Exception as error:
            errors.append('cleanup_scan:' + repr(error)); stopped = False
        for value, grace in ((signal.SIGINT, .25), (signal.SIGTERM, .25), (signal.SIGKILL, 1.0)):
            if stopped:
                break
            try:
                self.send(value)
                stopped = self.quiet(grace)
            except Exception as error:
                errors.append('cleanup_signal_or_scan:' + repr(error))
        # No signal will be attempted after collecting the reserved leader.
        try:
            rows = self.identities()
            if any(row['state'] != 'Z' for row in rows):
                errors.append('UNREAPED_HOLD_live_group_after_KILL')
                return {'reaped': False, 'cleanup_group_empty': False, 'errors': errors, 'remaining': rows}
            for row in rows:
                if row['pid'] != self.process.pid:
                    try:
                        pid, status = os.waitpid(row['pid'], os.WNOHANG)
                        if pid:
                            self.adopted_reaped.append({'pid': pid, 'status': status, 'start_ticks': row['start_ticks']})
                    except ChildProcessError:
                        pass  # Never signal a PID merely because wait failed.
            self.process.wait(timeout=.5)
            self.reaped = True
            # Post-reap observation only. Unknown/reused groups are never killed.
            remaining = []
            for name in os.listdir('/proc'):
                if not name.isdigit(): continue
                try: row = read_stat(int(name))
                except FileNotFoundError: continue
                if row['pgid'] == self.pgid: remaining.append(row)
            if remaining: errors.append('HOLD_group_not_empty_after_reap')
            return {'reaped': True, 'cleanup_group_empty': not remaining, 'errors': errors, 'remaining': remaining}
        except Exception as error:
            errors.append('cleanup_final_scan:' + repr(error))
            # The group was already signalled through SIGKILL above. Even if
            # proc cannot prove emptiness, wait on our actual Popen child.
            try:
                self.process.wait(timeout=.5); self.reaped = True
            except Exception as wait_error:
                errors.append('UNREAPED_HOLD:' + repr(wait_error))
            return {'reaped': self.reaped, 'cleanup_group_empty': False, 'errors': errors}


def run_guarded(command, output, limits, *, environment=None, _fixture_system=None,
                _fixture_rss=None, _fixture_hook=None):
    """Fixture injections are private test seams; production uses real readers."""
    output = Path(output); output.mkdir(exist_ok=False, parents=True)
    sampler = _fixture_system or system_sample
    rss_reader = _fixture_rss or read_rss
    report = {'schema': 'loot-owned-group-guard-1', 'command': command, 'limits': limits,
              'namespace': os.readlink('/proc/self/ns/pid'), 'engine_started': False,
              'fixture_injections': bool(_fixture_system or _fixture_rss or _fixture_hook),
              'reason': '', 'peak_group_rss': 0, 'peak_leader_rss': 0,
              'cleanup': {'reaped': False, 'cleanup_group_empty': True, 'errors': []}}
    process = None; owned = None; reaper = None; started = time.monotonic()
    raw_offset = 0; raw_tail = b''; raw_errors = set()
    markers = (b'Traceback', b'AssertionError', b'SCRIPT ERROR', b'SHADER ERROR',
               b'ERROR:', b'Parse Error', b'Compile Error', b'resources still in use',
               b'ObjectDB instances leaked')
    def read_raw_chunk():
        nonlocal raw_offset, raw_tail
        path = output / 'raw.log'
        if not path.exists(): return False
        with path.open('rb') as stream:
            stream.seek(raw_offset); block = stream.read(65536)
        raw_offset += len(block)
        joined = raw_tail + block
        for marker in markers:
            if marker in joined: raw_errors.add(marker.decode())
        raw_tail = joined[-160:]
        return bool(block)
    try:
        before = sampler(); report['before'] = before
        if before['budget']['raw'] <= limits['start_raw'] or before['budget']['effective'] <= limits['start_effective']:
            raise GuardError('admission_refused')
        if limits['wall_seconds'] <= 2.6:
            raise GuardError('wall_budget_must_include_cleanup_reserve')
        with LocalSubreaper() as reaper, (output / 'raw.log').open('w') as log, (output / 'samples.jsonl').open('w') as samples:
            try:
                owned = OwnedGroup(report['namespace'])
                process = subprocess.Popen(command, stdin=subprocess.DEVNULL, stdout=log,
                                           stderr=subprocess.STDOUT, start_new_session=True,
                                           env=environment)
                report['engine_started'] = True; report['pid'] = process.pid
                owned.attach(process)
                owned.establish()
                report['leader_start_ticks'] = owned.start_ticks; report['pgid'] = owned.pgid
                while True:
                    members = owned.members(rss_reader)
                    memory = sampler()
                    aggregate = sum(row['rss'] for row in members)
                    leader_rss = next(row['rss'] for row in members if row['pid'] == process.pid)
                    report['peak_group_rss'] = max(report['peak_group_rss'], aggregate)
                    report['peak_leader_rss'] = max(report['peak_leader_rss'], leader_rss)
                    samples.write(json.dumps({'seconds': time.monotonic()-started, 'members': members,
                                              'group_rss': aggregate, 'memory': memory})+'\n'); samples.flush()
                    if _fixture_hook: _fixture_hook(members)
                    read_raw_chunk()
                    if raw_errors: raise GuardError('raw_error:' + ','.join(sorted(raw_errors)))
                    if any(memory['oom'][key] > before['oom'][key] for key in before['oom']):
                        raise GuardError('OOM_delta')
                    if memory['budget']['raw'] < limits['runtime_raw']: raise GuardError('runtime_raw')
                    if memory['budget']['effective'] < limits['runtime_effective']: raise GuardError('runtime_effective')
                    if aggregate > limits['own_rss']: raise GuardError('aggregate_RSS')
                    if time.monotonic()-started >= limits['wall_seconds']-2.5:
                        raise GuardError('wall_cleanup_reserve')
                    if owned.leader_exited():
                        if any(row['pid'] != process.pid and row['state'] != 'Z' for row in owned.identities()):
                            raise GuardError('leader_exited_with_live_group')
                        break
                    time.sleep(.05)
            except BaseException as error:
                report['reason'] = type(error).__name__ + ':' + str(error)
            finally:
                if owned is not None and owned.process is not None:
                    report['cleanup'] = owned.cleanup()
                    report['signals'] = owned.signals
                    report['adopted_reaped'] = owned.adopted_reaped
                elif process is not None:
                    # Startup identity failures are never reported as clean.
                    report['reason'] += '|HOLD_no_owned_group_identity'
                    report['cleanup'] = {'reaped': False, 'cleanup_group_empty': False, 'errors': ['ownership_initialization_failed']}
                if process is not None: report['exit'] = process.returncode
    except BaseException as error:
        report['reason'] = report['reason'] or type(error).__name__ + ':' + str(error)
    try: report['after'] = sampler()
    except BaseException as error: report['after_error'] = repr(error); report['reason'] += '|after_sample_failed'
    while read_raw_chunk(): pass
    report['raw_errors'] = sorted(raw_errors)
    if raw_errors: report['reason'] = report['reason'] or 'raw_error_after_exit'
    report['elapsed'] = time.monotonic()-started
    report['local_subreaper_restored'] = reaper.restored if reaper is not None else None
    report['passed'] = (not report['reason'] and report.get('exit') == 0 and
                        report['cleanup']['reaped'] and report['cleanup']['cleanup_group_empty'] and
                        not report['cleanup']['errors'])
    (output / 'exit.json').write_text(json.dumps(report, indent=2))
    return report
