#!/usr/bin/env python3
"""Source/pack contracts only. Does not parse or execute GDScript or launch Godot."""
import argparse
import hashlib
import json
import re
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PRESENTATION = "fengli_route_20261024/presentation.gd"
HELPER = "fengli_route_20261024/soul_pickup_view.gd"


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

    def read(path):
        return (base / path).read_text()

    pin = json.loads((ROOT / "SOURCE_HASHES.json").read_text())
    for name, expected in pin["baseline_files"].items():
        check("baseline_exact:" + name, sha(base / name) == expected)
    for name, expected in pin["overlay_files"].items():
        check("overlay_exact:" + name, sha(ROOT / "changes" / name) == expected)
    actual_files = sorted(str(p.relative_to(ROOT / "changes")) for p in (ROOT / "changes").rglob("*") if p.is_file())
    check("exact_two_file_overlay_no_guards_or_assets", actual_files == sorted([PRESENTATION, HELPER]))
    manifest = json.loads(read("first_hero_full_admission_20261020/manifest.json"))
    mismatches = [path for path, expected in manifest["files"].items() if sha(base / path.removeprefix("res://")) != expected]
    check("all_existing_manifest_bindings_unchanged", not mismatches, {"count": len(manifest["files"]), "mismatches": mismatches})
    before = read(PRESENTATION)
    after = (ROOT / "changes" / PRESENTATION).read_text()
    view = (ROOT / "changes" / HELPER).read_text()
    runtime = read("scripts/combat/common_hex_runtime.gd")
    bridge = read("fengli_route_20261024/g02/common_bridge.gd")
    core_bridge = read("scripts/combat/common_hex_bridge.gd")
    source = read("scripts/combat/hero_combat_core.gd")
    route_sim = read("fengli_route_20261024/sim.gd")
    check("baseline_has_no_soul_presentation", "soul" not in before and "soul" not in read("fengli_route_20261024/environment_view.gd"))
    for label, text in {
        "source_real_drop": 'souls.append({"entity_id":_entity_id("soul")',
        "source_world_TTL": 'soul.left -= _world_elapsed(soul,dt)',
        "source_original_range": 'distance_to(soul.position) <= parameter("g10", 6) + EPS',
        "source_original_QE_reset": '_reset_nonultimate("common_g10")',
        "source_real_pickup_event": '_emit("soul_pickup", {"source":"common_g10", "position":soul.position})',
        "source_actor_speed_duration": 'soul_speed_until = actor_time + parameter("g10", 4)',
    }.items():
        check(label, text in runtime)
    check("bridge_witness_wraps_all_event_kinds", "_g02_drained_event=event\n   _apply(event)\n   _g02_drained_event={}" in bridge)
    check("bridge_non_execute_uses_original_apply", 'if event.get("kind")!="execute":super._apply(event);return' in bridge)
    check("event_id_survives_presentation_copy", 'var presentation = event.duplicate(true)' in core_bridge and 'presentation.erase("kind")' in core_bridge and 'presentation.erase("event_id")' not in core_bridge)
    check("source_event_logged_before_callback", source.index("event_log.append(event.duplicate(true))") < source.index("combat_event.emit(event.duplicate(true))"))
    check("route_event_includes_run_id", 'actual["run_id"] = route_run_id' in route_sim)
    check("view_reads_only_live_entities", "for entry: Variant in live.souls:" in view and '"soul_spawn"' not in view)
    check("view_keeps_only_scalar_copies", '"entity_id":str(entry.entity_id), "position":entry.position, "left":float(entry.left)' in view and "receipt.souls.append(entry)" not in view)
    check("view_uses_source_world_time", "var now: float = float(sim.clock.world_time)" in view and "Time." not in view and "delta" not in view)
    check("view_uses_original_projected_radius", 'model.hex_parameter("common_g10", "G10-6")' in view and "* float(soul.pickup_radius)" in view)
    check("foreground_resamples_current_source", "func draw_foreground(view: Node2D, sim: Node)" in view and view.count("var state: Dictionary = sample(sim)") == 2)
    check("scope_covers_sim_run_room_generation", "sim.get_instance_id(), sim.route_run_id, sim.combat_level_id, sim.room_id, sim.encounter_generation" in view)
    check("death_noncombat_room_and_generation_rejected", all(x in view for x in ["sim.hero.dead", 'sim.phase != "combat"', "not live.combat", "live.room_id != sim.room_id", "live.generation != sim.encounter_generation"]))
    check("scope_clear_resets_entities_and_feedback", '_pickups.clear()' in view and 'receipt.clear()' in view and 'if next != _scope:\n  clear()' in view)
    check("receipt_records_actual_live_and_pickup_counts", "receipt.live_count = receipt.souls.size()" in view and "receipt.pickup_count = receipt.pickups.size()" in view)
    check("feedback_requires_original_event_id", 'original.get("event_id") != event.get("event_id")' in view and "not sim.common._draining" in view and "sim.event_log.back() != event" in view)
    check("feedback_expiry_uses_world_age", "now - float(entry.world_time)" in view and "age >= PICKUP_FLASH_SECONDS" in view)
    check("ground_before_hostile_warnings", after.index("soul_pickups.draw_ground(self,host.sim)") < after.index(" _draw_pitcher_zones()"))
    check("frame_receipt_after_actual_foreground", after.index("soul_pickups.draw_foreground(self,host.sim)") < after.index('receipt["soul_pickups"]=soul_pickups.receipt.duplicate(true)'))
    check("host_reset_points_clear_new_view", after.count("rescue_effects.clear();soul_pickups.clear();") == before.count("rescue_effects.clear();") and "if not active:\n  soul_pickups.clear()" in after)
    # Limited lexical guard, explicitly not a GDScript parser or behavior proof.
    executable = "\n".join(line.split("#", 1)[0] for line in view.splitlines())
    check("no_source_assignment_or_mutating_calls", not re.search(r"(?:sim|live|model)\.[\w.]+\s*(?:=(?!=)|\+=|-=)|(?:sim|live|model)\.[\w.]+\.(?:clear|append|erase|pop_front|pop_back)\(", executable))
    check("no_gameplay_commands_or_extra_clock", not any(x in executable for x in ["damage_enemy(", "request_action(", "start_skill_cooldown(", "reset_cooldowns(", "emit_event(", "runtime.parameter(", "Time.", "await "]))
    check("no_ui_text_or_input_added", not any(x in executable for x in ["draw_string", "Input.", "_input(", "Button.new", "Label.new"]))
    observer = (ROOT / "tests/observe_souls.gd").read_text()
    check("fixture_is_opt_in_not_engine_entry", observer.startswith("extends RefCounted") and "func _init(" not in observer and "func run()" in observer)
    check("fixture_covers_pickup_expiry_pause_clear_death", all(x in observer for x in ["paused_source_and_view_frozen", "real_touch_removes_entity_and_flashes", "original_expiry_removes_without_flash", "source_clear_has_no_cached_ground_entity", "death_clears_view", "battle_end_clears_view"]))
    with tempfile.TemporaryDirectory(prefix="soul-patch-check-", dir=ROOT) as tmp:
        work = Path(tmp)
        (work / PRESENTATION).parent.mkdir(parents=True)
        (work / PRESENTATION).write_text(before)
        patch = (ROOT / "soul_pickup.patch").resolve()
        validation = subprocess.run(["git", "apply", "--check", str(patch)], cwd=work, capture_output=True, text=True)
        check("patch_applies_to_exact_source", validation.returncode == 0, validation.stderr.strip())
        if validation.returncode == 0:
            applied = subprocess.run(["git", "apply", str(patch)], cwd=work, capture_output=True, text=True)
            check("applied_patch_equals_overlay", applied.returncode == 0 and all((work / name).read_bytes() == (ROOT / "changes" / name).read_bytes() for name in actual_files))
    report = {"status": "STATIC_CONTRACT_PASS" if all(c["passed"] for c in checks) else "FAIL", "checks": checks, "limitations": ["No GDScript parse/type/runtime test.", "No engine, GUI, screenshots or natural-route gameplay.", "Fixture observer authored but never run.", "Not admitted, merged or published."], "engine_launched": False}
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({"status": report["status"], "passed": sum(c["passed"] for c in checks), "failed": [c["check"] for c in checks if not c["passed"]]}))
    return 0 if all(c["passed"] for c in checks) else 1


if __name__ == "__main__":
    raise SystemExit(main())
