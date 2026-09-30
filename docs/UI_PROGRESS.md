# 风厉 HUD：独立集成交付

分支 `feature/combat-ui`，从 `abb91cf` 分出。仅拥有 `scripts/ui`、`scenes/ui`、`assets/ui`、`tests/ui` 与本文；不改 main、project.godot、战斗代码或正式模型。后续成长任务 `feature/progression` 独占底层，本组件不替代它。

## 交付与运行

- `scenes/ui/combat_hud.tscn`：可实例化到任意 CanvasLayer 的 HUD。
- `scenes/ui/hud_demo.tscn`：独立 3D 几何背景与 UI 交互夹具。所有生命、技能、冷却、XP、金币、房间和奖励都是**演示数据**，未连接真实战斗。
- `scripts/ui/hud_adapter.gd`：输入快照、输出请求、消费反馈的窄接口。
- 不需要修改主场景：Godot 编辑器打开 demo 按 F6；或者 `godot --path . res://scenes/ui/hud_demo.tscn`。
- 键鼠：K 开关修习，Esc 关闭；Tab/Shift+Tab 切焦点，Enter/Space 按钮，选项框方向键；Q/E/R/Shift 发演示技能请求，左键空地展示伤害字，F8 演示结算，F9 重置夹具；F10 清空演示配装以查看并选择11个初学候选。

HUD 有 HP/等级/XP、Q/E/R/Shift/被动等级与 CD/不可用原因、18 点修习、6 装备槽（含药品）、金币、房间/波次、伤害字、技能/拒绝提示、结束结算。初学候选 Q3/E3/R2/P3；升级不显示机制分支。R 成本 1/2/2，其余每档 1，阶数 Q5/E5/R3/P3。全满 18 点。每槽允许外部传 rank=0，未学时可选择候选。

不实现商店、奖励结算、药品堆叠、锻体、海克斯、成长持久化或网络协议。演示初始 18级，5点已投入、13点剩余；演示升级仅用于按钮信号与展示验收，R 后两阶在夹具中无额外门槛，**不是已确定玩法**。真实系统通过 `upgrade_reason` 阻止尚不可分配的阶级。演示所有主动技能成功后暂用5秒反馈CD，非风厉平衡数据。

## 父任务最低接入 API

实例化后调用（不替换 adapter 实例）：

```gdscript
var hud = preload("res://scenes/ui/combat_hud.tscn").instantiate()
$CanvasLayer.add_child(hud)
hud.adapter.request_emitted.connect(_on_ui_request)
hud.adapter.present(snapshot)
hud.adapter.feedback({"kind": "damage", "text": "128", "critical": false,
    "screen_x": 640.0, "screen_y": 320.0})
hud.adapter.feedback({"kind": "skill", "text": "超载已开启"})
hud.show_result({"title": "战斗完成", "kills": 36, "gold": 240, "xp": 180,
    "source_label": "实际本场结算"})
```

`present(Dictionary)` 全量快照深拷贝。无内置计时、扣点、治疗或冷却推进。每次权威更新调用即可；纯冷却显示可按 10–20Hz 更新。`feedback` 不反写模拟；屏幕坐标是 HUD 逻辑画布坐标，世界事件由接入方经 Camera 投影后转换。`show_result` 不改游戏阶段、不授予奖励。

| 快照字段 | 类型/意义 |
| --- | --- |
| actor_id / revision | String / int，人物标识与状态版本 |
| level / points | int，1–18 与剩余可花点，均以成长模型为准 |
| hp / hp_max / xp / xp_next / gold | 数值；XP 为本级进度，不是累计总 XP |
| room / wave / source_label | 显示字符串；真实接入请明确来源 |
| can_undo | bool，由下一场前撤销规则判定 |
| skills | 按 Q/E/R/Shift/P 索引的 Dictionary |
| 每个 skill | name, rank, candidate_index（0起）, cooldown（剩余秒）, reason（施放不可用原因）, description, upgrade_reason（非空禁用修习） |
| equipment | 最多6个 Dictionary：name / description；缺项显示空槽 |

所有请求经 `request_emitted(Dictionary)`，公共字段 `action / actor_id / command_id / state_revision`。动作：

- `ability` + `slot_id`：转换成 Combat.request_action；权威失败原因用 feedback 回传。
- `learn` + `slot_id / candidate_id / expected_rank`：candidate_id 如 Q1/E3/R2/P3；转换成 Progression.learn。前端只作提示性门槛，后端再次验证预算、等级、幂等与候选。
- `undo_new_points`：成长模型审查阶段与新点账本；不要重置 HP/CD。
- `item` + `slot_index`（0–5）：接入装备/物品详情或使用流程，UI 不决定药品规则。

