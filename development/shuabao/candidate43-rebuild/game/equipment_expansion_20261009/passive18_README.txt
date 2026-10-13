A05 source adapter and passive18 pure consumer

Scope: one new supported equipment item, final:A05 (处刑轮机), whose sole
mechanism is passive:18 (巨物猎手). The original 32 equipment definitions are
preserved; G06 and its upgraded task variant remain unavailable in this module.

Interfaces

Adapter.build(numeric: Dictionary) -> Dictionary
  Calls the unchanged content01 adapter, verifies its 32 supported items, and
  adds exactly A05. Returns the original result and metadata with one extra
  definitions entry. A05 contains:
    stats: AD, crit_chance, penetration
    passives: ["passive:18"]
    passive18: base_damage_bonus, damage_bonus_cap, lost_hp_step,
               step_damage_bonus (all four remain source percent points)
    parameters / passive18_parameters: detached value and provenance records
  Commerce remains responsible for prices, recipes, buying, selling and undo.

Passive18.select_unique(inventory: Array, definitions: Dictionary) -> Dictionary
  Returns equipped, tuning, item_id, uid, owned_copies and passive_id.
  Missing, unsupported or invalid A05 definitions return equipped=false with
  tuning={}. Only genuine-shaped A05 inventory entries with nonnegative integer
  UID and positive integer count qualify. Repeated UIDs are ignored; additional
  copies are reported but never create an additional passive multiplier.
  Returned tuning is a detached copy. Nothing in either input is changed.

Passive18.factor(enemy: Dictionary, tuning: Dictionary) -> float
  Requires the actual rank_category "elite" or "boss" and finite numeric hp
  and max_hp with 0 <= hp <= max_hp and max_hp > 0. Empty/invalid source tuning,
  other ranks, or invalid health yield the neutral multiplier 1.
  Formula:
    lost_percent = (max_hp - hp) / max_hp * 100
    steps = floor(lost_percent / lost_hp_step)
    bonus = min(base_damage_bonus + steps * step_damage_bonus, damage_bonus_cap)
    multiplier = 1 + bonus / 100
  No epsilon, rounding-up, target mutation, owner binding, clock or cache.
  At original values: full HP=1.12; 25% lost=1.14; 50%=1.16; 75%=1.18;
  the purely mathematical 100%-lost boundary=1.20. The existing real damage
  pipeline rejects dead targets before this hook, so 0HP is not a live hit.

Model integration contract (implemented separately by the parent task)

  selected = Passive18.select_unique(state.inventory, runtime_stat_definitions)
  multiplier = Passive18.factor(enemy, selected.tuning)

The ordinary Sim's original _hero_final_outgoing_multiplier should retain its
super result and multiply by this value. The existing source damage pipeline
owns snapshot_final/replay bypass. This consumer deliberately takes no event
argument and introduces no damage-source, no_reactions or direct-hit whitelist.
P1's already-final actual-damage-based supplement is not multiplied a second
time by this module. It does not read hero HP or hero.stats and cannot create a
max-HP-to-damage projection cycle.

Authority

docs/equipment_source_20261004/correction_0959/equipment_system_extracted.json:
  lines1235-1265: A05 costs3300; AD55, crit20%, penetration20; I04+I11+B01,
                  component total2900 and combination fee400.
  lines3317-3319: elite/Boss final damage12%, +2% per25% missing maximum HP,
                  cap20%, without attack/skill/damage-type source restrictions.
  lines3811-3814: explicit floor-step interpretation and legal living-target
                  usual maximum18%; do not change source numbers to reach20%.
tests/equipment_editable_tables_20261004/outputs/equipment_tables/converted/equipment_numeric_config.json:
  lines529-552: price and three A05 stat parameters and units.
  lines2107-2130: four passive18 parameters with original DOCX references.
  lines5243-5245: same-name passive uniqueness across equipment copies.

Verification

Prepared but not executed by the module author. No Godot, Blender or GUI was
launched for this implementation. Source review is not a parser/runtime pass.

godot --headless --path /workspace/scratch/73ebae91a474/loot_resume_1115/candidate04 --script res://equipment_expansion_20261009/mechanism_gate.gd -- --equipment-a05-result=/tmp/equipment_a05_mechanism.json

The gate uses the real source numeric map, checks every original definition and
metadata field remains byte-equivalent, proves current editable values reach
the consumer, rejects invalid/missing nodes/values/units, covers both target
ranks and every25% threshold on either side, cap and invalid health, duplicate
UIDs, multiple copies, held-but-unadmitted items, and pure nonmutation.

It is a bounded pure-function gate. It explicitly does not claim actual source
hits, commerce integration, G18 recording/replay, P1 composition, native input,
balance, or natural floor progression. The parent task owns those integrations
and the new source-binding admission; no existing pins are changed here.
