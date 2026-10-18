Public derivative: private approval transcript and internal attribution omitted. Engineering content below.

# P3 recovery reimplementation, unified gameplay migration

This is a new implementation. No lost-source hash or historical native acceptance is inherited.

## Authority

Mechanism contract: rest retains counts; each successfully completed skill release counts once, not each segment; refund uses remaining cooldown at triggering time; reaching a new threshold on upgrade settles immediately, with zero cooldown retaining readiness until the next successful release. Formal mechanism scope is independent Q/E, excluding R. Existing cross-room retention and death/passive replacement clearing remain. Runtime numbers come exclusively from the original InkTuning/Catalog, which records XLSX 晏归舟技能 E78:H78 and E79:H79, thresholds 4/4/4/3 and refund percentages 60/68/82/100.

## Current implementation

Original Model command owns costs, rank caps, deduplication and allocations. P3 only observes accepted non-replay P-slot changes and records an inverse for the corresponding original allocation. Real combat boundaries erase undo access. Safe cooldown time does not tick. Original rest service finishes both cleanups while its existing transition locks remain held before advancing the cooldown reset barrier, so an upgrade inverse cannot resurrect a cooldown cleared by rest. Death retains learned rank and clears progress; respec/passive removal resets rank zero. No new save format or clock exists.

Successful release uses the existing _c03 stack frame and current family state. Q1/Q2/Q3/E1/E2/E3 commit after their real cooldown writes. E2 boarding and E3 A-only preview are not releases. Release identity includes original run/generation/room/family/cast. The core itself is not a public authorization boundary; its caller is.

## Migration

23 overlay files; no complete source copy. The original 1747 runtime and 71 visual maps remain byte-equivalent data. Nine exact predecessor preimages are separately retained. The new gate validates every real current after plus added core, then authorizes only the exact two predecessor maps for historical replay. Live binding preserves its previous structural checks and old capability comparisons, and exposes P3 only through the separately hash-bound gameplay migration. Current ordinary factory paths are unchanged. The startup Host is the independently reconstructed 7cd9301c successor, including original navigation continuation and existing converted RuntimeActor selection.

The self-hashed gate normalizes only its self-hash value. Manifest and current source_binding have explicit exact hashes. External overlay inventory is the independent seal; coordinated malicious rewriting of all verifier and inventory files is not claimed to be prevented.

## Evidence and limits

check.py records 33 static in-memory checks, using the newly fully verified 3031 hash inventory for unchanged files and actual bytes for overlay files. Includes separate current-after, old-preimage, and wrong-predecessor rejection for all nine replacements. This is not GDScript execution. Core01 has separate isolated native evidence; these Sim/Model/UI changes do not inherit it. Historical test scripts remain present, but are not silently marked rerun or updated by global SHA replacement.

P3 UI retains the original panel, P1/P2 buttons and callbacks. Hidden title plus 142+142+104 button minima, two 8px gaps and 16px horizontal margins have a nominal 420px budget. Actual font combined minimum, viewport containment, readability and button clickability remain native acceptance items. P3 HUD is a read-only projection of core state. The final source must be independently sealed and tested through the original entry/Hex/Session path before being declared playable.
