# Direct schema3 host regression

This test runner directly owns two sequential Godot processes. It creates a new
schema3 world, waits for server_ready and at least two physics steps, verifies the
original readiness/port assertions, requests normal stop, then checks exact saved
state. Only after normal exit/reap/group-empty and all assertions does a fresh
resource admission permit reopening the same world and checking original identity,
clock, restoration and sequence assertions. No game source or save format changes.

The observer core is unchanged. Each child has its own session/PGID; no Python
wrapper child, pipe ownership scheme, duplicate driver signal cleanup or heartbeat
lease remains. Normal ready timeout15s and requested-save stop timeout8s are
functional deadlines. Resource failures use the existing observer's <=0.1s TERM
and KILL, with at most6s post-KILL confirmation; raw/OOM emergencies directly KILL.
Both Godot phases share45s, total110s. Fresh startup/runtime admission retains the
original192MiB owned cap,900MiB effective reserve and192MiB raw floor. The fixed61
v3 admission policy does not apply. Final source229 pure mocks and independent
review passed. No new actual host lifecycle has run; previous historical evidence
is not rewritten. A dedicated desktop execution window is required.
