#!/usr/bin/env bash
# Local-only dependencies for the exact two user-selected MCP sources.
set -euo pipefail
cd "$(dirname "$0")/../.."
export UV_CACHE_DIR="$PWD/.local/uv-cache"
mkdir -p .local
pin_source() {
  local repo_url="$1" source_dir="$2" revision="$3"
  if [[ ! -d "$source_dir/.git" ]]; then
    git clone "$repo_url" "$source_dir"
    git -C "$source_dir" checkout --detach "$revision"
  fi
  [[ "$(git -C "$source_dir" rev-parse HEAD)" == "$revision" ]] || {
    echo "Unexpected source revision: $source_dir" >&2; return 1;
  }
  [[ -z "$(git -C "$source_dir" status --porcelain --untracked-files=no)" ]] || {
    echo "Modified source: $source_dir; refusing to overwrite it" >&2; return 1;
  }
}
pin_source https://github.com/mkdevkit/godot-mcp.git .local/godot-mcp-src 328e15f7d38092371b2aca8b81c40b8188bbe747
pin_source https://github.com/ahujasid/mcp-for-blender.git .local/blender-mcp-src 60d2a31b4632a7bc178f3dd636f7e68dfb5c8ae4
npm ci --prefix .local/godot-mcp-src/server --ignore-scripts --no-audit --no-fund --cache "$PWD/.local/npm-cache"
npm run build --prefix .local/godot-mcp-src/server
if [[ ! -d .local/blender-mcp-venv ]]; then uv venv .local/blender-mcp-venv; fi
uv pip install --python .local/blender-mcp-venv/bin/python -r scripts/mcp/requirements.lock .local/blender-mcp-src
printf '%s\n' 'MCP dependencies ready. No user-level client configuration or startup service was changed.'
