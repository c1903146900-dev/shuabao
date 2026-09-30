"""Real MCP SDK client: stdio initialize/list/call, with temporary local GUIs.
Run with .local/blender-mcp-venv/bin/python scripts/mcp/check.py.
Scene edits must be MCP tool calls supplied in --workflow JSON, never bootstrap code.
"""
import argparse
import asyncio
import base64
import hashlib
import json
import os
from pathlib import Path
import secrets
import shutil
import signal
import subprocess
import time
from contextlib import AsyncExitStack
from datetime import timedelta
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

ROOT = Path(__file__).resolve().parents[2]
PINS = {"godot-mcp-src": "328e15f7d38092371b2aca8b81c40b8188bbe747", "blender-mcp-src": "60d2a31b4632a7bc178f3dd636f7e68dfb5c8ae4"}

def write_json(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")

async def run(args):
    os.chdir(ROOT)
    for name, pin in PINS.items():
        actual = subprocess.check_output(["git", "-C", str(ROOT / '.local' / name), "rev-parse", "HEAD"], text=True).strip()
        if actual != pin:
            raise RuntimeError(f"Source revision mismatch: {name}: {actual}")
    out = ROOT / args.evidence
    out.mkdir(parents=True, exist_ok=True)
    fixture = ROOT / '.local/mcp-fixture'
    if args.fresh_fixture and fixture.exists():
        fixture.rename(fixture.with_name('mcp-fixture-previous-' + str(time.time_ns())))
    if not fixture.exists():
        fixture.mkdir()
        for name in ('project.godot', 'scenes', 'scripts', 'assets', 'data', 'tests'):
            src = ROOT / name
            if not src.exists():
                continue
            if src.is_dir():
                shutil.copytree(src, fixture / name, ignore=shutil.ignore_patterns('mcp', 'preview', 'source', 'evidence', '__pycache__'))
            else:
                shutil.copy2(src, fixture / name)
        shutil.copytree(ROOT / '.local/godot-mcp-src/addons', fixture / 'addons')
        with (fixture / 'project.godot').open('a') as f:
            f.write('\n[editor_plugins]\nenabled=PackedStringArray("res://addons/godot_mcp/plugin.cfg")\n')
    env = os.environ.copy()
    env.update(DISPLAY=':97', XAUTHORITY=str(out / 'Xauthority'),
               XDG_CACHE_HOME=str(ROOT / '.local/cache'), XDG_CONFIG_HOME=str(ROOT / '.local/config'),
               XDG_DATA_HOME=str(ROOT / '.local/data'), DISABLE_TELEMETRY='true',
               BLENDER_HOST='127.0.0.1', BLENDER_PORT='9876', GODOT_MCP_PORT='6505',
               SHUABAO_BLENDER_ADDON=str(ROOT / '.local/blender-mcp-src/addon.py'))
    auth = Path(env['XAUTHORITY'])
    if Path('/tmp/.X97-lock').exists():
        raise RuntimeError('Display :97 already in use; do not disturb it')
    auth.touch(mode=0o600)
    subprocess.run(['xauth', '-f', str(auth), 'add', ':97', 'MIT-MAGIC-COOKIE-1', secrets.token_hex(16)], check=True)
    procs, handles = [], []
    def start(name, cmd):
        log = (out / (name + '.log')).open('w'); handles.append(log)
        proc = subprocess.Popen(cmd, env=env, stdout=log, stderr=log, start_new_session=True)
        procs.append(proc)
        return proc
    def record_result(label, result):
        data = result.model_dump(mode='json')
        texts = ' '.join(c.text for c in result.content if c.type == 'text')
        data['application_error'] = bool(result.isError or texts.lower().startswith('error') or '"error":' in texts.lower())
        for idx, block in enumerate(data.get('content', [])):
            if block.get('type') == 'text':
                try:
                    payload = json.loads(block['text'])
                except (ValueError, TypeError):
                    payload = None
                if isinstance(payload, dict) and 'base64' in payload:
                    raw = base64.b64decode(payload.pop('base64'))
                    image_path = out / (label + '-' + str(idx) + '.png')
                    image_path.write_bytes(raw)
                    payload.update(saved_image=image_path.name, sha256=hashlib.sha256(raw).hexdigest())
                    block['text'] = json.dumps(payload, ensure_ascii=False)
            if block.get('type') == 'image':
                raw = base64.b64decode(block.pop('data'))
                suffix = '.png' if block.get('mimeType') == 'image/png' else '.jpg'
                image_path = out / (label + '-' + str(idx) + suffix)
                image_path.write_bytes(raw)
                block['saved_image'] = image_path.name
                block['sha256'] = hashlib.sha256(raw).hexdigest()
        write_json(out / (label + '.json'), data)
        print(label, 'isError=', getattr(result, 'isError', False), flush=True)
        return data
    try:
        x = start('xorg', ['Xorg', ':97', '-config', str(ROOT/'scripts/mcp/xorg-dummy.conf'), '-nolisten', 'tcp', '-auth', str(auth), '-logfile', str(out/'xorg-server.log')])
        for _ in range(40):
            if x.poll() is not None:
                raise RuntimeError('Xorg failed; inspect log')
            if subprocess.run(['xdpyinfo'], env=env, capture_output=True).returncode == 0:
                break
            await asyncio.sleep(.25)
        else:
            raise RuntimeError('Xorg readiness timed out')
        async with AsyncExitStack() as stack:
            sessions = {}
            specs = {
                'godot': ('node', [str(ROOT / '.local/godot-mcp-src/server/build/index.js')]),
                'blender': (str(ROOT / '.local/blender-mcp-venv/bin/mcp-for-blender'), []),
            }
            for name, (cmd, argv) in specs.items():
                err = (out/(name+'-mcp.log')).open('w'); handles.append(err)
                streams = await stack.enter_async_context(stdio_client(StdioServerParameters(command=cmd, args=argv, env=env), errlog=err))
                session = await stack.enter_async_context(ClientSession(*streams, read_timeout_seconds=timedelta(seconds=90)))
                initialized = await session.initialize()
                write_json(out/(name+'-initialize.json'), initialized.model_dump(mode='json'))
                listed = await session.list_tools()
                write_json(out/(name+'-tools.json'), listed.model_dump(mode='json'))
                print(name, 'initialized', initialized.serverInfo.name, 'tools', len(listed.tools), flush=True)
                sessions[name] = session
            start('godot-editor', ['godot', '--editor', '--path', str(fixture), '--rendering-method', 'gl_compatibility', '--rendering-driver', 'opengl3', '--audio-driver', 'Dummy'])
            start('blender-gui', ['blender', '--factory-startup', '--python', str(ROOT/'scripts/mcp/blender_bootstrap.py')])
            for name, tool, params in [('godot','get_project_info',{}), ('blender','get_scene_info',{'user_prompt': 'MCP connection readiness query'})]:
                deadline = time.monotonic()+100
                attempt = 0
                while time.monotonic()<deadline:
                    attempt += 1
                    result = await sessions[name].call_tool(tool, params)
                    record_result(f'{name}-ready-{attempt}', result)
                    texts = ' '.join(c.text for c in result.content if c.type=='text')
                    bad = result.isError or any(v in texts.lower() for v in ['not connected', 'could not connect', 'connection refused', '"error":', 'error checking', 'error getting'])
                    if not bad:
                        print(name, 'APPLICATION_QUERY_OK', flush=True)
                        break
                    await asyncio.sleep(3)
                else:
                    raise RuntimeError(name+' application not ready; inspect recorded tool results')
            record_result('blender-addon-status-known-upstream-issue', await sessions['blender'].call_tool('get_addon_status', {}))
            record_result('blender-scene', await sessions['blender'].call_tool('get_scene_info', {'user_prompt': 'Verify Shuabao MCP connection; inspect current scene only.'}))
            if args.workflow:
                workflow = json.loads((ROOT / args.workflow).read_text())
                def expand(value):
                    if isinstance(value, str): return value.replace('{{ROOT}}', str(ROOT))
                    if isinstance(value, list): return [expand(v) for v in value]
                    if isinstance(value, dict): return {k: expand(v) for k, v in value.items()}
                    return value
                workflow = expand(workflow)
                for i, step in enumerate(workflow):
                    result = await sessions[step['server']].call_tool(step['tool'], step.get('arguments', {}))
                    data = record_result(f"step-{i:02}-{step['tool']}", result)
                    if data['application_error']:
                        raise RuntimeError(f'MCP tool error at step {i}; inspect result')
                    for expected in step.get('expect_text', []):
                        actual_text = '\n'.join(c.text for c in result.content if c.type == 'text')
                        if expected not in actual_text:
                            raise AssertionError(f'Step {i} missing expected result: {expected}')
                    if step.get('wait_after'):
                        await asyncio.sleep(min(float(step['wait_after']), 45))
            await asyncio.sleep(3)
            subprocess.run(['import','-window','root',str(out/'desktop.png')], env=env, check=True)
            print('MCP_CHECK_COMPLETE', flush=True)
    finally:
        for p in reversed(procs):
            try:
                os.killpg(p.pid, signal.SIGTERM)
            except ProcessLookupError:
                continue
            try:
                p.wait(timeout=8)
            except subprocess.TimeoutExpired:
                os.killpg(p.pid, signal.SIGKILL); p.wait()
        for h in handles:
            h.close()
        auth.unlink(missing_ok=True)

if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fresh-fixture', action='store_true', help='Archive the previous isolated fixture before creating a fresh one')
    parser.add_argument('--workflow', help='JSON list of real MCP tool calls')
    parser.add_argument('--evidence', default='.local/mcp-evidence')
    asyncio.run(run(parser.parse_args()))
