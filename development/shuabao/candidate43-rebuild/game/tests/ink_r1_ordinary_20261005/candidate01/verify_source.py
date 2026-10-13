#!/usr/bin/env python3
"""Read-only source verification for the isolated R1 core. Never launches an engine."""
from pathlib import Path
import hashlib
import json
import re
import sys

D = Path(__file__).resolve().parent
R = D.parents[2]
checks = []


def check(value, label):
    checks.append({"label": label, "passed": bool(value)})


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


checkpoint_path = D / "core_checkpoint02.json"
if not checkpoint_path.exists(): checkpoint_path = D / "core_checkpoint01.json"
checkpoint = json.loads(checkpoint_path.read_text())
for relative, digest in checkpoint["unchanged_source_pins"].items():
    check(sha(R / relative) == digest, "unchanged source " + relative)
for relative, digest in checkpoint["core_files"].items():
    check(sha(D / relative) == digest, "core checkpoint " + relative)
check(checkpoint["parent_binding_sha256"] ==
      "1b89127da1767a4c57fe790edd8b29be1d624096cd3d4f16fef486753bce88a0",
      "exact current ordinary E1 parent identity")

catalog = json.loads((R / "data/final_design/catalog.json").read_text())
skill = catalog["heroes"]["yanguizhou"]["skills"]["R1"]
expected = {
    "R1-1": [12, 12, 12, 12], "R1-2": [11, 11.54, 12.5, 14],
    "R1-3": [6, 6.7, 8.2, 10.5], "R1-4": [70, 73, 79, 88],
    "R1-5": [40, 44, 52, 65], "R1-6": [25, 28, 35, 45],
    "R1-7": [140, 131, 116, 96],
}
for token, values in expected.items():
    check(skill["parameters"][token]["values"] == values,
          "unchanged original four-rank values " + token)
progression = catalog["progression"]
check(progression["max_level"] == 18 and progression["leveling_sp_budget"] == 18
      and progression["full_build_cost"] == 23, "18 base SP versus23 full ranks")
check(progression["rank_costs"]["R"] == [1, 2, 2, 2] and
      progression["r_gates"] == [6, 6, 6, 6], "Lv6 first R and no later level gates")

base = (R / "scripts/combat/enemy_director.gd").read_text()
step = base[base.index("func step_enemy("):base.index("\nfunc _interrupt(")]
move = base[base.index("func _move_role("):base.index("\nfunc _turn_facing(")]
step = step.replace(
    " if _frozen(sim) or not sim.ai_enabled or enemy.dead: return\n",
    " if _frozen(sim) or not sim.ai_enabled or enemy.dead: return\n"
    " var snow: Dictionary = sim.r1_step_enemy_rates(enemy,dt)\n"
    " if not bool(snow.in_domain):\n  super.step_enemy(sim,enemy,dt)\n  return\n", 1)
step = step.replace(
    " enemy.timer=maxf(0.0,enemy.timer-dt)",
    " # Only attack preparation/cadence clocks use attack rate. Spawn and active\n"
    " # pounce retain their authored world-time durations; no other timer is scaled.\n"
    ' var attack_dt: float = dt*float(snow.attack_rate) if enemy.state in ["chase","warning","recover"] else dt\n'
    " enemy.timer=maxf(0.0,enemy.timer-attack_dt)\n"
    " # A slowed warning must keep its threat reservation until actual release.\n"
    " # The ordinary world-time decrement above is retained, as are release handoffs.\n"
    ' if enemy.state == "warning":\n'
    '  enemy.threat_left=maxf(float(enemy.threat_left),float(enemy.timer)+(0.40 if enemy.kind=="pouncer" else 0.10))', 1)
step = step.replace(
    "var lunge_speed: float=15.0*(1.0-enemy.slow_amount if enemy.slow_left>0 else 1.0)",
    "var lunge_speed: float=15.0*(1.0-enemy.slow_amount if enemy.slow_left>0 else 1.0)*float(snow.move_rate)", 1)
