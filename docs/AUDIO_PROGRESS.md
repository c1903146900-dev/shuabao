# 战斗音效交接

分支 `feature/combat-audio`，实际环境快照基线 `a3dd6b4`（本地无法解析任务中提到的短 SHA `15e694`，没有据此重置或改动 main）。只交付 `assets/audio`、`scripts/audio`、`scenes/audio`、`tests/audio` 与本文；不接主场景/战斗/UI，不合 main，不导出部署。

15 个原创合成 WAV、13 个事件 ID；32 kHz / PCM16 / mono，合计 348,180 bytes，170–965 ms。波形与音高包络、窄带气流、低频冲击、泛音及短音程分层生成；无下载音源、录音、音乐、语音、付费工具或新增 DAW/插件。`scripts/audio/synthesize.py` 是可编辑源配方，Python 标准库即可重建。项目内可继续修改/使用这些本任务原创资产，没有外部采样归属要求。

## 一页 ID / 触发时点映射

这里只是后续宿主接入合同，**尚未连接真实战斗事件**。以下事件名只读核对当前 `combat_sim.gd`；不要由按键按下或动画播放反推伤害。

| API ID（文件） | demo 键 | 后续宿主触发时点 | 合成区分 |
|---|---|---|---|
| `sword`（`sword_1/2/3.wav`） | 1 | `attack_started`，每次接受的普攻一次，空挥也有 | 短气流与下降音高，三种长度/滤波变体 |
| `hit` | 2 | `damage` 普通命中反馈，按 cast/target 去重 | 短中低频敲击 |
| `hit_heavy` | 3 | `damage.critical` 或宿主明确重命中，替代 hit | 更低、更长的冲击 |
| `dash` | 4 | `dash`，成功冲刺开始 | 低中心频率气流 |
| `hurt` | 5 | `hero_damaged` 且 amount > 0 | 双音下降、短不协和 |
| `enemy_die` | 6 | `kill`，目标第一次死亡确认 | 下坠音高与低频消散 |
| `q_thrust` | Q | `q1` 的实际突刺；其它 Q 候选由宿主另行定义 | 更亮、更快的尖端瞬态 |
| `e_overload` | E | `overload_started`，每次启动一次，续时不重播 | 上升音高后短和声音程 |
| `r_slam` | R | `ultimate_impact`，每次重击一次，不按多目标伤害重复 | 低频主体与长于普攻的余振 |
| `ui_confirm` | C | 有效 UI 操作/事务成功确认 | 上行双音 |
| `ui_reject` | X | 明确拒绝且需反馈的用户操作 | 下行低双音 |
| `level_up` | L | 成长模型等级实际增加后一次 | 四音上行 |
| `settlement` | V | 成功结算页面首次呈现/事务完成一次 | 两段短和声收束 |

同一刀的 E3 额外真伤不要再发第二个 hit；AOE 同帧命中聚合后播放，R 已播重击时避免每目标重复重击。宿主按 `combat_level_id + sequence` 去重；组件仅做时间节流，不持有战斗事件身份。所有声音都可丢弃，不能作为伤害、输入、奖励或进度的前置条件。

## 接入与独立 demo

```gdscript
var audio = preload("res://scenes/audio/combat_audio.tscn").instantiate()
add_child(audio) # 单个本地呈现宿主一份，不给每个敌人创建一份
var accepted: bool = audio.play_event("sword")
audio.set_volume_db(-3.0) # clamp [-60, 0] dB
audio.set_muted(true) # 立即停止已有声音；后续事件返回 false
```

`CombatAudio` 使用 8 个非空间 `AudioStreamPlayer` 与实例独立总线，send 到 Master；不修改 Master、autoload、InputMap 或 project.godot。每 ID 最多 2 声，40 ms 最小间隔，总体 8 声；满池丢弃新声，不截断已有瞬态。战斗 pitch ±2.5%（可调至最大 ±4%），剑挥不连续选同一变体；UI/升级/结算保持调律。每播放器固定 −14 dB 余量，加默认总线 −3 dB；设置总线为 0 dB 时八声最坏同相 PCM 峰值估算仍约 −2.94 dBFS。该预算只覆盖**一份组件的这些源 WAV**，宿主其它音轨和额外组件不在预算内。