**输入必须接入**：战斗攻击使用 `_unhandled_input`，让 Control 先消费鼠标。若现有战斗通过 `_input` 或 `Input.is_mouse_button_pressed` 轮询，必须额外调用 `hud.blocks_gameplay_input()` 屏蔽 UI/模态面板；GUI 无法撤回已经执行的攻击。修习不设置 SceneTree.paused。键盘技能应在模态面板可见时抑制，移动是否保留由输入层决定。HUD 暂以 K/Esc 键处理菜单，不修改项目 InputMap；战斗键映射仅在 demo。

`docs/prototype-acceptance` 的 CombatEvent/Snapshot 仍为建议契约，这里提供可执行适配边界。成长分支实现完成后需映射字段，不在 UI 偷建另一套权威系统。

## 来源与资产

本次实际检查工作区/仓库：无 AGENTS.md、无 `.agents/skills` 的 game-ui-ux/game-feel；没有下载技能包。采用 Godot 官方 [InputEvent](https://docs.godotengine.org/en/stable/tutorials/inputs/inputevent.html) 的 GUI 先于 unhandled gameplay 输入，以及 [Containers](https://docs.godotengine.org/en/stable/tutorials/ui/gui_containers.html) 的容器布局建议。反馈与模拟分离。

背景几何、面板、颜色、排版均代码自制；没有外部图标、付费资产。为中国 Windows 可移植中文显示，携带本机 Noto Sans CJK 的 SC 字体面，未依赖 Windows 安装字体。原始来源 Debian fonts-noto-cjk 包，SIL OFL 1.1 许可全文及声明见 `assets/ui/FONT_LICENSE.txt`；字体不是声称自制的美术。

## 验证复现

依赖与版本沿用 `docs/CLOUD_REPRO.md`。只使用项目隔离 `.local` 安装两个既定 MCP 和官方 Python SDK，无常驻服务、用户级配置或外网端口。

```sh
bash scripts/mcp/setup.sh
python3 tests/ui/prepare_fixture.py
.local/blender-mcp-venv/bin/python scripts/mcp/check.py \
  --workflow tests/ui/build_workflow.json --evidence .local/ui-build
.local/blender-mcp-venv/bin/python scripts/mcp/check.py \
  --workflow tests/ui/verify_workflow.json --evidence .local/ui-verify
```

prepare_fixture 会归档旧 fixture，额外复制 assets 和测试代码，并仅在隔离副本的编辑器元数据中关闭嵌入运行（否则编辑器强制改变窗口大小）；不要随后加 check.py 的 `--fresh-fixture`，其通用复制列表没有 assets/tests。构建工作流真实通过 MCP 创建两个场景、附加脚本、保存、启动和截图；已检查后将两个 .tscn 保存回本分支。脚本常规文件编辑，不冒称全部 GDScript 文本均由 MCP 生成。

## 尚未验收

真实战斗输入层的防穿透、真实成长预算/撤销与R门槛、真实伤害/技能事件、战后冻结/死亡结算、装备药品、联机、Windows实际启动、DPI/超宽屏、屏幕阅读器、性能与导出包：均未测。演示通过不能代替这些集成验收。本分支无需战斗/成长代码即可运行；集成必须重新执行对应游戏验收。

## 实际成长 API 对齐记录（下一阶段接线，非已集成）

本阶段收尾已直接读取 `feature/progression` 提交 `607bf6385f5f668155aa76f5df6eb184e5685cea` 的 `docs/PROGRESSION_PROGRESS.md`、`scripts/progression/model.gd` 与 `confirmed_rules.json`。遵从父任务最新要求，先提交独立可验收 UI；**本提交没有加载或调用该成长模型**，下列是依据实际代码的接线映射，不冒称真实联通。

| UI 当前边界 | 实际成长接口 / 下一阶段动作 |
| --- | --- |
| learn(slot_id, candidate_id, expected_rank) | `model.command(command_id, "learn", {"slot": slot_id, "candidate": candidate_id, "expected_rank": expected_rank})`；P/Q/E/R与候选ID一致 |
| undo_new_points | 实际动作 `undo_skill` **每次仅撤销最新一笔**，需要把正式按钮改成“撤销上次投入”；当前 fixture 演示恢复本轮全部投入，不可直接当作模型同义动作，禁止静默批量循环调用 |
| actor_id / revision / level / points / xp / gold | `model.snapshot()` 同名字段可直接映射；state_revision 是 command 回执字段，快照字段是 revision |
| skills[slot].candidate_index / name / rank | 快照是 `{candidate, rank}`，候选字符串如 Q2 需用定义目录映射显示名和索引；不要把中文名发给模型 |
| can_undo | `phase == "safe" and not allocations.is_empty()` 为显示条件；模型仍权威检查 `unsafe_phase / undo_boundary` |
| upgrade_reason | 将 `unresolved_r_gate / insufficient_points / level_gate / rank_cap / training_required / stale_rank` 译成中文；confirmed_rules 后两阶 null，须显示“R后两阶门槛待定”，不沿用夹具[6,6,6]作为正式规则 |
| equipment[0..5] / item(slot_index) | 实际快照为 inventory 实例数组，使用/卖出按实例 uid；需要保存槽→uid映射与定义显示名。当前 item 请求是查看/交互入口，不能把 slot_index 直接当 uid 或一键使用药品 |
| xp_next / HP / CD / room / wave / source_label | xp_next 必须来自实际定义/显示元数据；HP/CD/房间波次来自战斗快照，成长模型不含这些字段。来源标签需按真实/fixture设置 |

协调层持有每 actor 的模型，把 `command()` 回执的 accepted/reason/events 交给 UI，再用最新 snapshot 重绘。UI 不调用 reward_minion/context/enter_level，不把可伪造的客户端信息变成奖励或阶段权限；药品 recovery_requested 只交战斗协调层审核处理。正式集成验收尤其要检查真实 LIFO 撤销、HP/CD不重建、未定 R 门槛与槽→uid映射。

## 本阶段最终验收（2026-09-30）

- **真实 MCP**：两服务 initialize/tools/list 成功，Godot 173 工具；`build-fixed` 记录两场景 create_scene/attach_script/save_scene 与运行，`acceptance` 独立重启编辑器后24步调用全部无协议/应用错误。不是仅 CLI 验证，也没有把工具数量当全部通过。
- **29项 × 2分辨率 = 58项检查，0失败**：实际窗口分别1920×1080、960×540；快照深拷贝、反馈不改HP、空地点击/UI防穿透、面板遮罩、K/Esc/Tab/Enter/下方向键、12次开关、结算焦点、战斗时钟继续、点数不足/R6级限制、18点满配、11候选、6槽药品、结束冻结、旧配装和新学习撤销展示等。报告：[test_report.json](../tests/ui/evidence/acceptance/test_report.json)。以上时钟/冻结/投点是 UI fixture 验证，真实战斗/成长未测。
- **6张真实尺寸截图**，尺寸清单：[screenshots.json](../tests/ui/evidence/acceptance/screenshots.json)。已检查中文显示、边缘截断、按钮/文本重叠与对比；960×540下主状态和操作可读，辅助说明较小，未来无障碍字号缩放仍需专项设计。面板有意遮住并暗化下方HUD，游戏继续运行。
- 1080p：[HUD](../tests/ui/evidence/acceptance/step-07-get_game_screenshot-0.png)、[修习](../tests/ui/evidence/acceptance/step-09-get_game_screenshot-0.png)、[结算](../tests/ui/evidence/acceptance/step-11-get_game_screenshot-0.png)。960×540：[HUD](../tests/ui/evidence/acceptance/step-17-get_game_screenshot-0.png)、[修习](../tests/ui/evidence/acceptance/step-19-get_game_screenshot-0.png)、[结算](../tests/ui/evidence/acceptance/step-21-get_game_screenshot-0.png)。伤害字/技能提示经动态输入验证；未专门保存短暂反馈的截图。
- **独立源码启动**：无需 MCP 插件，`godot --headless --path . res://scenes/ui/hud_demo.tscn --quit-after 90` 退出0、无脚本错误，日志 [standalone.log.gz](../tests/ui/evidence/standalone.log.gz)。正式源码与 MCP 最终 fixture 的三个GDScript、两个场景、字体及测试脚本已逐文件比对一致。
- Godot MCP `get_editor_errors` 返回0；原始引擎日志仍有 llvmpipe 环境 Vulkan surface/V-Sync/音频回退诊断，不能宣称整个日志零告警。Blender `get_addon_status` 的已知上游缺模块失败单独保留，UI任务未使用其资产制作功能。
- 修复过程：初版锚点偏移导致部分HUD屏外；首次脚本类型推断错误已修；测试输入曾未转换缩放坐标导致2项假失败；编辑器嵌入窗口曾覆盖尺寸请求，最终改为隔离副本项目元数据禁用嵌入，再核实PNG实际尺寸。未把失败的早期图当最终验收。`build-fixed`仅是早期MCP场景构建证据，最终布局以 `acceptance` 为准。
- 最终源码和证据 SHA-256：[manifest.json](../tests/ui/evidence/manifest.json)。所有当次 GUI/MCP 进程由标准客户端清理。分支只交付独立 UI，可供父任务审阅/挑选；尚未合入 main。

环境清理补记：Xorg dummy 显示在客户端结束会话的清理阶段出现 TimerFree/ddxGiveUp 段错误；发生于最终截图/工具调用之后，原始日志以 .log.gz 无损保留。此项是显示服务退出诊断，不宣称已修复。GUI/服务进程已退出。
