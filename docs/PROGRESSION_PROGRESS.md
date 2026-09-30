# 成长 / 商店 / 海克斯交付

基线 `origin/main e6d994d`，独立工作树 `/workspace/shuabao-progression`，分支 `feature/progression`。只提交本任务五个授权目录/文件；不合并 main。已查 `/AGENTS.md`、`/workspace/AGENTS.md`、仓库全部路径，未发现 AGENTS.md；已读 main 设计、计划、决策、状态、MCP_CLIENT、CLOUD_REPRO、风厉规格与 prototype-acceptance。任务最新明确规则覆盖历史未决记录。

## 内容与来源

- `scripts/progression/model.gd`：单角色纯数据事务模型；`command(id, action, args)` → `{accepted, reason, state_revision, events}`，失败原子回滚；同 ID 同参数重放回执，不重复生效，异参数拒绝。`snapshot()` 返回独立副本。
- `data/progression/confirmed_rules.json`：仅确认的技能候选与 R 首阶 6 级，后二阶为 null；不含正式装备/海克斯/XP/药品政策。缺定义返回明确诊断。
- `data/progression/fixture.json`：**全部经济数值、装备、海克斯词条、升级数值为测试夹具**。4 种物品、16 个抽样 ID 不代表完整正式内容。夹具 R 门槛 `[6,6,6]`、每级 XP=100、锻体 50 金币/AD+1、技能 `fixture_numeric_scale` 仅用于测试引擎。真实数值表没有补造。
- 等级授点只能由 XP 跨级产生：1级1点，封顶18；固定成本 P=1/1/1、Q/E各5×1、R=1/2/2。11候选独立学习；升阶只输出数值表，不加入机制分支。`skill_values(slot)` 缺表返回 `unresolved_rank_values`。
- 安全阶段可打开固定完整目录 `shop_catalog()`；6槽含组件/药品。合成先移除指定组件、按实际投入抵价，再检查余额/容量；售出取 `floor(invested*0.9)`。组件缺失拒绝；本引擎不隐式代购缺组件。整堆卖出是示范接口，正式逐瓶出售 UI 未做。
- 同装备数值相加，`equipment_effects().passives` 按同名唯一；锻体固定价重复购买，独立不可逆账本与 `body_effects()`，洗点/交易撤销不退锻体支出。
- 普通药总数≤5；特殊每个稳定 combat_level_id 最多使用2次。重复进入当前关不重置，已访问旧关 ID 拒绝，房间/波次到关的映射交由父任务。使用消耗品清除交易撤销链，防止使用后撤销恢复物品。
- **药品政策显式实验**：`normal_stack=true/false` 对照一堆一槽/一瓶一槽；`mutex=holding/per_level_use` 对照持有互斥/同关使用互斥。未配置或未知政策拒绝。两种都不是最终规则。恢复值/使用时机缺源；消费事件额外输出 `recovery_requested`，缺恢复定义标 unresolved，不直接回血。正式接入应在权威协调层先检查恢复定义和合法时机再提交消耗，不把夹具消费当作真实治疗。
- 海克斯1/4/7/10/13里程碑可分别打开，跳级通过 `pending_milestones` 保留；不强制定弹窗顺序。右槽当前英雄专属，混合槽可为通用/当前英雄；跨未决 offer 的展示、已选项均排除。每槽刷新1次，被替换者本轮排除；见过权重公式 `max(1, floor(base_weight/(1+seen_count)))` 是明确的测试抽样策略，正式降权曲线待定。候选不足原子拒绝，不填重复项。未学对应候选休眠，学习激活，洗点再休眠。
- RNG 为固定31位 LCG，存档保存状态、seen、offers、刷新额度、已选、命令回执。JSON 整数规范化保证续抽与回执重放一致。`save/restore` 是同定义版本的**可信本地 checkpoint**；不宣称已实现不可信存档校验、迁移、磁盘持久化或联机协议。

## 给 UI / 战斗的最小接口

UI 仅读快照与投递玩家意图。权威协调层持有模型实例，每 actor 一份；`reward_minion` 的金币/XP 数量、`context`、`enter_level` 是协调层受信输入，不能直接暴露给客户端/UI。

| 命令 | 关键参数 / 边界 |
| --- | --- |
| reward_minion | event_id, gold≥0, xp≥0；事件去重，不接受 equipment/points 字段 |
| context | phase=safe/combat, training；进入 combat 提交旧投点/交易撤销边界 |
| enter_level | 稳定 combat_level_id；新关重置特殊次数并提交旧投点/交易链 |
| learn | slot=P/Q/E/R, candidate, expected_rank；已学候选不可直接替换 |
| undo_skill / respec | 安全时撤销最新未提交投入；训练点洗全部技能，返实际成本 |
| open_shop / buy / sell / undo_shop | 安全阶段；item 定义ID / uid 实例ID；交易严格 LIFO 撤销 |
| buy_body | 训练阶段；重复购买固定价，不存在 undo_body |
| use_item | uid；返回消耗及恢复请求事件，不写 HP/CD |
| hex_open / hex_refresh / hex_select | milestone；刷新/选择另给 slot=0..3 |

