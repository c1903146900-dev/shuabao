# 风厉单人战斗原型交接

2026-09-30，分支 `feature/fengli-combat`，基线 `d7d1161`。首个 Q1/E3/R1/P3 可运行阶段已单独推送 **07dd35e**；后续提交扩展候选与验收。只改任务授权目录；没有改 main、project.godot、主入口、工具目录、UI任务目录或美术资产。

## 立即运行

```sh
godot --path . scenes/combat/fengli_arena.tscn
# 或在 Godot 4.6.3 打开该场景，按编辑器 F6。
bash tests/combat/run.sh
```

- WASD移动、鼠标朝向、左键长剑普攻（可按住）、Shift冲刺、Q/E/R技能。
- 默认 **Q1/E3/R1/P3**；游戏窗口内 F6 明确开始全新测试局并循环另外两组：Q2/E1/R2/P1、Q3/E2/R1/P2。不是免费战中洗点。
- F5开始同组合的新测试局；H隐藏临时HUD；首次倒地按空格使用本局一次自救。
- 独立测试房：8普通怪、2精英、1测试Boss。普通/精英锁定地面圆预警，Boss交替扇形与圆攻击；受击、击退、死亡和结算可见。11敌允许P3初档在一次完整清房中增长1AD。
- 本场景预置**6级、四槽各1阶、剩2点**，仅用于立即测试R。不是正式新角色等级、奖励或XP流程。

## 验收与证据

当前核心/集成232、扩展技能71、战斗配装夹具61，共 **364项机制断言**；另 **11项MCP原生输入事件断言**。最终通过结果以 `tests/combat/evidence/release-input/` 和 `release-demo/` 的回执、manifest为准。早期 `core-stage/` 是07dd35e的104项历史检查，不把旧截图称作最新版本。

覆盖内容：

- 11候选逐一只学自己槽位、其他槽为空仍可用；18点守恒、R成本1/2/2、R6级首学、升级纯数值、失败原子拒绝。
- Q1几何/去重/退款/最多4层/多杀限次/其他攻击助攻不刷新；Q2最多4个不同目标、死目标和越界重验、全段免伤不可选中；Q3伤害/矩形/击退与Boss硬直。
- E1追踪、二段、5秒过期/目标死亡；E2单圈移动/距离限制/有敌落点无敌；E3各基础效果、真伤、击杀续时、结束计CD、粗细帧一致。
- P1仅普攻吸血；P2非致命阈值、恰好10%、低到低、直接致命不触发、活动E3不重复/结束免一次CD；P3三档10/7/5阈值、本局增量和计数余数。
- R1巨大圆、严格低于5%、Boss斩杀、演出免伤/单层慢速；R2首1/第二3/第三4根累计实例、201根不封顶、Boss完整0.25%比例、减速刷新、3秒窗口边界、三投/超时结束计CD。
- 防御/穿甲、普攻175%测试暴击、技能不默认暴击、真伤、范围吸血、65%CDR/2.5攻速/100%韧性；不可选中不自动挡范围伤害。
- 60秒战后HP/CD和保留状态不变、最后击杀归因先结算、死亡事务后不继续改敌人、跨房不继承上一帧未消耗时间、无敌来源互不覆盖、重入输入拒绝。
- 真死亡经验进度测试夹具100→70、一次自救、重复死亡不重复罚；正式XP结算由成长协调层接管。
- MCP原生输入：W/A/S/D各方向、鼠标朝向、左键伤害、Shift位移且不伤害、Q伤害/CD、E持续状态、R伤害/演出、F6组合切换。是运行中Godot输入事件，不冒称真人物理键盘/手感测试。

已修复且有回归：浮点计时恰好到零、最后一击后多回血一帧、封房后敌人继续改状态、R完成过早扣CD、E3过期跨帧伤害不一致、R2完成信号先于计数、跨房残留帧预算、失败请求改面向、被动被当主动、R1清除E2剩余无敌、失效E1拒绝请求改CD，以及旧候选保留状态与新候选并存。

