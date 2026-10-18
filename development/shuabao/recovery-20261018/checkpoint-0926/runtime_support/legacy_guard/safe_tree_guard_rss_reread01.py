"""Candidate: at most 10 ms shared per sample for genuinely absent VmRSS.

No missing-live-RSS zero, reaping, signals, relaxed limits or cleanup changes.
All I/O remains subject to the adapter's full observation-interval deadline.
"""
from pathlib import Path
import time, select
from safe_tree_guard_vanished_child01 import OwnedTree as PreviousTree
from safe_tree_guard import GuardError, BoundedHistory, read_stat, pidfd_pid
from safe_group_guard import parse_rss
from safe_tree_guard_rss_exit01 import pidfd_events

class MissingVmRSS(GuardError):
    pass

def read_rss(row):
    if row['state'] == 'Z':
        return 0
    text = Path(f"/proc/{row['pid']}/status").read_text()
    if not any(line.startswith('VmRSS:') for line in text.splitlines()):
        raise MissingVmRSS(f'missing_live_VmRSS:{row["pid"]}')
    # Malformed or duplicate VmRSS never enters the retry path.
    return parse_rss(text, row['pid'])

class OwnedTree(PreviousTree):
    def _same_held_identity(self, row):
        records = [r for r in self.records if r['pid'] == row['pid']
                   and r['start_ticks'] == row['start_ticks'] and not r.get('reaped')]
        if len(records) != 1:
            raise GuardError('RSS_reread_no_unique_held_identity')
        record = records[0]
        if pidfd_pid(record['fd']) != row['pid']:
            raise GuardError('RSS_reread_pidfd_identity_changed')
        current = read_stat(row['pid'])
        if current['pid'] != row['pid'] or current['start_ticks'] != row['start_ticks']:
            raise GuardError('RSS_reread_identity_changed')
        return current, record

    def _resolve_missing(self, row, rss_reader, deadline, evidence):
        for _ in range(128):
            if time.monotonic() >= deadline:
                raise GuardError('RSS_reread_10ms_timeout')
            current, record = self._same_held_identity(row)
            evidence['attempts'] += 1
            if current['state'] in ('Z', 'X'):
                value, proof = 0, 'same_identity_' + current['state']
            elif pidfd_events(record['fd']) & select.POLLIN:
                value, proof = 0, 'same_identity_owned_pidfd_readable'
            else:
                try:
                    value = rss_reader(current)
                except MissingVmRSS:
                    # No waiting/sleep and no absorption of permission, I/O,
                    # malformed-field or identity errors.
                    continue
                proof = 'same_identity_measured_VmRSS'
            after, _ = self._same_held_identity(row)
            if time.monotonic() >= deadline:
                raise GuardError('RSS_reread_10ms_timeout')
            evidence.update(resolved=True, proof=proof, final_state=after['state'])
            return after, value
        raise GuardError('RSS_reread_attempt_bound')

    def sample(self, rss_reader):
        scan = self.scan()
        output = []
        retry_started = None
        deadline = None
        if not hasattr(self, 'rss_reread_evidence'):
            self.rss_reread_evidence = BoundedHistory()
        for row in scan['rows']:
            evidence = None
            try:
                value = rss_reader(row)
            except MissingVmRSS as error:
                now = time.monotonic()
                if retry_started is None:
                    retry_started, deadline = now, now + .010
                evidence = {'pid': row['pid'], 'start_ticks': row['start_ticks'],
                            'original_error': str(error), 'attempts': 0,
                            'resolved': False, 'reaped_by_probe': False,
                            'sample_retry_started': retry_started, 'deadline': deadline}
                try:
                    current, value = self._resolve_missing(row, rss_reader, deadline, evidence)
                except BaseException as problem:
                    evidence['error'] = repr(problem)
                    raise
                finally:
                    evidence['finished'] = time.monotonic()
                    evidence['shared_elapsed'] = evidence['finished'] - retry_started
                    self.rss_reread_evidence.append(evidence)
            except (FileNotFoundError, GuardError) as error:
                # Preserve the old one-read ENOENT/exit proof path. Invalid
                # VmRSS must remain red rather than becoming an exit retry.
                if isinstance(error, GuardError):
                    raise
                current, evidence = self.missing_rss_exit_proof(row, error)
                value = 0
            if not isinstance(value, int) or isinstance(value, bool) or value < 0:
                raise GuardError('invalid_live_RSS_sample')
            current = read_stat(row['pid'])
            if current['pid'] != row['pid'] or current['start_ticks'] != row['start_ticks']:
                raise GuardError('RSS_identity_changed')
            if deadline is not None and time.monotonic() >= deadline:
                raise GuardError('RSS_reread_10ms_timeout')
            item = dict(current, rss=value)
            if evidence is not None:
                item['rss_resolution_evidence'] = evidence
            output.append(item)
        return scan, output
