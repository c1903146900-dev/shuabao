# 可复用的标准 MCP 客户端

> 最新：骨骼 GLB 跨应用播放、干净 clone 和两平台实际导出已验证，见 [集成验收](INTEGRATION_VALIDATION.md) 与 [完整复用步骤](CLOUD_REPRO.md)。

本文件取代早期“必须另开 CLI/等待平台插件”的接入建议。托管助手仍没有原生 Godot/Blender 工具菜单，但本云环境可以通过 shell 启动官方 Python MCP SDK 客户端；这是用户明确允许的标准客户端入口。

## 实际调用路径

`助手 → check.py（官方 mcp ClientSession）→ stdio JSON-RPC initialize / tools/list / tools/call → 指定 MCP 服务 → 本地 GUI 插件 → Godot/Blender`

`check.py` 没有直接连接应用插件端口、没有嵌套模型、没有 HTTP 网关或公开端口。普通进程操作只负责临时显示、应用启动和清理。`blender_bootstrap.py` 仅在当次 GUI 会话注册上游插件，不编辑场景。动画及场景改动全部由 JSON 工作流的真实 MCP 调用完成，包括 Blender 上游提供的 `execute_blender_code`；它是 MCP 工具，不是客户端直接执行 bpy。

## 固定来源和范围

- Godot 引擎 4.6.3，Blender 4.3.2，使用已有软件。
- [Godot MCP](https://github.com/mkdevkit/godot-mcp)：`328e15f7d38092371b2aca8b81c40b8188bbe747`，服务 0.1.0，MIT；依赖使用上游 package-lock.json，安装时禁用 npm lifecycle scripts，再显式执行已检查的 `tsc` build。
- [Blender MCP](https://github.com/ahujasid/mcp-for-blender)：`60d2a31b4632a7bc178f3dd636f7e68dfb5c8ae4`，包 2.1.3，插件 1.8 / protocol 13，MIT。
- Python 官方 MCP SDK `mcp==1.30.0`，传递依赖固定于 `scripts/mcp/requirements.lock`。Blender initialize 的 serverInfo.version 报 1.30.0，是框架值，不将其误认作插件包版本。

安装范围仅项目 `.local/`。不更改用户级配置或系统安装，不设常驻服务。Godot 服务绑定 127.0.0.1:6505，Blender 插件使用 localhost:9876；Xorg 使用带 cookie 的 :97，禁用 TCP。Blender 收集功能通过上游 DISABLE_TELEMETRY 环境开关关闭，不启用任何资产/生成集成。

## 重建和验收

在仓库根目录：

```sh
bash scripts/mcp/setup.sh
.local/blender-mcp-venv/bin/python scripts/mcp/check.py \
  --fresh-fixture \
  --workflow scripts/mcp/animation_probe.json \
  --evidence .local/mcp-final-evidence
```

需要现有 `node/npm`、`uv`、`godot`、`blender`、`Xorg`、`xauth`、`xdpyinfo`、ImageMagick `import` 和 dummy Xorg 配置。本环境已具备。setup 会验证源码版本且拒绝覆盖被修改的源码。Python 缓存也放 `.local`，避免只读用户目录问题。尚未在一台完全空白机器上验证安装。

`--fresh-fixture` 会把旧隔离场景改名存档，然后从项目骨架准备新测试副本；不会删除旧场景或修改正式游戏。去掉该参数可对现有 `.local/mcp-fixture` 持续操作。不要在已有验收动画的副本上重复执行会创建同名节点的完整初始工作流；复查时使用只读/打开/播放工具清单。

客户端为每次会话保存 initialize、tools/list、每次 tools/call 返回和 MCP 截图。工具可能返回 `isError=false` 却在正文报错，因此额外记录 application_error，工作流遇到实际错误终止。启动时应用尚未连接的短暂查询失败会保留；应用 ready 后才执行改动。

后续制作可提供新的 JSON 工具调用清单（`server`、`tool`、`arguments`、可选 `expect_text` 和 `wait_after`），同一命令启动真实 MCP 链路。只修改 `.local/mcp-fixture` 内内容；在明确检查差异后再把选定游戏资产/场景保存回正式仓库，不携带调试 autoload、插件依赖或缓存。没有测试过的工具必须先读取实际 tools/list schema，再调用并验证结果。

## 已验收与限制

- 两服务真实 initialize / tools/list 通过：Godot 173 工具，Blender 36 工具。枚举数量不等于全部工具通过。
- Godot get_project_info 读到实际 4.6.3 编辑器和隔离项目路径；Blender get_scene_info 读到默认场景。Blender 版本通过 MCP execute_blender_code 只读查询确认为 4.3.2。
- Godot 通过 MCP 添加 AnimationPlayer，写入 0/1/2 秒三帧位置动画，保存并打开；另一次完全重启编辑器后仍读到中间帧 1 秒 / x=2。运行时两次查询位置变化，实际 MCP 游戏截图已查看。
- Blender 通过 MCP 创建立方体探针，在 1/12/24 帧写 x=0/3/0，保存 .blend，重开后断言关键帧和值正确；MCP 视口截图可见探针。
- 两应用的 GUI、截图与动画往返通过，但没有战斗原型、生产资产或性能验收。此段为最初验收范围；后续已安装官方模板并完成 Windows/Linux 实际导出，结果见上方集成验收。

已知问题必须保留：Blender get_addon_status 返回缺少 `blender_mcp.config`，虽然 isError=false，仍明确记失败；未修改上游代码掩盖该问题。可通过其它已经验证的查询/制作工具工作，不能将所有状态工具或第三方集成宣称为通过。

Godot 上游在新建动画库/编辑器保存时会输出引擎诊断；已通过保存后的独立重开与运行查询核实产物，没有把零退出等同于零诊断。初次运行时节点路径 `/root/Main/...` 不适用于该插件的解析实现，使用相对当前场景的 `World/HeroPlaceholder` 后通过。图形驱动有 Vulkan 探测/V-Sync 告警，实际采用 llvmpipe/OpenGL，软件渲染不代表游戏性能达标。

该入口是按需进程链路：验收完成后服务和 GUI 均清理，下次命令会重连。不存在用户需保留开放的端口或后台授权。

## 本次证据

完整新副本验收共 26 次工作流工具调用，均无协议/应用错误；另外的 `get_addon_status` 已知失败单独保存。证据见 [manifest](validation/mcp/manifest.json)、[Godot MCP 游戏截图](validation/mcp/step-16-get_game_screenshot-0.png) 和 [Blender MCP 视口截图](validation/mcp/step-25-get_viewport_screenshot-0.png)。manifest 对 37 个握手、枚举、调用和图片文件记录 SHA-256。Godot 运行位置从 `(-1.080429, 0.9, 0)` 变为 `(1.654391, 0.9, 0)`，Blender 重开后的第 12 帧 x=3。所有 GUI 和服务进程已结束；依赖保留在项目隔离目录以便下一任务复用。
