B03 / C06 source distance passives, 2026-10-09

Scope
- adapter.gd wraps equipment_expansion_20261009/adapter.gd. Its existing 33
  definitions and result metadata are retained unchanged; only final:B03 and
  final:C06 are appended, making exactly 35 supported ordinary equipment items.
- No Model, Sim, Bridge, source pin, HP, position, timer, event or ledger writes.
  D04 is not admitted. No G18 entry, record, snapshot or replay consumer is added.

Authoritative inputs
- docs/equipment_source_20261004/correction_0959/equipment_system_extracted.json
- tests/equipment_editable_tables_20261004/outputs/equipment_tables/converted/
  equipment_numeric_config.json
- The user clarified on 2026-10-09: B03's extra 5% lifesteal is constant, and
  C06's extra 12 penetration is constant. The source named-passive uniqueness
  rule still applies. Distance controls only each final-damage bonus.

Parameters and units
- final:B03.stat.AD: attack_points -> AD, scale 1
- final:B03.stat.max_health: health_points -> max_hp, scale 1
- final:B03.stat.cdr_pct: percent_points -> cooldown_reduction, scale 0.01
- passive:14.range_threshold: meters (source 4.5, inclusive <=)
- passive:14.damage_bonus: percent_points (source 12)
- passive:14.lifesteal: percent_points (source 5, converted once to 0.05)
- final:C06.stat.AP: ability_points -> AP, scale 1
- final:C06.stat.penetration: penetration_points -> penetration, scale 1
- final:C06.stat.move_speed_pct: percent_points -> move_speed, scale 0.01
- passive:15.range_threshold: meters (source 9, inclusive >=)
- passive:15.damage_bonus: percent_points (source 15)
- passive:15.penetration: penetration_points (source 12, flat)
All twelve fields read the editable current numeric value, require its exact
source unit and reject missing, malformed, negative or nonfinite values.
Percent-point tuning stays in original units until its consumer converts it.
Provenance contains parameter, source_ref, source_unit, current_value,
source_value and scale. No source prices or recipes are copied into new logic.
Commerce keeps B03 at source 3000 gold, I13 + I07 + 700 combine fee; C06 at
source 3250 gold, I14 + I09 + base:B02 + 350 combine fee.

Interfaces
Adapter.build(numeric: Dictionary) -> Dictionary
  Accepted output extends prior result.definitions. Each new definition has
  stats, parameters, passives, actives=[], tier=final, distance_passive and
  distance_passive_parameters. Stats contain only per-copy base contributions.

Passives.select_unique(inventory: Array, definitions: Dictionary) -> Dictionary
  {
    equipped: bool,
    passives: {
      passive:14 or passive:15: {
        passive_id, item_id, uid, owned_copies,
        tuning: {range_threshold, damage_bonus, lifesteal OR penetration}
      }
    },
    constant_stats: {lifesteal: 0.05 if B03 held, penetration: 12 if C06 held}
  }
Only present passives/stat keys are returned. Empty inventory produces false
and two empty dictionaries. Invalid count/UID/definition entries are ignored.
Repeated UIDs are ignored. Multiple distinct UIDs and count > 1 retain actual
owned_copies but activate each named passive once. Returned tuning is detached.
Only the two admitted IDs may activate these mechanisms; another item bearing
a copied passive name cannot activate them through this module.

Passives.factor(hero_position: Variant, enemy_position: Variant,
                selection: Dictionary) -> float
Reads finite Vector3 positions at the actual contact. Uses full Vector3
Euclidean distance, inclusive comparisons and no boundary epsilon. It never
changes the selection or actor positions, and never gates constant_stats.
At source values, B03 yields 1.12 at <= 4.5 m, C06 yields 1.15 at >= 9 m,
and neither yields a bonus in the gap. Invalid inputs yield no effect.
The caller aggregates constant_stats once into equipment_effects, retains
normal per-copy base-stat aggregation, and calls factor only in its existing
eligible final-damage path. The caller owns already-final and replay exclusion.

Verification
mechanism_gate.gd provides five groups: old-33 deep preservation and original
source recipe checks; 12-field validation; inclusive 4.5/9 boundaries on all
axes; unique constants with scalar base-stat contribution checks; invalid
inputs and deep no-mutation assertions. It emits JSON and exits nonzero on a
failure. A command-line argument can set --equipment-distance-result=PATH.
This worker did not launch Godot or a GUI. The gate requires the parent's
serial Godot validation. Pure scalar fixtures do not prove actual damage,
lifesteal, penetration, commerce, native input, P1, or full-floor behavior;
those remain the separate integration validation's responsibility.
