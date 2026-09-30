"""Generate real MCP workflows using canonical combat sources; no app socket access.
Run each workflow with scripts/mcp/check.py. The fixed upstream simulate_* tools
silently queue nothing in the editor, so input tests use execute_game_script to
queue through the RUNNING MCPInputBridge. Mouse press/release are distinct native
events in the test harness, avoiding the upstream reused InputEvent click bug.
"""
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCES = {
    "data/combat": ["tuning", "ability_tuning"],
    "scripts/actors": ["fengli_model", "actor_view"],
    "scripts/combat": ["world_clock", "loadout_fixture", "ability_extensions", "combat_sim", "debug_hud", "arena"],
    "tests/combat": ["tests_core", "tests_extended", "tests_loadout_fixture", "harness", "runner"],
}

def call(tool, arguments=None, wait=0):
    step = {"server": "godot", "tool": tool, "arguments": arguments or {}}
    if wait:
        step["wait_after"] = wait
    return step

def runtime(code, wait=0):
    return call("execute_game_script", {"code": code}, wait)

def queued(event, wait=0):
    return runtime('get_node("/root/MCPInputBridge").queue_events(' + json.dumps([event]) + ')', wait)

def build():
    result = []
    for directory, names in SOURCES.items():
        for name in names:
            relative = f"{directory}/{name}.gd"
            result.append(call("create_script", {"script_path": "res://" + relative,
                "content": (ROOT / relative).read_text(), "overwrite": True}))
    for scene, script in [("fengli_arena", "scripts/combat/arena.gd"), ("acceptance", "tests/combat/harness.gd")]:
        path = f"res://scenes/combat/{scene}.tscn"
        result.extend([call("create_scene", {"scene_path": path, "root_type": "Node3D", "overwrite": True}, 1),
            call("open_scene", {"scene_path": path}, 1), call("attach_script", {"node_path": ".", "script_path": "res://" + script}),
            call("save_scene")])
    return result

def launch():
    return [call("open_scene", {"scene_path": "res://scenes/combat/acceptance.tscn"}, 1),
        call("play_scene", {"mode": "current"}, 14)]

def inputs():
    result = [runtime("run_all_tests()")]
    for label, key in [("w",87),("s",83),("a",65),("d",68),("shift",4194325),("q",81),("e",69),("r",82),("preset",4194337)]:
        result += [runtime(f'begin_input_probe("{label}")'), queued({"type":"key","keycode":key,"pressed":True},.35),
            queued({"type":"key","keycode":key,"pressed":False},.35),runtime("finish_input_probe()")]
    result += [runtime('begin_input_probe("aim")'),queued({"type":"mouse_move","x":1000,"y":300},.4),runtime("finish_input_probe()"),
        runtime('begin_input_probe("attack")'),runtime("inject_mouse_button(640,260,true)",.2),
        runtime("inject_mouse_button(640,260,false)",.25),runtime("finish_input_probe()"),runtime("input_report()")]
    return result

def demo():
    result = [runtime("run_all_tests()"),runtime("begin_demo()")]
    # 97 real MCP viewport samples, 0..12 simulated real seconds, assembled at 8fps.
    for index in range(97):
        if index:
            result.append(runtime("sample_demo(0.125)"))
        result.append(call("get_game_screenshot"))
    for expr in ["fixture_warning()","fixture_ultimate()",'fixture_candidate_visual(1,"q")',
            'fixture_candidate_visual(1,"e")','fixture_candidate_visual(1,"r")',
            'fixture_candidate_visual(2,"e")',"fixture_victory()"]:
        result.extend([runtime(expr),call("get_game_screenshot")])
    return result

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=["build", "verify", "input", "demo"])
    parser.add_argument("--out", required=True)
    args = parser.parse_args()
    if args.mode == "build":
        workflow = build()  # Restart editor before verify to avoid hot-reload cache diagnostics.
    else:
        workflow = launch()
        workflow += inputs() if args.mode == "input" else demo() if args.mode == "demo" else [runtime("run_all_tests()"),call("get_game_screenshot")]
        workflow.append(call("stop_scene"))
    output = Path(args.out)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(workflow, ensure_ascii=False, indent=2))
    print(f"{len(workflow)} MCP calls -> {output}")
