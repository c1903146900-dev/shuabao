# Confirmed inventory policies, 2026-10-08 07:14 UTC

User decisions now settled:
1. Q drops one item. Mouse-held stack can be dropped whole.
2. Right-click returns ceil(quantity/2) to original slot when all that half fits.
   If it does not fit, drop the entire requested half atomically; do not partially
   fill the original slot. Remainder stays in carry, original slot unchanged.
3. Same-layer compatible stackable ground items within one cell merge, preserving
   full stack/instance-state compatibility. Keep overflow on ground; unique item
   instances do not merge.
4. Carry persists in complete saves and is restored still held on reconnect.
   Crash/power loss guarantees remain limited to the last complete commit.

This first patch only removes the temporary carry-nonempty F10 refusal. It keeps
pending-response wait, timeout, cutoff, receipt, identity, exact instance and
atomic combined-save gates. No inventory mutation is introduced by close.
Ground/drop/half-return keys stay disabled until their authority and shared
persistence exist. No feature remains blocked awaiting these four answers.

The original inventory012_rules.json is retained byte-for-byte as a historical
source projection so its audit hash does not invalidate existing schema5 saves.
Its unresolved_features list describes that projection's former decision state;
this document supersedes that list as current user policy. No item rule, capacity,
creation grant, save schema or item identity changes in this carry patch.

Runtime acceptance still required: existing Live27 and Close/pending regression;
technical ready8 clone take999 into carry, normal F10/menu/Exit, cold reconnect
must show same held999 and same gun in hotbar, then carry-preserving close. Do not
claim this proves uncommitted hard-disconnect persistence or natural harvesting.