`stop_all()` 清除声音与节流历史；`snapshot()` 返回真实 playing、position、stream、pitch、bus 和活跃数量。销毁组件会移除自己的总线。静音/Dummy 音频不影响任何游戏逻辑；服务器可完全不实例化。

```sh
godot --path . scenes/audio/audio_demo.tscn
# 鼠标按钮或上表按键；M 静音；- / = 每次调整 3 dB
python3 scripts/audio/synthesize.py
bash tests/audio/run.sh
```

## 验证与准确边界

**未试听**，没有主观听觉验证，不能声称“听起来好”或已完成实机混音验收。云端真实 Godot 播放使用 Dummy，验证的是导入、播放器状态/时钟和输入。波形已视觉检查；[`signal-review.json`](../tests/audio/evidence/signal-review.json) 与 [`waveforms.svg`](../tests/audio/evidence/waveforms.svg) 保存每文件峰值、RMS、10 ms 包络、SHA-256、起音和静音尾巴。FFmpeg 测过采样 true peak；短瞬态 LUFS 会因门限窗口返回 `-inf`，不将它当音量达标指标。

数值结果：零削波样本、零首尾样本；峰值 −10 至 −7 dBFS、整段 RMS −25.74 至 −20.06 dBFS；−60 dB 门限起音 0.25–0.344 ms，尾段 3.75–19.813 ms。无初始长静音、削平峰顶或长静音尾巴。上述是基础信号检查，不能替代听感、扬声器/耳机兼容和游戏内遮蔽测试。

本地独立 Godot 测试 142 项断言覆盖全部 ID 导入/播放/结束回收、播放时钟、单 ID 双声上限、八声上限、静音与恢复、增益钳制、实例总线隔离/清理和剑挥不连续重复。见 `tests/audio/evidence/runtime.log`。Dummy 快速 stop/free 的退出日志存在 AudioStreamPlaybackWAV 资源残留诊断，断言通过不代表退出零诊断；不隐去此限制。首次未设置 XDG 路径的启动失败已改用仓库 `.local` 隔离路径。

真实 MCP 复现：先按 `docs/CLOUD_REPRO.md` 运行 preflight/setup；以下两会话顺序执行，禁止抢占已有 :97/6505/9876。客户端 SDK initialize → tools/list → tools/call → GUI 插件，不直连应用端口。先写入脚本、创建并保存场景、设置 WAV 禁归一化/禁循环/PCM16/mono 并真实重导入，再完全重启编辑器复查资源和运行。中间脚本表达式/类型推导错误保留于诊断回执，不能据此声称第一次全通过。

```sh
python3 tests/audio/mcp_workflow.py build --out .local/audio-build.json
.local/blender-mcp-venv/bin/python scripts/mcp/check.py --fresh-fixture \
  --workflow .local/audio-build.json --evidence .local/audio-build-proof
python3 tests/audio/mcp_workflow.py verify --out .local/audio-verify.json
.local/blender-mcp-venv/bin/python scripts/mcp/check.py \
  --workflow .local/audio-verify.json --evidence .local/audio-verify-proof
```

真实 MCP 最终通过 23 次制作调用与 26 次独立重启验收调用：15 个资源导入、13 个事件逐一播放、并发/静音设置、播放位置推进至 0.188 秒后自然归零、原生 E 键输入，共 16 组运行检查。最终脚本解析/运行错误为零；图形环境 Vulkan/V-Sync/XServer 退出诊断及上游 Blender addon status 缺 config 仍保留。见 [`verified-summary.json`](../tests/audio/evidence/mcp-verify/verified-summary.json)、[`实际 demo 截图`](../tests/audio/evidence/mcp-verify/step-24-get_game_screenshot-0.png) 与 [`manifest`](../tests/audio/evidence/manifest.json)。校验：`python3 tests/audio/verify_mcp.py tests/audio/evidence/mcp-verify`。

后续主集成须接实际事件并进行真人试听；本分支没有背景音乐、语音、3D 距离衰减、网络传声、性能/实机混音或平台导出验证。预览与证据只留既有仓库，没有上传 Library 或外部目的地。
