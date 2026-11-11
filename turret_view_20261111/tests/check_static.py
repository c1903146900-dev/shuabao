#!/usr/bin/env python3
"""Text/byte contracts only. Never parses GDScript or launches an engine."""
import argparse
import hashlib
import json
import re
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PRESENTATION = "fengli_route_20261024/presentation.gd"
HELPER = "fengli_route_20261024/turret_view.gd"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runtime", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    base = args.runtime.resolve()
    checks = []

    def check(label, passed, detail=None):
        checks.append({"check": label, "passed": bool(passed), "detail": detail})

    read = lambda path: (base / path).read_text()
    pins = json.loads((ROOT / "SOURCE_HASHES.json").read_text())
    for name, expected in pins["baseline_files"].items():
        check("baseline_exact:" + name, sha(base / name) == expected)
    for name, expected in pins["overlay_files"].items():
        check("overlay_exact:" + name, sha(ROOT / "changes" / name) == expected)
    actual = sorted(str(p.relative_to(ROOT / "changes")) for p in (ROOT / "changes").rglob("*") if p.is_file())
    check("exact_two_changed_sources_no_guard_assets_or_G10", actual == sorted([PRESENTATION, HELPER]))
    manifest = json.loads(read("first_hero_full_admission_20261020/manifest.json"))
    mismatches = [p for p, expected in manifest["files"].items() if sha(base / p.removeprefix("res://")) != expected]
    check("existing_manifest_and_all_bound_files_unchanged", not mismatches, {"count": len(manifest["files"]), "mismatches": mismatches})
    before = read(PRESENTATION)
    after = (ROOT / "changes" / PRESENTATION).read_text()
    view = (ROOT / "changes" / HELPER).read_text()
    runtime = read("scripts/combat/common_hex_runtime.gd")
    core = read("scripts/combat/hero_combat_core.gd")
    bridge = read("fengli_route_20261024/g02/common_bridge.gd")
    core_bridge = read("scripts/combat/common_hex_bridge.gd")
    for label, required in {
        "real_shift_ends_spawn_turret": 'active("g28") and str(state.get("slot", "")) == "shift"',
        "real_entity_has_id_and_origin": 'turrets.append({"entity_id":_entity_id("turret"),"last_world_at":time,"position":state.start_position',
        "source_world_elapsed_owns_expiry": 'var elapsed = _world_elapsed(turret,dt)',
        "source_controls_active_fire_time": 'var active_dt = minf(elapsed, turret.left)',
        "source_selects_nearest_in_original_range": 'var targets = _nearest(_enemies(ctx), turret.position, parameter("g28", 3))',
        "source_shot_has_no_flight": '_damage(targets[0], turret.damage, "common_g28", turret.position, {"cast_id":turret.cast_id})',
        "source_expiry_removes_entity": 'if turret.left <= EPS: turrets.erase(turret)',
    }.items():
        check(label, required in runtime)
    check("original_drain_witness_wraps_apply", "_g02_drained_event=event\n   _apply(event)\n   _g02_drained_event={}" in bridge)
    check("generic_bridge_commits_then_presents", core_bridge.index("s.damage_enemy(") < core_bridge.index('s.emit_event("common_hex_"'))
    check("damage_contains_committed_source_and_target_positions", '"position":enemy.position,"source_position":source_position,"amount":actual' in core)
    check("event_logged_before_signal", core.index("event_log.append(event.duplicate(true))") < core.index("combat_event.emit(event.duplicate(true))"))
    check("generic_hit_reaction_already_accepts_G28", 'if str(event.get("kind",""))!="damage"' in read("fengli_route_20261024/hit_reaction.gd") and 'event.get("source"' not in read("fengli_route_20261024/hit_reaction.gd"))
    check("default_skill_hit_filter_excludes_hex", 'bool(event.get("hex_generated", false))' in read("fengli_route_20261024/skill_effects.gd"))
    check("baseline_projectile_draw_is_enemy_collection_only", 'for projectile:Dictionary in host.sim.projectiles:' in before and 'if str(projectile.get("team",""))!="enemy":continue' in before)
    check("view_reads_live_entities_without_spawn_synthesis", 'for entry: Variant in live.turrets:' in view and '"turret_spawn"' not in view)
    check("copied_body_fields_only", '"entity_id":str(entry.entity_id), "position":entry.position, "left":float(entry.left), "cast_id":int(entry.cast_id)' in view)
    check("source_TTL_controls_visibility", 'float(entry.left) <= 0.0' in view)
    check("complete_scope_includes_sim_run_room_generation", 'sim.get_instance_id(), sim.route_run_id, sim.combat_level_id, sim.room_id, sim.encounter_generation' in view)
    check("combat_death_and_common_scope_reject_stale_bodies", all(s in view for s in ['sim.hero.dead', 'sim.phase != "combat"', 'not live.combat', 'live.room_id != sim.room_id', 'live.generation != sim.encounter_generation', 'not live.active("g28")']))
    check("internal_and_route_run_identity_domains_preserved", 'original.get("run_id", "") != sim.common.runtime.run_id' in view and 'event.get("run_id", "") != sim.route_run_id' in view and 'live.run_id != sim.route_run_id' not in view)
    check("feedback_only_for_original_committed_positive_damage", all(s in view for s in ['event.get("kind", "") != "damage"', 'float(event.amount) <= 0.0', 'sim.common._inside_hit <= 0', 'not sim.common._draining', 'original.get("target_id", "") != event.get("target", "")', 'original.get("position") != event.source_position', 'sim.event_log.back() != event']))
    check("deduplication_and_bounded_feedback", 'int(event.sequence) <= _last_sequence' in view and 'if _shots.size() > MAX_SHOT_FLASHES' in view)
    check("source_world_clock_not_frame_delta", 'var now: float = float(sim.clock.world_time)' in view and 'now - float(shot.world_time)' in view)
    check("shared_visual_muzzle_anchor", 'var muzzle: Vector2 = foot + MUZZLE_OFFSET' in view and 'view.p(shot.source_position) + MUZZLE_OFFSET' in view)
    check("no_target_impact_effect_duplicate", 'view.draw_line(origin, target,' in view and 'view.draw_circle(target' not in view and 'view.draw_arc(target' not in view)
    check("turret_bodies_use_original_depth_sort", after.index('for turret:Dictionary in turret_state.turrets:') < after.index('actors.sort_custom(') < after.index('turret_view.draw_body(self,actor.turret)'))
    check("actual_foreground_precedes_receipt", after.index('turret_view.draw_shots(self,host.sim)') < after.index('receipt["common_turrets"]='))
    check("scope_death_and_invalid_owner_clear_view", after.count('rescue_effects.clear();turret_view.clear();') == before.count('rescue_effects.clear();') and 'if not active:\n  turret_view.clear()' in after)
    # Lexical safeguard only, not a language parser or runtime proof.
    executable = "\n".join(line.split("#", 1)[0] for line in view.splitlines())
    check("no_simulation_assignment_or_collection_mutation", not re.search(r"(?:sim|live|model)\.[\w.]+\s*(?:=(?!=)|\+=|-=)|(?:sim|live|model)\.[\w.]+\.(?:clear|append|erase|pop_front|pop_back)\(", executable))
    check("no_gameplay_commands_or_new_clock", not any(s in executable for s in ['damage_enemy(', 'request_action(', 'emit_event(', 'runtime.parameter(', 'Time.', 'await ', 'randf(', 'Input.', '_process(']))
    check("no_range_circle_or_damage_text", not any(s in executable for s in ['draw_arc(', 'draw_circle(', 'draw_string', 'G28-3', 'parameter(']))
    fixture = (ROOT / "tests/observe_turrets.gd").read_text()
    check("fixture_not_autoexecuting_entry", fixture.startswith('extends RefCounted') and 'func _init(' not in fixture and 'func run()' in fixture)
    check("fixture_real_shift_and_source_tick", 'sim.request_action("shift"' in fixture and 'sim.step(1.0 / 120.0)' in fixture)
    check("fixture_lifecycle_pause_replay_fake_expiry_covered", all(s in fixture for s in ['view_has_no_gameplay_writes', 'pause_freezes_source_and_view', 'public_fake_damage_cannot_create_trace', 'source_expiry_removes_body_without_resurrection', 'source_clear_removes_cached_body', 'generation_change_clears_body_and_feedback', 'death_clears_body_and_feedback', 'combat_end_clears_body_and_feedback']))
    evidence = json.loads((ROOT / "RULE_EVIDENCE.json").read_text())
    check("decoded_G28_has_original_parameters", evidence['rule']['values'] == {'G28-1': 4.0, 'G28-2': 0.8, 'G28-3': 9.0, 'G28-4': 12.0, 'G28-5': 18.0, 'G28-6': 15.0, 'G28-7': 2.0, 'G28-8': 3.0})
    check("decoded_first_floor_candidate_is_eligible", evidence['approved'] and evidence['required_hooks_present'] and evidence['machine_floor_definition']['weight'] > 0 and not evidence['machine_floor_definition']['ranged_only'] and not evidence['machine_floor_definition']['skill_dependencies'])
    with tempfile.TemporaryDirectory(prefix="turret-patch-", dir=ROOT) as tmp:
        work = Path(tmp)
        (work / PRESENTATION).parent.mkdir(parents=True)
        (work / PRESENTATION).write_text(before)
        patch = (ROOT / "turret_view.patch").resolve()
        result = subprocess.run(["git", "apply", "--check", str(patch)], cwd=work, capture_output=True, text=True)
        check("patch_applies_to_exact_baseline", result.returncode == 0, result.stderr.strip())
        if result.returncode == 0:
            result = subprocess.run(["git", "apply", str(patch)], cwd=work, capture_output=True, text=True)
            check("patch_equals_overlay", result.returncode == 0 and all((work / p).read_bytes() == (ROOT / "changes" / p).read_bytes() for p in actual))
    report = {"status": "STATIC_CONTRACT_PASS" if all(c['passed'] for c in checks) else "FAIL", "checks": checks, "engine_launched": False, "limitations": ["No GDScript parse/type/runtime test.", "Fixture NOT RUN.", "No GUI, screenshots or natural-floor play.", "No admission, merge, PCK or manifest change."]}
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({"status": report['status'], "passed": sum(c['passed'] for c in checks), "failed": [c['check'] for c in checks if not c['passed']]}))
    return 0 if report['status'] == 'STATIC_CONTRACT_PASS' else 1


if __name__ == "__main__":
    raise SystemExit(main())
