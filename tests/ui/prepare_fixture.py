"""Prepare only the isolated MCP fixture, preserving any previous fixture by rename."""
from pathlib import Path
import shutil
import time
ROOT = Path(__file__).resolve().parents[2]
fixture = ROOT / '.local/mcp-fixture'
if fixture.exists():
    fixture.rename(fixture.with_name('mcp-fixture-previous-' + str(time.time_ns())))
fixture.mkdir(parents=True)
for name in ('project.godot', 'scripts', 'scenes', 'assets'):
    src = ROOT / name
    if src.is_dir():
        shutil.copytree(src, fixture / name, ignore=shutil.ignore_patterns('mcp'))
    else:
        shutil.copy2(src, fixture / name)
(fixture / 'tests/ui').mkdir(parents=True)
shutil.copy2(ROOT / 'tests/ui/ui_contract_test.gd', fixture / 'tests/ui/ui_contract_test.gd')
shutil.copytree(ROOT / '.local/godot-mcp-src/addons', fixture / 'addons')
with (fixture / 'project.godot').open('a') as stream:
    stream.write('\n[editor_plugins]\nenabled=PackedStringArray("res://addons/godot_mcp/plugin.cfg")\n')
print(fixture)

# Project-local editor metadata: prevent embedding from overriding capture dimensions.
editor = fixture / ".godot/editor"
editor.mkdir(parents=True, exist_ok=True)
(editor / "project_metadata.cfg").write_text("[game_view]\nembed_on_play=false\n")
