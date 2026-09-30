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

# 第二轮：可调初值目录（2026-09-30）

本节取代首轮关于“尚无原型目录”的状态，不把首轮 fixture 改名当商品表。唯一新来源是本轮用户粘贴的内容提取规范；其中 T54/T58/T76/T94 是该提取稿提供的索引，本任务没有冒称重新取得或阅读全文附件。所有新价格、属性量、名称、配方、权重、治疗值都标 **“新增可调初值，非历史确认定值”**，`release_ready=false`。

优先修复 QA-001：`e022b456007287b40828d45f3363634c749f3e42` 已独立推送。与主集成相同的原子负币保护及17项交错交易回归：撤销出售前先检查能否归还售款，再弹出交易；拒绝不能擦除锻体或部分改变账本。新目录提交在其后，父任务可先只取此修复。

## 文件与兼容性

- 原 `fixture.json` / `confirmed_rules.json` 保持不变；首轮 model/API保留，仅纳入 QA-001 修复及“新目录误传旧类时原子拒绝”的防错门禁。
- 新可调目录：[prototype/catalog.json](../data/progression/prototype/catalog.json)；离线严格结构 schema：[catalog.schema.json](../data/progression/prototype/catalog.schema.json)。schema 禁止未登记字段与第13属性，核心确定成本/槽数仍在引擎；价格/数值/权重可改后重跑测试。
- 新 `CatalogModel` 位于 `scripts/progression/catalog_model.gd`，继承首轮 Model，构造函数仍为 `(definitions, actor_id, seed)`，`command/snapshot/save/restore/shop_catalog/equipment_effects/body_effects` 的既有入口保持。
- **仅新目录显式选择 CatalogModel**，不要把 prototype JSON 直接交给旧 Model，误传时旧模型返回 catalog_adapter_required，避免绕过内容支持检查。现有 UI/战斗继续使用旧 Model 时不会被悄悄切换新数值。
- 新增 `select_body` 命令与 `body_pending` 字段，新增 `support`、`set_supported_hooks`、`aggregate_effects`、`project_stats` 只读/协调接口。新目录 `buy_body` 是安全商店买入揭示三个候选；不要求训练节点。旧 fixture 的 `buy_body` 保持原行为，便于现有 UI 映射不变。
- **实际战斗适配未在本分支实现**：默认没有支持能力，所有商品购买、锻体、海克斯抽选均失败关闭。模型测试仅通过明确声明的测试能力验证数值投影/事务，不把测试 stub 宣称真实战斗 hook。

## 新目录设计

12组件沿用 T94 名称/属性映射，新增逐件量值/价格；3中级构成基础→中级→成装的多级路径。8成装全部使用新原型名称，避免将历史追猎刀、血壳、回响法典的触发草案误称实现。绝大多数是2–3个主属性，只有续战两件共享一个已实现唯一数值组。没有全能装、额外技能点、随机品质或词条。

属性口径：AD/AP/最大生命/防御/穿甲为 flat；攻速/移速为基础值线性加算比例；暴击/冷却缩减/吸血/韧性为比例增量；基础生命恢复为战斗中 HP/秒。`project_stats(base)` 应用攻速2.5、CDR65%、韧性100%的已确认上限；它不改变 `base` 或当前HP/CD。返回的 hp_regen 只是数值，战斗端必须只在战斗时间推进恢复，安全状态仍冻结。