move = move.replace(
    " var offset: Vector3=sim.hero.position-enemy.position",
    " var snow: Dictionary = sim.r1_step_enemy_rates(enemy,dt)\n"
    " if not bool(snow.in_domain):\n  super._move_role(sim,enemy,dt)\n  return\n"
    " var offset: Vector3=sim.hero.position-enemy.position", 1)
move = move.replace(
    "var speed: float=enemy.speed*(1.0-enemy.slow_amount if enemy.slow_left>0 else 1.0)",
    "var speed: float=enemy.speed*(1.0-enemy.slow_amount if enemy.slow_left>0 else 1.0)*float(snow.move_rate)", 1)
director = (D / "enemy_director.gd").read_text()
check(director[director.index("func step_enemy("):].strip() == (step + "\n" + move).strip(),
      "only documented rate substitutions in two original director methods")
check(director.startswith('extends "res://tests/ink_enemy_navigation_fix01_20261005/enemy_director.gd"'),
      "inherits exact retained navigation and Q3 interception")
check("enemy.slow_amount=" not in director.replace(" ", ""),
      "no R1 write into original timed slow amount")

sim = (D / "sim.gd").read_text()
executable = "\n".join(line for line in sim.splitlines() if not line.lstrip().startswith("#"))
check(sim.startswith('extends "res://tests/ink_e1_ordinary_20261005/candidate01/sim.gd"'),
      "inherits current E1 ordinary source, excludes E2/E3/P1 chains")
check('start_presentation(' not in executable and 'r1_active=' not in executable.replace(" ", ""),
      "no immunity or global presentation slow introduced")
check('func _hero_victory_pending' not in sim,
      "base nondamaging R1 does not add victory pending")
check(executable.count("super._fixed_step(real_dt)") == 1,
      "one inherited fixed-step invocation")
check('match str(enemy.get("rank_category","")):' in sim,
      "category classification does not guess from art/role kind")
check('hero.cooldowns.r = 0' not in executable and 'hero.cooldowns["r"] = 0' not in executable,
      "no room/cancel R cooldown reset")
check(all(x not in executable for x in ["set_level(", "reward_minion", "configure_test_loadout(", "state.points"]),
      "no runtime level XP SP grant")
old_scope = json.loads((R / "tests/ink_e1_ordinary_20261005/candidate01/source_binding.json").read_text())
check(old_scope["runtime_candidates"] == ["Q1", "Q2", "Q3", "E1"] and
      len(old_scope["supported_hex_hooks"]) == 10,
      "ordinary scope remains four old candidates and ten hooks")
for path in sorted(D.glob("*.gd")):
    text = path.read_text()
    classes = re.findall(r'const\s+(\w+)\s*(?::=|=)\s*preload\("res://[^"\n]+\.gd"\)', text)
    illegal = [name for name in classes if re.search(
        r'\b' + re.escape(name) + r'\.(?:resource_path|get_base_script|can_instantiate|get_instance_id)\b', text)]
    check(not illegal, "no const-class Script-resource reflection " + path.name)

binding_path = D / "source_binding.json"
if binding_path.exists():
    binding = json.loads(binding_path.read_text())
    for relative, digest in binding["candidate_files"].items():
        check(sha(D / relative) == digest, "candidate source pin " + relative)

report = {"suite": "ink_r1_isolated_core_source", "passed": all(x["passed"] for x in checks),
          "checks": len(checks), "failures": [x["label"] for x in checks if not x["passed"]],
          "scope": "read-only source bytes and documented substitutions; not GDScript parse or engine",
          "engine_passed": False, "native_input": False, "ordinary_entry_changed": False,
          "checkpoint_path": checkpoint_path.name, "checkpoint_sha256": sha(checkpoint_path)}
print(json.dumps(report, ensure_ascii=False, indent=2))
sys.exit(0 if report["passed"] else 1)
