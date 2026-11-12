# Isolated G16 source-missile display

Baseline: passed 4112ebb6 (dash_trail01), not layered on G10, G28 or dash-attack-pitch candidates. Existing common G16 logic already emits real missile entities after eligible nonultimate actions and moves them toward chosen targets before committing damage. Fengli presentation previously rendered only sim.projectiles (enemy projectiles), not common.runtime.projectiles. No G16 renderer or missiles_fired consumer existed in the route. This is a source-evidenced missing visual connection, not a newly observed gameplay failure.

The new missile_view.gd draws a compact cyan/gold bolt at each live G16 source position, oriented toward that entity's actual target. It never spawns from notifications, chooses a target, moves a source entity, advances a timer, adds collision, range, damage or impact effects. G11 corpses and other sources are excluded. Invalid/expired entries, dead targets, hero death, inactive G16, room/generation mismatch and non-combat state are hidden. Every sample is rebuilt from live source arrays; no cached projectile survives source removal. Existing generic hit feedback remains unchanged.

Only presentation.gd plus the new helper change; binding manifest/generation are resealed. Existing core, reward, skill, stat, timing, guard and other presentation helpers are byte-identical. Expected PCKffc527630e612199cc0553dcd305626cd67074110207ea8cfed4e867ab1f2261 has258 bindings. This checkpoint is NOT merged or selected for delivery.

Offline checks now include exact preservation of all existing presentation function signatures (36 checks). Runtime and visual coverage is recorded in RUNTIME_QA.md. The source-array fixture has now run with 14 passing checks; its embedded historical UNRUN label predates execution and is not the current result.

Still unverified: natural G16 reward acquisition, moving-target/wall interactions in free combat, full first floor, native player control quality, Windows and audible output. Keep this candidate isolated. The test used explicit G16 selection, position and enemy-AI fixtures; it did not change projectile speed, targeting or damage.

Apply presentation.patch with zero-context support against exact before hash, add changes/fengli_route_20261024/missile_view.gd, and reseal with the existing public recovery tool. The full presentation source is provided for exact recovery; do not alter the established guard. No private reference, artwork, executable, raw log or credentials are included.

## Correction after first guarded attempt
The first candidate failed at authenticated bootstrap: a broad replacement accidentally changed the existing _draw_enemy_projectiles function declaration. No visual/logic test ran. This revision restores the exact declaration and checks every presentation function signature matches baseline. Guard was unchanged; original run exited4 with complete cleanup, no guard fault. This revised pack loaded and completed the final guarded short test described below. Preserve the failed prior checkpoint as history, not a working candidate.