战斗中新增投点保留到下一次进入战斗前，可在安全期撤销。已经越过边界的老技能仅训练洗点重配。模型没有 HP/CD 字段、引用或时间推进，事件无重置生命/CD指令；**这证明模型隔离，不代表已验收战斗端的跨技能CD映射与保留行为**。HP/CD仍须由战斗单一所有者保存，不能依据新技能快照重新初始化。

## 复现

普通确定性测试（不替代 MCP）：

```sh
mkdir -p .local/cache .local/config .local/data
XDG_CACHE_HOME="$PWD/.local/cache" XDG_CONFIG_HOME="$PWD/.local/config" \
XDG_DATA_HOME="$PWD/.local/data" godot --headless --path . --script tests/progression/run.gd
bash scripts/check.sh
```

真实 MCP 使用仓库现有官方 SDK 客户端，未改任何工具、插件、project.godot 或端口权限：

```sh
python3 scripts/mcp/preflight.py
bash scripts/mcp/setup.sh
.local/blender-mcp-venv/bin/python scripts/mcp/check.py --fresh-fixture \
  --workflow scripts/mcp/animation_probe.json --evidence .local/progression-baseline
# 现有客户端只复制 scripts/scenes；给隔离副本补充模型数据与独立测试。
mkdir -p .local/mcp-fixture/data/progression .local/mcp-fixture/tests/progression
cp data/progression/*.json .local/mcp-fixture/data/progression/
cp tests/progression/*.gd .local/mcp-fixture/tests/progression/
.local/blender-mcp-venv/bin/python scripts/mcp/check.py \
  --workflow tests/progression/mcp_demo.json --evidence .local/progression-demo
.local/blender-mcp-venv/bin/python scripts/mcp/check.py \
  --workflow tests/progression/mcp_reopen.json --evidence .local/progression-reopen
```

场景由 MCP create_scene/add_node/attach_script/save_scene 制作，保存重开后通过 MCP play_scene/execute_game_script/get_game_screenshot 运行、读回、截图。仅将审查后的 `scenes/progression/demo.tscn` 与本人脚本 UID 从隔离副本复制回源码。未用直接脚本编辑场景来代替 MCP。示范按 F6 独立运行，不改项目主场景。P 走同一按键处理路径；MCP 使用注入 InputEventKey 测试，不冒称真人物理按键测试。场景为英文诊断面板，正式中文 UI 属于别的任务。

## 验证状态

结果和证据清单在本文件末尾补充。不能将无头模型测试、MCP 场景执行、真实战斗整合混称同一项通过。

已知环境/上游诊断：Godot llvmpipe/OpenGL 的 Vulkan surface / V-Sync 探测告警；MCP 编辑器保存时 progress dialog 诊断；Blender get_addon_status 已知缺少 blender_mcp.config，仍单列失败。首次单测默认用户数据目录不可写造成退出，改用已约定 `.local` XDG 目录后通过。首次示范 MCP 断言没匹配上上游双层编码的字符串，保留失败日志；随后改为布尔语义断言并读取完整快照，未改服务掩盖错误。

最终核验（2026-09-30）：

| 范围 | 结果 / 证据 |
| --- | --- |
| 独立模型测试 | **274 项断言，0失败**；18点守恒/不足拒绝/R门槛、11候选、投点撤销边界、满槽合成/原子失败、重复请求、实际投入90%售价、20轮撤销无套利、药品两种策略/2次上限、锻体不可逆、海克斯去重/额度/权重/休眠、JSON RNG/回执续接 |
| 双 MCP 前置闭环 | 26步骤无应用/协议错误；两服务握手、Godot场景动画保存重开/运行位置变化、Blender关键帧保存重开/截图；[baseline证据](../tests/progression/evidence/baseline/) |
| MCP 成长场景创建 | 24步骤成功；create_scene/add_node/attach_script/save_scene、保存重开、真实场景执行模型套件与命令；[creation证据](../tests/progression/evidence/creation/) |
| 最终源码重新启动编辑器验收 | 20步骤成功；最终274测试在运行场景内执行，P注入安全开启/战斗拒绝，1000→组件100→合成补150=750金币，Q学习余5点，右槽刷新一次/重复拒绝/选择；[完整快照](../tests/progression/evidence/verified/step-15-execute_game_script.json)、[可见截图](../tests/progression/evidence/verified/step-16-get_game_screenshot-0.png) |
| 现有项目检查 | `scripts/check.sh` 退出0、SHUABAO_BOOT_OK；仅导入和骨架启动，非战斗/导出验收 |
| 正式内容、战斗联接 | **未实现/待定**：装备/海克斯全表、R后两档正式等级与数值、药品政策/恢复量/时机、锻体价格属性、XP曲线。未验证战斗端HP/CD冻结与跨候选映射、中文正式UI、真人键盘、多人、存档迁移/损坏校验或性能 |

所有证据与最终源码 SHA-256 见 [manifest](../tests/progression/evidence/manifest.json)。`creation` 保存当时首次成功的布局和模型版本；以 `verified` 的重新启动会话与 manifest 的最终源码哈希为交付依据。截图已人工查看，最终1280×720显示完整测试目录和状态；仅诊断面板，不替代正式 UI 多分辨率验收。Godot/MCP GUI与服务均由现有客户端退出清理。引擎导入产生的无关 `.import` 边文件已清理、不提交美术路径。
