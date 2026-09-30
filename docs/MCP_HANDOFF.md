# MCP 与图形接入复核（2026-09-30）

> 最新接入结果：标准 MCP SDK 客户端已完成两服务握手、工具调用和动画往返，见 [可复用 MCP 客户端](MCP_CLIENT.md)。下文保留此前阶段记录。

继续初始化提交 `68f919e79480b6428afb3687ba727926829f8793`，未重新创建项目。本文更新首次记录的环境判断。

## 已解决：图形入口

环境自带 Xorg 1.21.1.16、dummy 驱动和 `/etc/X11/xorg.conf`，不需要安装 Xvfb。临时启动 `:97`，使用 Xauthority cookie 和 `-nolisten tcp`；未更改系统配置。结束时停止 Xorg、Godot、Blender，并移除临时授权文件。

- Godot 4.6.3 使用 Mesa llvmpipe/OpenGL 4.5 软件渲染，1280×720 游戏窗口正常显示地面、角色、中文标题及退出按钮焦点。首个 10 秒截图仍为 splash，等待 40 秒后的 [实际场景截图](validation/godot-scene.png) 已人工检查。V-Sync 驱动告警不影响此画面验证；没有性能验收或多分辨率交互验收。
- Blender 4.3.2 的真正 GUI 已启动，[截图](validation/blender-gui.png) 可见默认场景和首次设置面板；不是 `-b`。尚未进行插件操作、动作编辑或交互验收。
- 本次使用命令启动应用和屏幕截图，仅验证图形基础设施，不能代替 MCP 工具调用。

## 已解决：部分网络访问

本轮 `git ls-remote` 和源码 clone 成功，npm registry 与 PyPI 元数据查询均 HTTP 200。不能把上一轮代理 403 推断为永久网络禁止。实际依赖安装尚未执行，下载所有依赖是否成功仍待验证。Library 按要求没有再次尝试。

只下载源码供阅读，放在忽略目录 `.local/`，没有启用插件或执行包安装脚本：

- Godot MCP：`328e15f7d38092371b2aca8b81c40b8188bbe747`，本地 `.local/godot-mcp-src`。
- Blender MCP：`60d2a31b4632a7bc178f3dd636f7e68dfb5c8ae4`，本地 `.local/blender-mcp-src`，包版本 2.1.3。

## 当前接入限制的准确范围

本机 `codex-cli 0.159.0-alpha.3` 的 `mcp add` 确认支持 stdio 和 Streamable HTTP；`codex mcp list` 为空只能证明尚未配置。

[OpenAI 官方 MCP 文档](https://developers.openai.com/codex/mcp/) 说明 CLI 可读用户或受信项目的 config.toml；托管网页会话不读取本地 Codex 配置，而使用插件工具。因此，仅在容器写入配置不能证明当前助手可以调用。文档也提供远程执行器 stdio 设置，但需宿主明确支持，不能由执行器单方面假定已接入。

当前工具目录未暴露 Godot/Blender、动态本地服务器注册或插件搜索/建议动作；这不是对整个产品“永久不支持”的结论。[Plugin Management 技能](skill://plugin_connector_1p_b3438d6beb9081918fba3625bc988128/plugin-management/SKILL.md) 已读取，但缺少其搜索工具，无法确认商店是否存在合适插件。需要用户/平台操作宿主入口，不能通过脚本、额外嵌套代理或公开隧道规避。

## 可选下一步（均不使用用户电脑、不连接阿里云）

**A：同一 shuabao 云主机的受支持 Codex CLI 会话。** 由平台提供该会话并确认项目配置的信任/加载，随后限定安装到本项目。若平台没有该入口，则 A 不可执行，不能要求用户在本机运行来冒充云端。

准备的安装范围：Godot MCP 的 Node 依赖与 build 输出、项目 `addons/godot_mcp`；Blender MCP 的本地 Python 虚拟环境与隔离 Blender 配置目录；项目 `.codex/config.toml`。启用 Godot 插件会注入三个运行期 autoload；Blender 插件会在应用中监听本地连接并可执行 Python。不会启用第三方生成、收费服务或公开端口。该持久插件/配置变更尚未实施，选定宿主并按平台要求确认后才执行。

基于已固定源码的准备命令（未执行）：

```sh
cd /workspace/shuabao/.local/godot-mcp-src/server
npm ci
npm run build
cd /workspace/shuabao
uv venv .local/blender-mcp-venv
uv pip install --python .local/blender-mcp-venv/bin/python .local/blender-mcp-src
```

然后按 [Godot 上游](https://github.com/mkdevkit/godot-mcp) 将 `addons/godot_mcp` 放入本项目并在编辑器启用；按 [Blender 上游](https://github.com/ahujasid/mcp-for-blender) 手动安装固定版本 `addon.py`，在 GUI Preferences → Add-ons 启用，不运行会自动修改多个客户端的 setup 安装器。

拟议项目级配置（示例，尚未加载或启用；仅在以上安装完成且宿主确认支持后使用）：

```toml
[mcp_servers.godot]
command = "node"
args = ["/workspace/shuabao/.local/godot-mcp-src/server/build/index.js"]
[mcp_servers.godot.env]
GODOT_MCP_PORT = "6505"

[mcp_servers.blender]
command = "/workspace/shuabao/.local/blender-mcp-venv/bin/mcp-for-blender"
[mcp_servers.blender.env]
BLENDER_HOST = "127.0.0.1"
BLENDER_PORT = "9876"
DISABLE_TELEMETRY = "true"
```

Godot 固定源码明确绑定 127.0.0.1:6505；Blender addon 默认 localhost:9876。安装前仍应审查依赖与插件权限。配置后的客户端需重载，并在 `/mcp` 中确认两服务器工具，不以 `mcp list` 配置条目代替连接验收。

**B：继续当前托管会话。** 用户/平台在 Plugins 入口查找指定两套 MCP 的受支持集成；若提供则按其授权流程连接。如果没有集成，应由平台确认是否能挂载本执行器的 stdio MCP。没有确认前不启用持久服务，不自行新建 HTTP 网关或暴露端口。

## 最终验收状态

| 项目 | 状态 |
| --- | --- |
| Godot 实际场景可见 | 通过；截图已查看，CLI 启动，非 MCP |
| Blender GUI 可见 | 通过；默认场景/首次设置面板，非 MCP |
| MCP 安装与客户端配置 | 尚未安装/配置；源码已下载审阅 |
| 实际 MCP 查询运行应用 | 未运行；待受支持客户端入口 |
| MCP 最小场景和动画保存、重开、读取关键帧 | 未运行；不能由 CLI 场景冒烟替代 |
| Windows/Linux 导出及文件检查 | 未运行；模板未装、没有导出文件 |

下一验收必须由真实 MCP 工具完成两应用查询、最小场景/关键帧创建、保存、重开与读回，再截图确认播放；导出必须实际执行并检查文件。此轮没有 gameplay 改动、服务器连接、部署、付费服务或可见性修改。