| 物品 / 层级 | 价格 | 属性初值 | 配方 + 合成补价 |
| --- | ---: | --- | --- |
| 铁刃 / component | 450 | AD 8 | 直接购买 + 0 |
| 秘典 / component | 450 | AP 12 | 直接购买 + 0 |
| 机簧 / component | 500 | attack_speed 0.12 | 直接购买 + 0 |
| 锐镜 / component | 500 | crit_chance 0.08 | 直接购买 + 0 |
| 冷凝核心 / component | 550 | cooldown_reduction 0.06 | 直接购买 + 0 |
| 血晶 / component | 500 | max_hp 100 | 直接购买 + 0 |
| 合金甲片 / component | 500 | defense 10 | 直接购买 + 0 |
| 风靴组件 / component | 450 | move_speed 0.05 | 直接购买 + 0 |
| 血囊 / component | 600 | lifesteal 0.04 | 直接购买 + 0 |
| 定心环 / component | 400 | tenacity 0.1 | 直接购买 + 0 |
| 钻芯 / component | 550 | penetration 8 | 直接购买 + 0 |
| 活性组织 / component | 400 | hp_regen 2 | 直接购买 + 0 |
| 穿锋组件 / intermediate | 1100 | AD 12、penetration 10 | 铁刃 + 钻芯 + 100 |
| 疾动组件 / intermediate | 1100 | attack_speed 0.18、move_speed 0.06 | 机簧 + 风靴组件 + 150 |
| 护持组件 / intermediate | 1150 | max_hp 150、defense 14 | 血晶 + 合金甲片 + 150 |
| 决斗锋刃 / complete | 2400 | AD 32、crit_chance 0.18 | 铁刃 + 锐镜 + 1450 |
| 突刺尖锋 / complete | 2600 | AD 28、penetration 18、cooldown_reduction 0.08 | 穿锋组件 + 冷凝核心 + 950 |
| 疾攻薄刃 / complete | 2500 | AD 18、attack_speed 0.32、move_speed 0.06 | 疾动组件 + 铁刃 + 950 |
| 坚壁战壳 / complete | 2700 | max_hp 360、defense 30、tenacity 0.2 | 护持组件 + 定心环 + 1150 |
| 续战血锋 / complete | 2800 | AD 24、lifesteal 0.12；唯一活性循环：基础回复+3/秒 | 铁刃 + 血囊 + 1750 |
| 活性护壳 / complete | 2600 | max_hp 280、defense 18；唯一活性循环：基础回复+3/秒 | 护持组件 + 活性组织 + 1050 |
| 凝思法典 / complete | 2400 | AP 48、cooldown_reduction 0.16 | 秘典 + 冷凝核心 + 1400 |
| 稳步护具 / complete | 2500 | move_speed 0.12、tenacity 0.25、max_hp 220 | 风靴组件 + 定心环 + 血晶 + 1150 |
| 普通血瓶·原型 / consumable | 75 | 治疗最大生命 0.18 | 直接购买 + 0 |
| 特殊补血药·原型 / consumable | 140 | 治疗最大生命 0.3 | 直接购买 + 0 |

取舍：决斗锋刃买AD/暴击；突刺尖锋买AD/穿甲/冷却，不附带突刺专属机制；疾攻薄刃买攻速/机动但AD较低；坚壁战壳放弃输出换生命/防御/韧性；续战血锋靠吸血与回复，活性护壳靠生命/防御与回复，两者同组回复只生效一次；凝思法典供有AP消费者的英雄/版本，**风厉若没有AP伤害消费者，不声明 stat.AP.v1，就不能购买秘典/凝思法典**；稳步护具偏机动/抗控而非高AD或高防御。

2400–2800成装价格只是新实验范围，没有把历史经济锚点解释成已确定的每关收入。本轮 XP 曲线为100起、每级增加25的可调初值；没有提供怪物掉钱/经验最终表，没有修改战斗奖励数值。锻体900金的同属性收益低于对应基础组件的每金币效率，换取不占槽与永久；没有作完整四幕平衡结论。

## 锻体、药品、唯一被动

锻体7结果：AD+8、攻速+10%、最大生命+100、穿甲+8、防御+10、AP+12、暴击+7%；每次900金，等权抽三个不同结果选一。池只来自来源明确举过的7属性，不将全部12属性自动放入池。只从已接通效果里抽，少于3个合法结果时 `body_pool_exhausted` 原子拒绝。

本轮明确**试验策略**：三选项不同；买后未选时阻止下一次购买，不退款，候选一直存档保留。选择请求为 `select_body {purchase_id, outcome}`，选中后才能加入属性；重复命令回执复用，新ID重选拒绝。没有刷新/撤销/洗点入口。已经揭晓的结果、选择、随机状态、扣款均存入原存档结构；加载后不会重抽。运行能力不存档，重连须由宿主重新绑定真实hook。

