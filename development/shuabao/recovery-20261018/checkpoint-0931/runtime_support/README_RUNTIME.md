# Owned runtime guard candidate, recovery B

This is a new wrapper implementation after the previous runtime wrapper was lost. It is not a byte restoration of that wrapper, and previous native passes do not apply to it.

Nine runtime dependency scripts are byte-identical to the recovered legacy source package. CODE_PINS.json lists only the scripts actually imported. Historical README files, old test results and previous machine paths are not execution dependencies. LEGACY_PINS.json and RECOVERY_INVENTORY.json record provenance separately.

Run the wrapper using Python 3 with -I -B, after independently checking its delivery seal and CODE_PINS.json. It validates the dependency bytes before importing them. The wrapper currently supports only functional normal-window execution. Official editor import is not supported by this candidate. Required arguments select an exact binary SHA, a project directory, exact pre/post file pins and a fresh output directory outside the project. Before the user-argument separator, only --script res://...gd and --resolution WIDTHxHEIGHT are accepted. The guard never uses headless mode.

## Resource and ownership contract

- Exclusive single_engine.lock; dedicated one-thread controller with no preexisting children; refuse existing Godot processes.
- Reuse legacy process-local subreaper, Linux PID start identities, kernel direct-child proof, retained pidfds and exact owned lineage. No arbitrary process/group killing. A foreign engine triggers cleanup of this guard's owned tree only.
- Sample controller plus owned descendants' RSS and swap at a nominal 50 ms interval; reject an observed gap over 200 ms or total above 1536 MiB. Require system MemAvailable at least 2 GiB before launching and throughout sampling. Missing live memory fields or identity changes fail closed.
- Launch-relative wall clock: request cleanup at 595 seconds and SIGKILL no later than the observed 600-second boundary. A nonthrowing launch alarm also covers Popen before it returns, pins actual direct children and retains owned pidfds on inventory errors.
- Cleanup sends TERM then KILL after 0.3 seconds, waits for two quiet scans, reaps owned children and proves direct-child/original-group inventory empty. Failure to prove exit stays OWNERSHIP_HOLD while retaining lock, subreaper and descriptors. Failure to write HOLD because the disk is full does not release ownership.
- These are sampled user-space controls, not cgroup limits or an OS hard guarantee. An uninterruptible kernel task, stalled interpreter or unavailable process evidence can exceed the deadline and remain HOLD. A kill request is never reported as proven termination.

An exit.json passed value means guard/resource/pin/exit checks passed, not that the game, fixture assertions or artwork passed. Raw engine output and fixture FINAL/report must be reviewed separately. The candidate has 23 pure tests, including fake launch timeout and fake cleanup failures. No actual child process or engine has been started by these tests. Real owned-cleanup and normal-window engine validation remain pending.
