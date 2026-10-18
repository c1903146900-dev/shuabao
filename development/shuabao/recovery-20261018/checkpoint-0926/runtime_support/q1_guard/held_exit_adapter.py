"""Q1 narrow held terminal-row omission; no live RSS relaxation or peak claim."""
import errno, os, select
from safe_tree_guard import GuardError, BoundedHistory, read_stat, pidfd_pid
from safe_tree_guard_rss_exit01 import pidfd_events
from safe_tree_guard_rss_reread01 import OwnedTree as StrictTree, MissingVmRSS
import time

class OwnedTree(StrictTree):
    def terminal_omission(self, row, original):
        if os.readlink('/proc/self/ns/pid') != self.namespace:
            raise GuardError('terminal_namespace_changed')
        records = [r for r in self.records if r['pid'] == row['pid'] and
                   r['start_ticks'] == row['start_ticks'] and not r.get('reaped')]
        if len(records) != 1:
            raise GuardError('terminal_no_unique_held_identity')
        fd = records[0]['fd']
        for _ in range(2):
            kernel_pid = pidfd_pid(fd)
            if kernel_pid not in (row['pid'], -1):
                raise GuardError('terminal_pidfd_identity_changed')
            if not pidfd_events(fd) & select.POLLIN:
                raise GuardError('terminal_pidfd_not_readable')
            try:
                current = read_stat(row['pid'])
            except FileNotFoundError as error:
                if error.errno != errno.ENOENT:
                    raise
                state = 'absent'
            else:
                if current['pid'] != row['pid'] or current['start_ticks'] != row['start_ticks']:
                    raise GuardError('terminal_PID_reused')
                if current['state'] not in ('Z', 'X'):
                    raise GuardError('terminal_stat_still_live')
                state = current['state']
        if not hasattr(self, 'held_exit_evidence'):
            self.held_exit_evidence = BoundedHistory()
        self.held_exit_evidence.append({'pid':row['pid'], 'start_ticks':row['start_ticks'],
            'proof':'retained_unique_identity_POLLIN_twice_fresh_terminal_or_ENOENT',
            'final_state':state, 'kernel_pid':kernel_pid, 'original_error':str(original),
            'sample_row_omitted':True, 'RSS_zero_substituted':False,
            'historical_peak_unchanged':True, 'unobserved_child_peak_known':False,
            'cleanup_record_retained':True, 'reaped_by_probe':False})

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
                    if (isinstance(problem, GuardError) and str(problem) == 'RSS_reread_pidfd_identity_changed') or (isinstance(problem, FileNotFoundError) and problem.errno == errno.ENOENT):
                        self.terminal_omission(row, problem)
                        continue
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
                self.terminal_omission(row, error)
                continue
            if not isinstance(value, int) or isinstance(value, bool) or value < 0:
                raise GuardError('invalid_live_RSS_sample')
            try:
                current = read_stat(row['pid'])
            except FileNotFoundError as error:
                self.terminal_omission(row, error)
                continue
            if current['pid'] != row['pid'] or current['start_ticks'] != row['start_ticks']:
                raise GuardError('RSS_identity_changed')
            if deadline is not None and time.monotonic() >= deadline:
                raise GuardError('RSS_reread_10ms_timeout')
            item = dict(current, rss=value)
            if evidence is not None:
                item['rss_resolution_evidence'] = evidence
            output.append(item)
        return scan, output
