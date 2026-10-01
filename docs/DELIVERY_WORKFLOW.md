# 测试包与连续窗口录制

仅云环境验证，不部署、不发布 Release、不上传 Library。需要本项目已有 Godot 4.6.3 官方引擎及匹配 Windows/Linux 导出模板；本机模板目录是 `.local/data/godot/export_templates/4.6.3.stable`。MCP 准备与来源见 [MCP_CLIENT.md](MCP_CLIENT.md) 和 [TOOLCHAIN.md](TOOLCHAIN.md)。`scripts/mcp/setup.sh` 仅准备两套 MCP 依赖，不冒称安装引擎或导出模板。

## 最终包复跑顺序

必须先合入待交付代码并提交，记录完整 SHA。以下导出是真正运行 Godot，不使用 MCP export_project 的命令字符串冒充构建。

```sh
cd /workspace/shuabao
# 已有环境先核对；干净环境按 TOOLCHAIN 与 MCP_CLIENT 安装。
godot --version
.local/blender-mcp-venv/bin/python scripts/mcp/check.py --fresh-fixture --workflow scripts/mcp/delivery_regression.json --evidence .local/delivery-regression-final
bash scripts/export/check.sh
python3 scripts/validation/window_play.py
python3 scripts/export/package.py
```

MCP 报告必须解析 failures，不能仅凭工具 isError=false。流程包含两房、药品/装备消费、Enter/Numpad/Tab 和面板输入；受控 103 项药品/属性测试明确区别于实际输入流程。当前表现版复测结果在 `docs/validation/delivery-regression`：12 两房、11 自然成长/药品、10 Enter、5 面板边界全部通过，另 103 受控消费检查通过。修改测试点击辅助是为把逻辑坐标转换为实际窗口坐标；未改玩法。

导出路径：

| 包 | 路径 | 验证范围 |
| --- | --- | --- |
| Windows | `build/windows/shuabao-smoke.exe` + `.pck` | PE/包内容检查；未在 Windows 执行 |
| Linux 无头 | `build/linux/shuabao-headless.x86_64` + `.pck` | 离开源码目录、清除 DISPLAY、不加 --headless，验证 dedicated_server 特征自动选择无头 |
| Linux 窗口 | `build/linux-window/shuabao-client.x86_64` + `.pck` | 私有 Xorg 虚拟显示中的真实窗口、OS 键鼠输入和连续录像 |

Linux 无头包仍是单房间原型的启动验证，**没有实现联机专服**。Windows 不因生成文件就宣称运行通过。

Windows ZIP / Linux TAR.GZ、源码逐文件 SHA256、源码 tree ID、二进制与 PCK 哈希、manifest 和 SHA256SUMS 位于 `build/delivery/<完整SHA>/`。审计原始输出位于 `.local/export-evidence/package-audit.json`，记录每个 PCK 条目的路径、大小和 SHA256。打包脚本拒绝已跟踪文件脏状态、过期审计、审计后二进制修改、与当前 SHA 不一致的录像。

导出资源采用明确清单，并列出全部 15 个动态加载 WAV。排除测试、MCP 插件及工具、文档、预览、Blender 源文件、开发缓存和运行日志。敏感检查针对已跟踪源码及发行包内容做已知格式扫描，不能证明所有形式的秘密绝对不存在；不读取用户凭据或环境变量秘密。

## OS 连续录制

`window_play.py` 默认运行 Linux 桌面导出包，从独立 Xorg `:98` 的 1280×720 窗口连续 x11grab，使用 XTest OS 键鼠事件。它不调用 Godot Input.parse_input_event，不直接修改 HP/金币/冷却，不加载 MCP 插件进入发行包。端口不公开，Xorg 禁用 TCP、使用一次性 Xauthority，结束后清理自建进程与授权文件。

默认输出 `build/window-play/continuous-play.mp4`、`recording.json`、`ffprobe.json`、OS 操作时间表及游戏日志。录制一次连续流，不以截图组成视频。PNG 仅用于人工检查。视频无音轨，不作为音质验收。脚本输入是自动化 OS 输入，不冒称真人手玩。

`--source --output build/window-trial` 可以明确测试源码版，不能替代最终导出包录像。窗口必须已经映射后才接受输入；发布版 stdout 可能缓冲，启动标记在正常关闭后核查，不将启动期未刷出日志误判为失败；ffmpeg 按请求 SIGINT 正常收尾可以返回 255，仍需 ffprobe 验证时长/帧数和实际画面，不能仅看退出码。

## 音频生命周期增量

已审阅合并 `85b14d33b768e1d61560117fc59966dd63e5c02d`（合并提交 `542df134c553ac18de76dff5f08a58033f744b76`），仅 tests/audio 与音频文档，未改生产组件。集成端独立复跑：142 项通过，35 个待回收弱引用在 32ms 后归零；220 次组件循环、20 次场景往返全部通过，对象1486/资源4/节点2/孤儿0/总线1恒定，静态内存与 RSS 增量均为0。日志在 delivery-regression/audio-*.log，未屏蔽退出诊断。有限循环通过不能证明无限运行无泄漏。

原两帧即退出测试早于音频线程回收；原生播放器的对照与 GUI 数据见 AUDIO_PROGRESS.md。硬退出可能仍出现引擎关闭诊断，不能混同为持续运行增长。最终窗口检查在最后操作后保留两秒以上自然播放完成时间，通过 WM_DELETE_WINDOW 正常关闭，要求退出0且完整日志没有 ObjectDB/resource残留。没有修改引擎或在生产组件中阻塞主线程。仍未试听。

## 最终交付记录

本文件提供流程与前置测试证据；实际最终源码 SHA、包哈希和运行结果以最终 delivery manifest 与 DELIVERY_RESULT.md 为准，不把旧 build 当成本次导出。
