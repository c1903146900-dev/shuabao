# Boat room-transition fixture correction 05

Status: NOT_RUN. Replaces snapshot04 boat_probe.gd only. Gameplay files unchanged.

The previous fixture called begin_encounter during combat without checking its
return. The real API rejects that phase, so the original boat continued normally.
The correction asserts this rejection and original scope preservation as a
negative case, then calls the real end_encounter API before beginning the next
room. It asserts cleanup, successful admission and room/generation change before
checking that old work emits no terminal, P1 payment or delayed endpoint burst.
No direct phase assignment or alternate Sim is used. The 17 groups are retained.

The prior native run failed 3 of 279 checks, with all 17 groups reached and no
engine ERROR. It remains failed. Its report was 186944 bytes, also above the
64 KiB output limit; future execution should allow a complete 256 KiB report.
That reporting limit is separate from the mechanism assertions.