短演示 `tests/combat/evidence/fengli-demo.mp4`：97张真实MCP游戏截图，测试时钟每次推进0.125秒，按8fps合成。**这是定时采样演示，不是实时屏幕录像或性能证据**。最终截图含普通战斗、Boss预警、R1、E1标记、R2及结算；结算画面是明确的验收夹具，不冒称视频中的玩家已经击杀Boss。

## MCP复现

已读 docs/MCP_CLIENT.md 和 main abb91cf 的 CLOUD_REPRO.md。本环境按固定源码安装并真实运行：官方Python MCP SDK → stdio initialize/tools/list/tools/call → GUI插件；Godot173/Blender36工具枚举和两应用查询成功。所有游戏GDScript写入、独立场景创建/挂载/保存、运行及截图通过MCP完成，再将核对后的授权文件从隔离副本复制回仓库。

```sh
bash scripts/mcp/setup.sh
python tests/combat/mcp_workflows.py build --out .local/combat-build.json
.local/blender-mcp-venv/bin/python scripts/mcp/check.py --fresh-fixture \
  --workflow .local/combat-build.json --evidence .local/combat-build-proof
# 独立重启后验证，不依赖编辑器热重载缓存。
python tests/combat/mcp_workflows.py input --out .local/combat-input.json
.local/blender-mcp-venv/bin/python scripts/mcp/check.py \
  --workflow .local/combat-input.json --evidence .local/combat-input-proof
python tests/combat/verify_mcp_evidence.py .local/combat-input-proof --expect-input
python tests/combat/mcp_workflows.py demo --out .local/combat-demo.json
.local/blender-mcp-venv/bin/python scripts/mcp/check.py \
  --workflow .local/combat-demo.json --evidence .local/combat-demo-proof
```

上游输入缺陷已实测保留：`simulate_key/mouse` 返回queued，但编辑器`/root/MCPInputBridge`为null，实际无输入；运行中的桥存在。键鼠移动改为MCP `execute_game_script`调用**运行中**桥的queue_events。上游mouse_click还复用同一InputEvent立即改pressed=false，累积输入只看到释放；验收harness通过同一MCP工具分别创建/投递新的按下与释放InputEventMouseButton，走真实Godot输入分发，不直接调用攻击函数。失败与修复回执见 `evidence/input-tool-diagnostic/`。

Godot软件渲染的Vulkan/V-Sync/音频/退出XServer诊断、编辑器保存进度队列诊断及Blender addon status缺config仍如实保留；没有改上游工具掩盖。曾发生父目录缺失创建场景失败和编辑器热重载旧基类诊断；重建目录、独立重启后复查。最终运行脚本解析与断言结果另查最终日志，不能仅依据工具isError=false。

## 模块与接入边界