普通血瓶75金/18%最大生命、特殊药140金/30%最大生命均为初值。延用首轮普通5瓶同槽、持有互斥实验；本轮使用时机显式选“仅安全阶段”、瞬时恢复、过量丢弃、不刷新CD；特殊药仍是首轮“单份使用后消耗，稳定新关ID重置使用次数计数”的试验，而**不是已确认的永久药瓶每关补充实体充能**。普通≤5、特殊每关≤2等已确认限制不变。未决定“关=房/波”；只接受父任务稳定 combat_level_id。

`use_item` 仍输出 `recovery_requested`，含 recovery.mode/amount/allowed_phases/overheal/refresh_cooldowns。宿主先验证活着、可恢复、阶段、效果可用等条件，再串行提交消耗与HP恢复；按 actor_id+command_id 去重恢复事件。能力名只是宿主声明，不是原子跨模块事务证明；没有接好恢复hook前绝不启用 recovery.v1，不会花钱买空药。

`equipment_effects().stats` 已包含**唯一组只加一次**的被动数值；`passives` 是标识清单，战斗消费者不得据其再次叠加同一数值。`snapshot().content_warnings` 提供 duplicate_unique_passive、拥有份数/生效份数，UI可直接提示。唯一组里暂无不同强度版本，未擅自选择“最大值优先”策略。

## 海克斯内容与耗尽边界

可接入的初值池为公共12 + 风厉12个**新数值项**。公共分别覆盖12属性；风厉8个英雄通用数值项、4个依赖Q1/Q2/E2/E3的数值项。依赖项在未学时可出现但休眠；学会激活、洗点后保留选中并休眠。它们给予通用属性，不把“Q1依赖AD”偷换成“仅Q1伤害”。这不是将旧机制草案简化后沿用其名字。

原13公共 + 6风厉机制草案完整保留在同目录，`status=unsupported`，不入池，即使调用者声明同名hook也不能解锁；须真正实现并审核定义后再改状态。一步十杀/剑走偏锋为一个effect_key及alias，绝不当两项。第二套弹匣不借R2轮数凑充能；留影/双施法/Q2重复目标等不硬凑现有API。具体 description、未决字段及所缺hook均在各条定义中。

没有品质分档。当前四槽、已选、本轮刷新掉的条目均排除，effect_key用于同一效果去重；不把同一草案的不同标题拆成多张。不同新数值项的属性方向可能相同，但数值/英雄范围不同，属于独立新设计，未宣称解决所有未来“同效异名”的一般归并问题。

抽选策略继续 `floor(base_weight/(1+seen_count))`，最低1；未学依赖项再乘0.5（新可调初值）优先照顾英雄通用项，不作绝对过滤。战斗中不弹出/刷新/选择；pending_milestones保留，安全时可处理。

**足量结论的精确前提**：每轮选择结束后处理下一轮，顺序任意；stats.v1及所有该池属性消费者已绑定。第五轮最多已有4个选中，最坏本轮需8个不重复，12个合法风厉选项足以覆盖右槽即使其他三个槽也都抽到英雄项。40种固定种子 × 左/右选择路径 × 两种刷新顺序运行五轮、每轮四槽全部刷新，无耗尽。总24项提供混合余量。

若宿主只支持少数属性，或同时打开多个未完成offer并互相占位，不能照搬这个足量结论；候选不足返回 pool_exhausted，保留余额/RNG/次数/展示。宿主按任意待处理里程碑逐轮完成即可；没有强制固定弹窗顺序。它不是“所有hook都没接也要硬填右槽”的假闭环。

## 缺失战斗hook与接线合同

| Hook | 接入方必须实现 / 当前分支提供 |
| --- | --- |
| stats.v1 + stat.AD/AP/attack_speed/crit_chance/cooldown_reduction/max_hp/defense/move_speed/lifesteal/tenacity/penetration/hp_regen.v1 | 逐属性消费 aggregate_effects 或 project_stats；每次按基础值重算，不能反复累计上个结果；当前HP/CD/充能不初始化、不补满，regen只在战斗；本分支只提供纯投影 |
| recovery.v1 | 预检、消费/治疗协调、事件去重、过量丢弃、安全阶段及稳定关ID；本分支只有事件与消耗账本，未写HP |
| draft_* 所列细分hook | dash_cooldown、kill_buff、same_target_attack、dash_end_damage、repeat_cast、target_hp_cooldown、skill_damage_cooldown、final_damage、ability_charges、r_spent_points_buff、low_hp_lifesteal、cast_sequence、potion_buff，以及6个风厉专属触发；全部 unsupported，不允许花资源白买/白选 |

