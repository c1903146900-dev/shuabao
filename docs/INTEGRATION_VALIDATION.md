# MCP 资产互通与实际导出验收

日期：2026-09-30。验收源代码：`20be58282ad9a9f9ba93c89d11e7a207b6ce1511`。本报告更新此前“模板未安装/导出未运行”的阶段状态。复现命令见 [新云任务复用步骤](CLOUD_REPRO.md)。

| 项目 | 结果 | 实际证据与边界 |
| --- | --- | --- |
| 两套 MCP initialize / tools/list / tools/call | 通过 | 官方 Python MCP SDK 标准 stdio 客户端；不是托管助手原生工具菜单 |
| Blender 骨骼动作 GLB | 通过 | MCP 创建一个骨骼、权重网格、三帧摆动动画 ProbeSwing，保存 blend 并导出 GLB |
| Godot GLB 导入及播放 | 通过 | MCP 导入后读到骨骼和动画；运行中两次 playing=true、时间及骨骼四元数变化 |
| 可见图形 | 通过 | Blender 视口和 Godot 游戏 MCP 截图已检查；软件渲染，不作为性能验收 |
| 干净 clone 复用 | 通过 | 独立安装依赖、18 次 GLB 工作流调用、0 次工具或应用错误，clone 工作树干净 |
| 官方匹配模板 | 通过 | 4.6.3.stable 完整归档 SHA-256 核验后安装 Windows/Linux x86_64 模板 |
| Windows 客户端实际导出 | 通过 | EXE 104659456 字节、PCK 7808 字节，PE x86_64 和 PCK 头核验 |
| Windows 客户端启动 | 未运行 | 当前无 Windows 运行环境，未安装 Wine |
| Linux headless 实际导出及启动 | 通过 | ELF 71075864 字节、PCK 7856 字节；从 /tmp、无显示变量、未传 --headless 启动，输出 SHUABAO_BOOT_OK、退出 0 |
| 专服联机玩法 | 未实现/未验收 | 仅最小 headless 测试包；不是可运行的多人战斗专服 |
| 阿里云连接、部署或公开发布 | 未执行 | 不在本任务授权范围 |

## MCP 资产证据

[GLB 清单](validation/glb/manifest.json) 包含源码提交、18 次调用结果校验值和真实 GLB 校验值。该 GLB 为 4460 字节，1 个 skin、1 个 joint，动画名 ProbeSwing。两次运行采样分别约 0.2544 秒与 0.6923 秒，骨骼旋转从 `(-0.076752, 0, 0, 0.99705)` 变成 `(0.194928, 0, 0, 0.980818)`。这结合导入结果与实际截图证明播放，而非仅有一个动画名称。

逐次 MCP 返回、[Blender 截图](validation/glb/step-02-get_viewport_screenshot-0.png)、[Godot 截图](validation/glb/step-16-get_game_screenshot-0.png) 和小型 [GLB 诊断产物](validation/glb/probe_swing.glb) 均保存于 docs。它们不是正式英雄资产；docs/.gdignore 防止证据进入游戏资源导入。完整临时项目和 blend 保留在本机忽略目录，可用工作流重新生成。

第一次导入曾因资源尚未扫描而失败；修正为源 blend 位于 Godot 项目外，GLB 经编辑器扫描并重导入后实例化。最终干净 clone 运行通过。Blender 缺少可选 Draco 压缩库的警告不影响本次未压缩 GLB；未验收 Draco。上游 get_addon_status 的缺少 blender_mcp.config 问题仍存在，本次没有把所有 36 个 Blender 工具宣称为通过。

## 模板和真实构建证据

模板取自 [Godot 官方 release](https://github.com/godotengine/godot-builds/releases/tag/4.6.3-stable) 的 `Godot_v4.6.3-stable_export_templates.tpz`。完整归档共 1255918323 字节，SHA-256 为 `3fbe2c0e2dec9d537ab9ec97bcf8da91dcf23357fc51f67092dd068d839290a8`，与 [官方资产清单](https://github.com/godotengine/godot-builds/releases/expanded_assets/4.6.3-stable) 匹配。安装位置是项目 `.local/data/godot/export_templates/4.6.3.stable`，不修改全局模板目录。

[导出清单](validation/export/manifest.json) 和同目录实际引擎日志、模板安装回执、文件类型、SHA256SUMS 记录本次结果。构建由 `scripts/export/check.sh` 真正执行两个 `--export-release`，并检查独立 Linux 产物。Linux preset 使用 dedicated_server 特征触发无头模式；没有宣称资源剥离或网络逻辑已实现。Windows 未签名，仅测试包。

当前产物保留在忽略目录 `build/windows` 与 `build/linux`，没有提交百兆二进制、公开 release 或上传服务器。其校验值与日志已经入库，后续可重新构建。下载代理对部分元数据域名返回 403，但官方 GitHub release 直链成功；未修改代理或绕过访问控制。

## 文档整合和下一步

已审阅并合入 docs/prototype-acceptance 的 `ded5c106d5d620b784eed735e4fe73d80f9bc30c`，合并提交 `975d4fc`；保留测试初值、来源与待定标签。没有执行该文档描述的战斗验收。本轮仅修改工具、验证、导出配置和 docs，未改战斗或正式美术资产。

下一步由 combat/art 独立分支通过本 MCP 入口制作，再审阅整合。Windows 实机启动与交互、正式资产契约以及战斗功能需在对应任务验收；不应将本次最小包通过等同于完整游戏通过。
