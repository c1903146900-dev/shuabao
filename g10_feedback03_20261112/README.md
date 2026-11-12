# Isolated G10 pickup floor-feedback candidate

Based on previously isolated soul_pickup01 (a5784552), not merged into the 4112 passed baseline. Only soul_pickup_view.gd drawing changed: the former head-height four small rays are now four outlined floor arcs drawn before actors. Real source event, pickup radius, Q/E reset, lifetime and all battle rules are unchanged. Source hash and patch permit exact reconstruction; reseal manifest/generation/PCK using the existing public tool.

Two serial guarded native-input short tests completed. v02 rendered brighter arcs over torso, so was not selected. v03 draws them behind actors: inspected actual pickup image shows no face/torso overpaint; visible lateral arc is still partly occluded by the hero, not a claim of perfect visibility from all directions. No further cosmetic iterations or merge were made.

Both tests earned 108 XP through 4 genuine source kill events using explicit lethal-damage fixtures, reached original level2/1SP, then used ordinary Q1 UI callback to learn Q. In the next normal room native Space resumed the game and native W entered the original pickup radius. Q and E each changed from fixture 5s cooldown to zero on the committed pickup event; source entity removed and display expired afterward. G10 selection, kill-counter23, lethal packet, hero position, cooldown values and disabled AI are explicit fixtures, not natural acquisition, natural combat, or full-floor success. No prices, XP curve or combat rules changed.

Observer public copy changes output path to user:// only; that path-only copy was not rerun. Executed test is retained locally. Guard was unchanged during these tests; its historical REIMPLEMENTATION_NOT_PRIOR_GUARD label does not prove original historical identity.

Not verified for this visual revision: all directions, screen edges, dense overlapping effects, death/room lifecycle runtime regression, natural full floor, Windows execution, audible sound, or user aesthetic acceptance. Existing earlier logical fixture coverage is separate and not asserted as new-revision testing. No private art, screenshots, raw logs or private design documents are included.