| 所有者/入口 | 契约 |
|---|---|
| `CombatSimulation` | `request_action(action, aim, command_id)`返回accepted/reason/cast_id/state_revision；动作仅attack/shift/q/e/r，同command_id不重复执行。信号回调期间拒绝重入施法，需延后投递。 |
| 时钟/生命周期 | `step(real_delta)`以5ms固定tick推进模型；`end_encounter(result)`原子冻结；`begin_encounter(next_id, roster)`在存活/非战斗阶段恢复，保持HP/CD，新的稳定combat_level_id由宿主指定，不擅定房/波/关映射。 |
| 只读观测 | `snapshot()`深拷贝；`combat_event`、`state_changed`、`encounter_finished`。事件含sequence/combat_level_id/world_time；伤害含source/cast_id/target/ordinary或true。禁止UI直接改hero/enemies内部字段。 |
| 角色属性/状态 | hero.stats仅12项基础属性；本局P3增量单列permanent_ad，HP/CD由战斗唯一持有。装备百分比叠算、恢复定义与奖励数值没有实现，不用重新new角色的方式应用成长快照。 |
| 成长适配 | `scripts/combat/loadout_fixture.gd`是**可替换测试夹具**，不是正式成长系统；`learn_ability/undo_new_investment/reset_at_training`演示应用槽位而保留HP/CD。正式模型属feature/progression；已只读其607bf638文档。没有写scripts/progression/data/progression/tests/progression/scenes/progression。 |
| 奖励/死亡 | kill事件提供敌人ID、source/cast_id和本单人致死credit；宿主可将唯一死亡事件映射到成长`reward_minion(event_id,gold,xp)`。战斗不掉装备、不发点、不定金币/XP数量；hero.xp_progress仅死亡测试夹具，正式进度由成长所有者结算，避免双扣。 |
| 恢复 | 成长`use_item`返回恢复请求，不自动治疗。需要宿主先校验正式恢复定义、时机、冻结例外后协调消耗与战斗HP事务；本分支未实现药品恢复或商店。 |
| 美术 | arena导出hero_visual/minion_visual/elite_visual/boss_visual可选PackedScene；actor_view有`Visual`及递归AnimationPlayer发现/`set_visual_scene`。+Y向上、-Z向前、脚底原点，无root motion。动作映射idle/run/attack/dash/thrust/overload/ultimate/hit/death；伤害不读动画姿态。 |
| UI | 临时HUD完全在scripts/combat内，只消费快照。正式UI可替换整个CanvasLayer，不影响模拟。 |

已读美术9fea8df的ART_PROGRESS并预留导出资源入口，**本分支没有导入/修改正式模型，也没有宣称战斗动画与正式骨骼已整合验收**。主任务统一接入。新增成长系统的R后两档正式门槛/数值应由其已批准定义决定；战斗夹具的10/14只是单测值，不能复制成正式规则。

## 数值配置与显式暂定解释

`data/combat/tuning.gd`分CONFIRMED、INITIAL、TEST_RANKS、POLICIES；`data/combat/ability_tuning.gd`保存扩展空间参数、测试档位及策略。基础倍率/CD保留用户规格；所有缺失空间、动作、升级表和以下解释**只验证当前测试策略，不代表设计已确认**。

- 测试基础：HP240、AD32、移速6、攻速1.7；攻击1AD、2.8×2.6米、前摇0.1秒；Shift4.2米/0.16秒/CD3.2，无攻击/无默认无敌。冲刺优先移动方向，否则朝向；不取消已锁定前摇。
- 只有平面矩形边界夹限与敌人软分离，没有生产碰撞/导航。穿刺/瞬移合法落点目前仅裁剪至房间边界，不宣称墙体/复杂地形扫掠通过。
- Q1基础4.2×1.8米；强化按基础加算，每cast最多一层；命中仅退一次完整有效CD的30%；只接受同cast致死，不改成助攻。宽限0.2世界秒；最后击杀封房时先关闭归因事务。
- Q2初始8米、后续4.5米；先按指针选最近合法目标，再按上一位置选最近未命中目标，相等按ID；执行每跳前重验死亡/范围。约0.2秒一跳，最后目标身后1.3米裁边界；全段输入锁与伤害/控制免疫。
- Q3即时11×2米矩形，逐目标一次，冲量8.5；没有双充能或额外眩晕。普通/精英位移，Boss转硬直为测试换算。
- E1范围12米、速度18米/秒、飞行最多2秒；目标死/超时在权威tick结束旧状态进入CD；命中1.5AD后标5秒，二段目标周围3米选点、路径宽1.3米/0.5AD。失败输入本身不偷偷启动CD。
- E2旋斩半径2.7米、0.25秒且可移动、瞬移最多6米；落点1.8米内有敌给1秒无敌，只有一圈，无落地额外伤害。
- E3额外真伤按暴击后/防御前的普攻普通伤害25%，不触发吸血；E3/P3仅本单人致死计数，未实现助攻。减Shift与CDR相乘，只影响新冲刺，旧CD不改；续时无上限。
- P1/P2三档2/4/6%吸血、7/11/15%回血与120/100/80秒CD是**新测试表**。P2重置活动Q/E不取消/不复制状态，给一次结束免CD信用；被动CD使用全局CDR。P3未满计数保留，按新阈值在下一次合格击杀扣除；无成长上限，仅本局增量。
- R1以施法位置为中心、半径10米、演出1.1真实秒、世界×0.2；严格低于5%才斩杀，Boss相同，不加免斩或百分比削减。
- R2按**普攻动作完成（空挥也算）**计数并去重；窗口为3世界秒、恰好边界不可续；每根同一12×1.6米矩形逐目标一次；累计不清零、不封顶。每投0.25真实秒独立演出/免伤，三投结束或窗口结束才进130秒CD。Boss比例无削减；30%慢速对Boss每投转0.3硬直，阈值1/0.65秒为测试值。
- 防御100/(100+max(0,防御−穿甲))、暴击175%、范围吸血40%、持续伤害吸血25%为可调初值；此原型没有持续伤害机制。普通攻击为范围吸血折算，P1不扩成技能吸血。
- 死亡测试时序：首次致死倒地，按空格35%HP自救/1秒无敌；再死真死亡。具体时序/恢复量未批准。场景F5/F6是全新测试局才重置，不提供战中免费治疗。

