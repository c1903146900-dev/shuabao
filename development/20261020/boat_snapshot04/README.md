# Boat callback cleanup checkpoint 04

Status: NOT_RUN. Replaces checkpoint 03 e2_base.gd and boat_probe.gd only.
Retain all other checkpoint 01/02/03 payloads.

Retirement now detaches local work before emitting target-cleanup callbacks.
Natural expiry rechecks cast liveness after target cleanup, so a callback that
cancels the cast cannot trigger an obsolete endpoint burst. Tests add cancellation
inside taunt-start/end callbacks and pause inside a return-hit callback.
No gameplay values, P1 eligibility, Catalog or source bindings changed.
