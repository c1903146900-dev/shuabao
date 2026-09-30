# 工具链与接入验收

> 最新接入结果：标准 MCP SDK 客户端已完成两服务握手、工具调用和动画往返，见 [可复用 MCP 客户端](MCP_CLIENT.md)。下文保留此前阶段记录。

> 后续复核：图形入口与部分网络访问已验证可用；MCP 仍待宿主接入。最新证据见 [MCP 与图形接入复核](MCP_HANDOFF.md)。以下保留初始化阶段的历史结果。

检查日期：2026-09-30；环境 Debian GNU/Linux 13，项目路径 `/workspace/shuabao`。

## 实际安装与来源

| 组件 | 实际结果 | 来源与许可 |
| --- | --- | --- |
| Godot | 已有 4.6.3.stable.official.7d41c59c4；导入和无头运行通过 | `/usr/local/bin/godot` 指向 `/opt/godot/4.6.3/Godot_v4.6.3-stable_linux.x86_64`；[官方 4.6.3 页面](https://godotengine.org/download/archive/4.6.3-stable/)，[MIT](https://godotengine.org/license/) |
| 导出模板 | 已检查的用户与系统位置未发现；未安装、未验证 | 必须与引擎匹配 4.6.3；后续从官方来源取得并核验 |
| Blender | 已有 4.3.2，Debian 包 `4.3.2+dfsg-2`；后台运行通过 | `/usr/bin/blender`；本地 `/usr/share/doc/blender/copyright` 标明主要源码 GPL-2+，依赖另有声明 |
| Godot MCP | 未安装、未接通 | [mkdevkit/godot-mcp](https://github.com/mkdevkit/godot-mcp)，上游 MIT |
| Blender MCP | 未安装、未接通 | [ahujasid/mcp-for-blender](https://github.com/ahujasid/mcp-for-blender)，上游 MIT；当前上游包名 mcp-for-blender |
| game-ui-ux / game-feel | 已通过网页读取主 SKILL.md；未持久安装 | [指定技能仓库](https://github.com/gamedev-skills/awesome-gamedev-agent-skills)，Apache-2.0；不安装整包 |

Godot 版本字符串标记 official，但本环境没有安装收据，尚未与官方校验和对比。实测文件 SHA-256：`f64d4ed19fc9df9440321653fcc80df8c6e365ba7b6de0a29e2cfa9fa71bfeb3`。不将该值误称为已验证的供应链证明。没有重新安装已经存在的软件。

## 网络和平台边界

- 对目标仓库的 `git ls-remote origin` 成功，初始无任何 refs。
- shell 访问 GitHub API、raw.githubusercontent.com、Library 签名传输地址均收到代理 `Tunnel connection failed: 403 Forbidden`。网页读取可用，但这不证明依赖下载可用；未尝试绕过代理。
- 当前 cloud/executor 技能目录均为空，项目和 `/workspace/.agents` 没有已有技能或 AGENTS.md。Library 当前只暴露工具说明，没有可读取的 Library 技能；按 `prepare_materialize` 的签名传输指南执行。
- `codex mcp list` 返回没有已配置服务器。当前助手的工具目录没有 Godot、Blender 或动态注册任意本地 MCP 的能力。
- CLI 的 `codex mcp add` 是客户端配置命令；本任务没有证据证明修改它能给当前会话暴露工具。不能据此宣布已连接，也未修改用户级持久配置。
- `DISPLAY` 未设置，未发现 `Xvfb`/`xvfb-run`，存在 Xorg 但没有已连接显示会话。本次不启动桌面、安装显示服务或开放端口。

## 真正支持的上游连接方式与待验收

Godot 上游是 MCP 客户端 → stdio Node 服务 → WebSocket（默认 6505）→ Godot 编辑器插件。Blender 上游需要 MCP 客户端运行其服务，并连接运行中 Blender 的插件。必须先由任务平台提供受支持的本地 MCP 挂载方式；普通磁盘安装不会自动改变助手工具列表。安装与持久访问需按平台要求确认，当前没有为了验证而安装闲置插件。

后续验收必须记录真实 MCP 工具调用：查询运行应用；创建/保存/重开最小场景；添加动画并读取关键帧；实际运行和取得可见画面。Blender `-b` 只验证二进制，不能代替 GUI 插件命令循环。Godot MCP 导出工具可能只生成命令，真正导出必须运行引擎并检查输出文件及可执行启动。

本次没有 MCP 场景/动画往返、可见运行、客户端导出或专服构建。不得把本仓 CLI 检查脚本称作这些验证的替代品。

## 技能应用边界

本次骨架按 [game-ui-ux](https://github.com/gamedev-skills/awesome-gamedev-agent-skills/blob/main/skills/disciplines/game-ui-ux/SKILL.md) 使用容器、缩放和键盘初始焦点；实际多分辨率视觉检查未运行。后续按 [game-feel](https://github.com/gamedev-skills/awesome-gamedev-agent-skills/blob/main/skills/disciplines/game-feel/SKILL.md) 将反馈与模拟分离。本次没有实现战斗反馈，不适用其完整玩法验收。上游代码示例标注 Godot 4.7，后续实现需在 4.6.3 实测。