## 战后逐项状态

| 状态 | 当前原型处理 |
|---|---|
| HP、基础回复、所有CD、控制/充能字段 | 立即冻结；等待不回血、不转CD；新房仅按新传入delta继续。没有额外充能能力。 |
| Q1层与宽限 | 保留层；最后击杀先结算归因，其他待决状态冻结。跨房保留是暂定策略。 |
| E1飞行/标记、E2未完成段 | 保留并冻结；恢复后失去旧目标则E1按失效路径进CD。未默认全部清除。 |
| E3剩余Buff | 保留并冻结；结束后才进CD。换候选也不能在旧活动状态结束前免费开启新E技能。 |
| R2轮次/普攻累计/续投截止 | 保留并冻结；演出令牌回收；第三投已完成则提交CD再冻结。未完旧R2会阻止新选R1并存。 |
| P2 CD、P3计数/本局AD | 保留冻结；新局显式重建才清本局成长。 |
| 大招演出 | 死亡/封房收回所有令牌，世界恢复正常；强制结束R1时提交其冷却再冻结，独立E2/自救无敌不被R1清除。 |

## 最新敌人美术合同核对

已只读 `feature/fengli-art` 69d58417 的 `assets/arena/enemies/README.md`。现有模拟前摇普通/精英/Boss为0.85/1.00/1.35秒，收势1.10/1.10/1.60秒，与美术打击帧一致。正式接入需将`enemy_warning`映射到windup、`enemy_impact`映射到release，以战斗世界时间驱动，受击不能取消权威预警；死亡和房间冻结应同步表现。当前可选模型适配器只有风厉动作通用入口，**尚未实现/验收新敌人windup/release/walk映射**，不能仅挂GLB就视为已接入。本轮优先交付白盒阶段，后续由主任务统一整合。

## 准确剩余边界

无环境/MCP/可运行性阻塞。仍待父任务集成：正式成长模型、奖励/恢复事务、正式UI、美术实例与动画时序；本分支仅提供夹具和适配口。仍待设计确认：上述暂定算法、跨候选/跨房状态策略、正式各档数值、R后两阶门槛、死亡时序、复杂地形规则。

未做：商店/装备/海克斯/药品底层、四幕、联机、生产导航、真人手感与实机性能、中文打包字体保证、Windows运行。本次不声称主线导出审计等于本战斗场景导出验收；主线导出与发布由主任务负责。没有将未确认内容永久删掉，也没有把未执行项列为通过。