由**权威宿主**调用 `set_supported_hooks([...])`；UI不能自行开能力。初始为空，存档不会恢复能力声明；缺hook的已持有内容也会停用，并输出unsupported提示。AP、恢复、基础回复等不应因为“有个字典字段”就被宣称已接入。`support(definition)`、目录availability、hex_status可用于禁用按钮与说明；`aggregate_effects()` 合并装备/唯一被动/已选锻体/激活海克斯，仍不修改任何战斗对象。

## 本轮复现

```sh
# 依赖复用现有MCP venv，无新增安装
.local/blender-mcp-venv/bin/python tests/progression/catalog_schema_test.py
XDG_CACHE_HOME="$PWD/.local/cache" XDG_DATA_HOME="$PWD/.local/data" \
XDG_CONFIG_HOME="$PWD/.local/config" godot --headless --path . --script tests/progression/catalog_run.gd
# 继续保留首轮和P1回归
XDG_CACHE_HOME="$PWD/.local/cache" XDG_DATA_HOME="$PWD/.local/data" \
XDG_CONFIG_HOME="$PWD/.local/config" godot --headless --path . --script tests/progression/run.gd
XDG_CACHE_HOME="$PWD/.local/cache" XDG_DATA_HOME="$PWD/.local/data" \
XDG_CONFIG_HOME="$PWD/.local/config" godot --headless --path . --script tests/progression/integration_run.gd
```

真实MCP复现沿用首轮隔离副本流程，补复制 `data/progression/prototype/`、`scripts/progression/*.gd`、`tests/progression/*.gd` 后，依次用现有 `scripts/mcp/check.py` 运行 `tests/progression/mcp_catalog.json` 创建场景、`tests/progression/mcp_catalog_reopen.json` 重启编辑器复核。不改客户端或主项目配置。内容审阅场景 `scenes/progression/catalog_review.tscn` 默认关闭全部实际战斗能力，B验证拒绝扣钱、P翻阅4页；独立自动套件运行在另建模型上，测试成功不会给审阅模型开放假能力。

本轮最终验证：离线 schema/配方38项通过；目录模型 **13,862次断言、零失败**（含80条五轮路径，不等于13,862种独立玩法）；首轮274项与P1交错17项仍通过。MCP创建18步、最终重新启动编辑器14步全部无工具/应用错误，场景内再次执行完整目录套件，缺能力购买返回unsupported_effect且金币10000不变。已查看最终1280×720中文四页截图，未宣称Windows/正式UI/真人输入验收。

- [本轮源码/证据哈希](../tests/progression/evidence/catalog_v2/manifest.json)
- [目录模型日志](../tests/progression/evidence/catalog_v2/verified/headless-catalog.log)
- [8件成装与配方截图](../tests/progression/evidence/catalog_v2/verified/step-09-get_game_screenshot-0.png)
- [药品/锻体/海克斯边界说明截图](../tests/progression/evidence/catalog_v2/verified/step-11-get_game_screenshot-0.png)
- [最终状态/目录读回](../tests/progression/evidence/catalog_v2/verified/step-12-execute_game_script.json)

当前文件的调参必须同时推进 `catalog.version` 并重跑结构、配方、经济、抽池和随机恢复测试；旧存档版本拒绝加载，本轮不提供迁移。首轮manifest属于607bf63的历史证据，不能拿它校验经P1修复后的源码；第二轮以catalog_v2/manifest为准。MCP已知Blender状态工具缺配置问题仍单列保留；未改上游服务或扩大工具权限。实际战斗hook、治疗跨模型原子接线、全四幕经济与手感平衡仍为父任务后续工作。
