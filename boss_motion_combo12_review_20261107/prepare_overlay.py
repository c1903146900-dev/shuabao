"""Rebase only the reviewed Boss presentation additions onto pinned combo12.

This preparation tool never runs Godot, edits an accepted runtime, or copies the
old complete presentation onto the new baseline. Run with --check for no writes.
"""
from pathlib import Path
import argparse
import difflib
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
BASE = ROOT / "rebuild_20261106/motion_combo12/runtime"
OLD = ROOT / "rebuild_20261106/motion_combo08/runtime"
REL = "fengli_route_20261024/presentation.gd"
CANDIDATE = ROOT / "boss_motion_review_20261107/changes03" / REL
OUTPUT = HERE / "changes" / REL
EXPECTED_OLD = "4fc075381df1e24e59669a4912dffbfd11a4f35153fdd431a0009a5c6bbf575d"
EXPECTED_CANDIDATE = "4e10555072c11ef5be5c2a8da4a509b11650050163ae6940c7f7eb4ac56eb9f3"
PINS = {
    REL: "ff3fb399f0e329522c5da625f142f06793b4dcf23def8d73db199b053a3954e6",
    "__clean_fengli/entry.gd": "c9c5a67d26f5f43394e97adfb363c25af31ff3301c03bccbbd802d9dd05971e5",
    "fengli_route_20261024/host.gd": "d2ff80b848bd7154f6869d27e6758cb494b21dc7d9ad79bee9647aee98e56747",
    "fengli_route_20261024/input_router.gd": "651a2b60ea745482c4476ccf764e2d8e5c4f3c681d4cb517c90a8ee5c9473416",
    "fengli_route_20261024/player_health_cue.gd": "2b571eda6f64690e9462103d7ed62531243691cc3f3ec395acbe489f31d7b708",
    "fengli_route_20261024/boss_wave.gd": "9ad11de65fe2b75b2791fe0ab1804ee3d150252e927c9319d3b3b1d7efade32f",
    "fengli_route_20261024/enemy_director.gd": "f03be03ff9490defe9fb67b92566e43e1ab9bc7d1658888c035b4a3adddaa270",
    "scripts/combat/fengli_sim.gd": "fea7d3ef921a672b06c957ee984b64199ec2a09d6ce59daa1c47ad9e61779bbc",
}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def checked_text(path, expected):
    data = path.read_bytes()
    require(digest(data) == expected, "Source identity changed: " + str(path))
    return data.decode("utf-8")


def function(text, name):
    marker = "func " + name + "("
    require(text.count(marker) == 1, "Function boundary not unique: " + name)
    return marker + text.split(marker, 1)[1].split("\nfunc ", 1)[0]


def replace_exact(text, old, new, count=1):
    require(text.count(old) == count, "Patch anchor count changed: " + repr(old[:100]))
    return text.replace(old, new)


def derive_overlay():
    original = checked_text(OLD / REL, EXPECTED_OLD)
    previous = checked_text(CANDIDATE, EXPECTED_CANDIDATE)
    latest = checked_text(BASE / REL, PINS[REL])
    for rel, expected in PINS.items():
        checked_text(BASE / rel, expected)
    event_start = " # A real release owns the brief body settle; recover alone can mean cancellation.\n"
    event_end = " if kind==\"enemy_shot\" and event.has_all"
    require(previous.count(event_start) == 1, "Boss event block not unique")
    event_block = event_start + previous.split(event_start, 1)[1].split(event_end, 1)[0]
    body_start = ' if key=="boss" and host.sim.phase=="combat":\n'
    body_end = " var body_scale:=Vector2(body_facing*"
    enemy_function = function(previous, "_draw_enemy")
    require(enemy_function.count(body_start) == 1, "Boss block must belong to _draw_enemy")
    body_block = body_start + enemy_function.split(body_start, 1)[1].split(body_end, 1)[0]
    patches = [
        ("var enemy_melee_impacts:Dictionary={}\n", "var enemy_melee_impacts:Dictionary={}\nvar boss_body_releases:Dictionary={}\n", 1),
        ("enemy_melee_impacts.clear();default_effects.clear()", "enemy_melee_impacts.clear();boss_body_releases.clear();default_effects.clear()", 2),
        (' if kind=="encounter_finished":animation.clear();enemy_melee_impacts.clear()\n', ' if kind=="encounter_finished":animation.clear();enemy_melee_impacts.clear();boss_body_releases.clear()\n', 1),
        (event_end, event_block + event_end, 1),
        (body_end, body_block + body_end, 1),
    ]
    # Verify the extracted additions reconstruct candidate03 exactly. This also
    # detects any unreviewed change concealed outside those additions.
    reconstructed = original
    for before, after, count in patches:
        reconstructed = replace_exact(reconstructed, before, after, count)
    require(reconstructed == previous, "Candidate contains changes outside the approved Boss additions")
    require("boss_body_releases" not in latest, "Latest baseline already contains a Boss rebase")
    merged = latest
    for before, after, count in patches:
        merged = replace_exact(merged, before, after, count)
    restored = merged
    for before, after, count in reversed(patches):
        restored = replace_exact(restored, after, before, count)
    require(restored == latest, "Reverse-patch conservation failed")
    preserved = ["_hero", "_draw_pitcher_zones", "_reaction_sprite", "_flash_sprite", "_record_body_pick", "body_aim_at", "_body_alpha"]
    for name in preserved:
        require(function(merged, name) == function(latest, name), "Unrelated function changed: " + name)
    require(body_start not in function(merged, "_hero"), "Boss pose inserted in hero function")
    require(function(merged, "_draw_enemy").replace(body_block, "") == function(latest, "_draw_enemy"), "Enemy transform/facing/picking changed outside Boss block")
    require('elif host.sim.phase=="combat" and not host.sim.hero.dead and kind in ["enemy_impact","boss_wave_released"]' in event_block, "Terminal release-storage gate lost")
    report = {
        "status": "prepared_not_engine_tested",
        "baseline": "motion_combo12",
        "origin_candidate": "boss_motion_draft03",
        "source_sha256": PINS[REL],
        "overlay_sha256": digest(merged.encode()),
        "static_checks": {
            "candidate03_reconstructed_exactly": True,
            "reverse_patch_restores_combo12_exactly": True,
            "boss_block_only_in_enemy_function": True,
            "shared_enemy_transform_facing_flash_and_picking_unchanged": True,
            "terminal_release_storage_guard_preserved": True,
            "preserved_functions": preserved,
            "baseline_protected_file_pins": PINS,
        },
        "mechanics_changed": False,
        "engine_or_ui_run": False,
        "pack_built": False,
        "live_boss_cancel_proven": False,
    }
    patch = "".join(difflib.unified_diff(latest.splitlines(True), merged.splitlines(True), fromfile="motion_combo12/" + REL, tofile="boss_motion_combo12_overlay/" + REL))
    return merged, patch, report


def prepare(check=False):
    merged, patch, report = derive_overlay()
    if check:
        require(OUTPUT.exists() and OUTPUT.read_text() == merged, "Prepared overlay missing or changed")
        require((HERE / "boss_additions.patch").read_text() == patch, "Prepared patch missing or changed")
    else:
        OUTPUT.parent.mkdir(parents=True, exist_ok=True)
        if OUTPUT.exists():
            require(OUTPUT.read_text() == merged, "Refusing to overwrite a changed overlay")
        else:
            OUTPUT.write_text(merged)
        (HERE / "boss_additions.patch").write_text(patch)
        (HERE / "static_review.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    print(json.dumps(prepare(args.check), ensure_ascii=False, indent=2))
