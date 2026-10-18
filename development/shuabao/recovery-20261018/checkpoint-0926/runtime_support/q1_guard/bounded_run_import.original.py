#!/usr/bin/env python3
"""Linux sampled-RSS import supervisor. No cgroup/OOM hard guarantee."""
import argparse
import fcntl
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time
import traceback

SOURCE = Path(__file__).resolve().parents[1] / 'loot_recovery_20261007/restored/six-hero-current-wip/tools/loot_resource_guard_20261006'
sys.path.insert(0, str(SOURCE))
from safe_tree_guard import (GuardError, LocalSubreaper, DeferredCancellation,
                             children, read_stat, proc_inventory, exited, pidfd_pid)
from safe_tree_guard_rss_reread01 import read_rss
from held_exit_adapter import OwnedTree
from proc_exit_adapter import install, inventory_read, EVIDENCE, confirmed_absent
install()
from safe_tree_guard import proc_inventory

MIB = 1024**2
INTERVAL = .050
class Deadline(BaseException):
    pass

def engines():
    found = []
    for pid in proc_inventory():
        try:
            name = inventory_read(lambda candidate: Path(f'/proc/{candidate}/comm').read_text().strip().lower(), pid)
        except FileNotFoundError:
            continue
        if 'godot' in name:
            found.append(pid)
    return found

def external_engines(tree):
    """Only distinct unowned launches conflict; inherited child comm is harmless.

    All proven-owned children remain under the normal RSS/session/cleanup guard.
    A fresh scan handles a fork between the preceding RSS sample and enumeration.
    """
    candidates = engines()
    def owned_or_gone(pid):
        try:
            row = inventory_read(read_stat, pid)
        except FileNotFoundError:
            return confirmed_absent(pid)
        records = [r for r in tree.records if r['pid']==pid and r['start_ticks']==row['start_ticks'] and not r.get('reaped')]
        return len(records)==1 and pidfd_pid(records[0]['fd'])==pid
    pending = [pid for pid in candidates if not owned_or_gone(pid)]
    if pending:
        tree.scan()
    return [pid for pid in pending if not owned_or_gone(pid)]

def cleanup(tree, output):
    """Keep ownership and lock held until terminal proof; TERM then KILL."""
    start = time.monotonic()
    quiet = 0
    errors = []
    while True:
        elapsed = time.monotonic() - start
        try:
            scan = tree.scan()
            live = any(r['state'] not in ('Z', 'X') for r in scan['rows'])
            live = live or any(not exited(r['fd']) for r in tree.records)
            quiet = quiet + 1 if not live else 0
            if quiet >= 2:
                return dict(tree.reap(), errors=errors[-20:], seconds=elapsed)
            if live:
                tree.signal_owned(signal.SIGTERM if elapsed < .3 else signal.SIGKILL)
        except BaseException as error:
            quiet = 0
            errors.append(repr(error))
            errors = errors[-128:]
            try:
                tree.signal_owned(signal.SIGTERM if elapsed < .3 else signal.SIGKILL)
            except BaseException as nested:
                errors.append(repr(nested))
        if elapsed > 1.5:
            try:
                (output/'HOLD.json').write_text(json.dumps({'status':'OWNERSHIP_HOLD', 'seconds':elapsed, 'errors':errors[-20:], 'no_new_engine':True}))
            except OSError:
                pass
        time.sleep(.025 if elapsed < 1.5 else .25)

PROFILES = {'import': 60., 'gui': 110., 'gui180': 180., 'gui900': 900., 'gui2400': 2400., 'pair': 110., 'pair300': 300., 'pair600': 600.}

def profile_limits(profile='import', seconds=None, rss_mib=896):
    if profile not in PROFILES:
        raise ValueError('unknown profile')
    seconds = PROFILES[profile] if seconds is None else seconds
    if not (0.6 <= seconds <= PROFILES[profile] and 1 <= rss_mib <= 896):
        raise ValueError('test limits must only tighten the selected profile')
    return seconds, rss_mib

def run(command, output, seconds=None, rss_mib=896, profile='import'):
    seconds, rss_mib = profile_limits(profile, seconds, rss_mib)
    pair_policy = None
    if profile in ('pair', 'pair300', 'pair600'):
        from pair_profile import PairPolicy
        pair_policy = PairPolicy(command)
    output = Path(output)
    output.mkdir(parents=True, exist_ok=False)
    report = {'command':command, 'profile':{'name':profile, 'rss_limit_bytes':rss_mib*MIB, 'wall_seconds':seconds,
              'sample_interval_seconds':INTERVAL, 'scope':'controller plus owned descendants',
              'memory_enforcement':'sampled RSS, not a kernel hard limit', 'cgroup_or_OOM_guarantee':False},
              'started':False, 'reason':'', 'peak_total_rss':0, 'max_sample_gap':0}
    if pair_policy is not None:
        from pair_exit_adapter import PairOwnedTree
        tree = PairOwnedTree(os.readlink('/proc/self/ns/pid'), pair_policy)
    else:
        tree = OwnedTree(os.readlink('/proc/self/ns/pid'))
    start = time.monotonic()
    old_alarm = signal.getsignal(signal.SIGALRM)
    def deadline(_number, _frame):
        raise Deadline('wall_deadline_cleanup_reserve')
    reaper = None
    try:
        with (Path(__file__).parent/'single_engine.lock').open('a') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            if children() or len(list(Path('/proc/self/task').iterdir())) != 1:
                raise GuardError('controller_not_dedicated_single_thread')
            if engines():
                raise GuardError('existing_godot_process')
            with DeferredCancellation() as cancellation, LocalSubreaper() as reaper, (output/'raw.log').open('w') as log, (output/'samples.jsonl').open('w') as samples:
                try:
                    process = subprocess.Popen(command, stdin=subprocess.DEVNULL, stdout=log,
                                               stderr=subprocess.STDOUT, start_new_session=True)
                    tree.attach(process)
                    report.update(started=True, pid=process.pid)
                    signal.signal(signal.SIGALRM, deadline)
                    # Reserve 0.5s inside the selected engine deadline for TERM/KILL.
                    signal.setitimer(signal.ITIMER_REAL, max(.001, seconds-.5-(time.monotonic()-start)))
                    tree.establish()
                    last_sample = time.monotonic()
                    while True:
                        tick = time.monotonic()
                        scan, rows = tree.sample(read_rss)
                        controller = read_rss(read_stat(os.getpid()))
                        total = controller + sum(r['rss'] for r in rows)
                        now = time.monotonic()
                        gap = now-last_sample
                        last_sample = now
                        report['max_sample_gap'] = max(report['max_sample_gap'], gap)
                        report['peak_total_rss'] = max(report['peak_total_rss'], total)
                        samples.write(json.dumps({'at':now, 'total_rss':total, 'controller_rss':controller,
                                                  'members':rows, 'sample_gap':gap})+'\n')
                        samples.flush()
                        if total > rss_mib*MIB:
                            raise GuardError('total_RSS_limit')
                        if gap > .2:
                            raise GuardError('sample_gap_over_200ms')
                        foreign = external_engines(tree)
                        if foreign:
                            report['external_godot_pids'] = foreign
                            raise GuardError('independent_unowned_godot_process_observed')
                        if pair_policy is not None:
                            pair_policy.observe(tree)
                            pair_policy.allowed_escaped.update(tree.verified_terminal_helper_escapes(scan['escaped']))
                        unapproved_escaped = [r for r in scan['escaped'] if pair_policy is None or (r['pid'],r['start_ticks']) not in pair_policy.allowed_escaped]
                        if unapproved_escaped:
                            raise GuardError('owned_process_escaped_session')
                        if cancellation.requests:
                            raise GuardError('controller_cancel_requested')
                        if tree.leader_done():
                            if any(r['pid']!=process.pid and r['state'] not in ('Z','X') for r in rows):
                                raise GuardError('leader_exited_with_live_descendant')
                            break
                        time.sleep(max(0, INTERVAL-(time.monotonic()-tick)))
                except BaseException as error:
                    report['reason'] = type(error).__name__+':'+str(error)
                    report['traceback'] = traceback.format_exc()
                finally:
                    signal.setitimer(signal.ITIMER_REAL, 0)
                    if tree.process is not None:
                        report['cleanup'] = cleanup(tree, output)
                        report['exit'] = tree.process.returncode
                        report['signals'] = list(tree.signals)
                    report['cancellation_requests'] = list(cancellation.requests)
    except BaseException as error:
        report['reason'] = report['reason'] or type(error).__name__+':'+str(error)
    finally:
        signal.setitimer(signal.ITIMER_REAL, 0)
        signal.signal(signal.SIGALRM, old_alarm)
        report['elapsed_seconds'] = time.monotonic()-start
        report['local_subreaper_restored'] = reaper.restored if reaper is not None else None
        report['passed'] = not report['reason'] and report.get('exit') == 0 and bool(report.get('cleanup',{}).get('direct_children_empty')) and not report.get('cleanup',{}).get('errors')
        report['rss_resolution_evidence'] = list(getattr(tree, 'rss_reread_evidence', []))
        report['inventory_evidence'] = list(getattr(tree, 'reaped_inventory_evidence', []))
        report['proc_exit_adapter_evidence'] = list(EVIDENCE)
        report['held_exit_evidence'] = list(getattr(tree, 'held_exit_evidence', []))
        report['pair_terminal_evidence'] = list(getattr(tree, 'pair_terminal_evidence', []))
        if pair_policy is not None:
            report['pair_policy'] = pair_policy.report()
        tree.close_fds()
        (output/'exit.json').write_text(json.dumps(report, indent=2))
    return report

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True)
    parser.add_argument('--profile', choices=sorted(PROFILES), default='import')
    parser.add_argument('--test-seconds', type=float, default=None)
    parser.add_argument('--test-rss-mib', type=int, default=896)
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    try:
        seconds, rss_mib = profile_limits(args.profile, args.test_seconds, args.test_rss_mib)
    except ValueError as error:
        parser.error(str(error))
    command = args.command[1:] if args.command[:1] == ['--'] else args.command
    if not command:
        parser.error('command required after --')
    result = run(command, args.output, seconds, rss_mib, args.profile)
    print(json.dumps(result, indent=2))
    raise SystemExit(0 if result['passed'] else 1)
