# 独立 QA 审查（2026-09-30）

当前结论（第三轮更新）：**QA-001已在指定修复及catalog源码提交独立复测通过；QA-002待修复SHA；不能签署最终集成可玩通过。** 未收到父任务的最终整合包 SHA，以下只针对指定阶段源码。没有修改 main 或任何功能文件；新增内容仅在 `qa/independent-audit` 的 `tests/qa` 与本文档。没有发布、部署或接触用户电脑/阿里服务器。

## 精确基线与方法

- 战斗：`6ae6dd982d7b5a1103f5fa77bb0b6bee80948eb4`
- 成长：`607bf6385f5f668155aa76f5df6eb184e5685cea`
- UI：`d02a4e8510e280fe50f6ec8a63750e655994d7bb`（只读合同审查，未做新的完整 UI 验收）
- MCP 客户端/规格/矩阵读取来源：`0bc397cd7d7b7a7df6e29b3780f987669e8d181d`；另只读取到 `origin/main=73187c84544007fb8b6c4737bc4839db54b9ba70`，并未将其当作父任务指定最终版。
- 引擎 Godot 4.6.3，Blender 4.3.2，Linux llvmpipe。软件与 MCP SDK 按仓库脚本安装至项目 `.local`，没有扩张权限、开放公网端口或更改上游插件。
- 独立脚本直接实例化原战斗/成长模型，不复制被测算法。MCP build.json 内的源代码是传输原文件到隔离应用的载荷，不是另一套模拟实现。
- 规格中 Q1 每 cast 一层/基础加算、Q2 不重复目标、R2 空挥完成计数、跨房保留及 fixture 数值按已公开原型策略验证，未把未定数值当 bug。R 后两阶门槛只使用测试 fixture，不声称正式规则已确认。

## QA-001：撤销出售可令金币为负（P1，已复现）

位置：成长提交 `scripts/progression/model.gd:146-148`。`undo_shop` 直接弹出记录并增加 `gold_delta`、恢复 inventory，没有校验撤销后金币是否足够。`buy_body` 在同文件 156-162 行保留不可逆花费，但没有消除先前出售产生的撤销依赖。

只用公开 command API 与仓库原 fixture，步骤如下：

1. `reward_minion` 授 100 金作为准备数据，`context` 设安全训练点。
2. 买 component 花 100，金币 0。
3. 卖该物品，金币 90。
4. 买一次 body 花 50，金币 40，body 账本 1 条。
5. `undo_shop` 撤销出售。

实际：`accepted=true`，金币 **-50**，component 恢复，body 保留。预期：余额不足时撤销应完整拒绝，金币仍 40、背包仍空、body 保留，撤销账本不应被部分弹出；或实施明确且不撤销锻体的合法交易依赖规则。不能通过退还锻体费用掩盖问题。

证据：[原始命令/回执](../tests/qa/ledger_probe.log)、[最小复现脚本](../tests/qa/ledger_probe.gd)。没有声称已经证明无限金钱套利；确定的是允许无足够资金恢复已售资产、钱包负值。

为什么现有测试漏掉：`tests/progression/suite.gd:110-116` 从富裕钱包测试“购买物品→锻体→撤销购买”，撤销是加钱；没有覆盖“出售→不可逆花费→撤销出售”的减钱路径。常规买卖撤销循环不能覆盖这种操作交错。

## 窗口级玩家输入与 MCP 读回

实际链路：官方 MCP ClientSession → stdio initialize/list/call → Godot 插件准备固定目标和读取状态；**X11 XTest 在实际游戏窗口发送鼠标/键盘** → 游戏自身输入/物理帧 → MCP 返回快照与截图。没有调用 attack/cast、手动扣目标血或脚本合成 Godot InputEvent 来冒充玩家击杀。夹具仅在输入开始前设置 64 HP 靶子、禁用 AI、无自然回血；这不是自然游玩难度验收。

- [输入驱动](../tests/qa/window_input.py)、[MCP 工作流](../tests/qa/window_workflow.json)、[只读回执与准备接口](../tests/qa/window_harness.gd)
- 输入前：敌人 HP 64，玩家 240，无伤害事件。[state-02](../tests/qa/evidence/window/state-02.json)
- 左键按住 1.25 秒：cast 1 造成 32，cast 2 造成 32，只有一次 kill，随后 encounter_finished；读回 phase=victory、目标 HP=0。[state-03](../tests/qa/evidence/window/state-03.json)
- [MCP 截图](../tests/qa/evidence/window/step-04-get_game_screenshot-0.png) 已亲自查看，显示存活敌人 00、战斗状态已冻结，HP240，LMB剩余冷却0.5。实际截图尺寸 **1228×690**，不是请求的1280×720，受编辑器嵌入窗口影响；未冒称完成矩阵要求的两个分辨率。
- 另一次 W 按下0.25秒→窗口失焦→焦点外松开→返回游戏，读回 `held_keys[87]=false`，位置 z=-1.799999，未持续跑到边界；[state-06](../tests/qa/evidence/window/state-06.json)、[截图](../tests/qa/evidence/window/step-07-get_game_screenshot-0.png) 已查看。此路径**未复现卡键**，不推断模态面板所有松键边界均通过。
- 输入日志：[window-input.json](../tests/qa/evidence/window/window-input.json)。所有工作流步骤 `application_error=false`；握手早期 ready 失败和已知 Blender status 缺 config 分开保留。
- 成长奖励尚未接入此战斗分支，**没有验证“玩家击杀→正式 XP/金钱→升级 HUD”的全链路**。未做真人手感、Windows、真实设备性能验收。

原战斗分支所称 11 项 MCP 原生输入断言实际使用 `MCPInputBridge.queue_events`/新建 InputEvent。其文档已如实说明，属于输入路由测试；本次没有将其当窗口验收，也没有把这一诚实披露列为缺陷。

## 独立边界探针结果

以下为模型 API/固定时钟验证，不能替代键鼠路径。证据：[combat_probe.log](../tests/qa/combat_probe.log)、[progression_probe.log](../tests/qa/progression_probe.log)。原机制套件也重新运行，无新失败；[baseline.log](../tests/qa/baseline.log)仅作背景，不作为质量结论。

| 检查 | 结果与范围 |
| --- | --- |
| Q1 同次五目标致死 | 5次唯一 kill、只加1层、Q冷却0；按公开每cast一层策略 |
| 死目标重复 damage | 无新增 kill；正式奖励映射仍待最终整合验证 |
| Q2 | 0.795秒内每tick施加致命伤/控制均不掉HP；0.805秒后4次hit结束、不可选中清除 |
| E3 战后与跨房 | 先消耗2秒，封房等待60秒HP/Buff/CD不变；次房再5秒结束，E CD开始为32 |
| P2 直接致命 | 真死亡，未触发被动CD，不能救命 |
| R1 封房 | 慢动作令牌清空、世界倍率1、场外60秒CD冻结 |
| R2 累计 | 第一投1根，完成2次普攻后第二投3根，再完成1次普攻后第三投4根；结束恢复倍率1并起CD |
| 重复奖励 | 相同 death event ID 换新 command ID，仍被拒绝且快照不变 |
| 18点 | fixture升18级，P3/Q5/E5/R3恰好花18点；逐笔撤销返18；空洗点不生点 |
| 特殊药 | 第三次使用原子拒绝；同关重入及 safe/combat切换不能重置2次额度 |
| 药品互斥 | 公开 holding 策略下持特殊药时普通药购买拒绝；其他策略仅原套件、未新增独立验证 |

## 集成必查风险与未执行项

**UI 输入隔离必须在宿主接线。** `scripts/combat/arena.gd:148` 直接轮询 `Input.is_mouse_button_pressed`，Control 消费鼠标事件无法阻止该轮询。UI `combat_hud.gd:342` 已提供 `blocks_gameplay_input()`，其交接文档也明确要求宿主调用。战斗阶段未整合此 HUD，因此这里是已定位的接入风险，**不是对最终整合版本的已复现缺陷**。最终应按 PI08/09 验证按钮、背景、边缘、按住开关、面板内松键、20次开关与键盘技能隔离。

最终整合提交/包尚未提供，以下保持 NOT_RUN/BLOCKED，不能用白盒通过替代：

- PI02/11/16 的真实击杀→正式成长奖励/升级HUD、adapter重建与重复回调；真死亡经验罚款和重试不重置账本。
- UI所有11候选通过面板学习并施放；旧技能与新候选跨房、撤销/洗点后的HP/CD不刷新；恢复药消耗与战斗HP原子事务。
- UI模态打开期间敌人、CD与自然回血继续；最终宿主的暂停/慢动作组合、死亡/封房恢复。
- 实际导出包、1280×720/1920×1080、Windows窗口输入、禁插件可玩性。
- Q1/R2/P2等独立模型探针通过不代表全部空间目标、粗细帧、重施边界均由本次独立验证穷尽。

## 复现与交接

独立工作树 `/workspace/shuabao-qa` 在 `qa/independent-audit`；只读成长工作树 `/workspace/shuabao-progression` 固定上文 SHA，UI工作树 `/workspace/shuabao-ui` 同理。`bash tests/qa/run.sh` 可重跑模型探针。成长探针目前直接读取这个精确绝对路径，换环境先按同路径建立该提交工作树。负钱包脚本是缺陷复现器，以 `NEGATIVE_WALLET_REPRO=true` 报告复现，不把零退出码误认成验收通过。

MCP 工具链安装使用原 checkout `/workspace/shuabao` 的 `scripts/mcp/check.py`。先运行 `tests/qa/build.json`（原文件传输和仅QA场景挂载），独立重启编辑器后运行 `window_workflow.json`，同时启动 `window_input.py <evidence绝对路径>`。窗口驱动等 MCP 准备回执才发输入；重复运行应使用新的 evidence 目录，防止读取旧step文件。

首次 MCP 构建缺少 scenes/combat 目录而失败；第二次使用 expression工具执行 DirAccess 失败。失败回执完整保留在 build/build-retry。最终用 MCP create_script 创建目录后完成 build-final，并重启验证，没有静默修改上游工具。一次初始无头运行未设置XDG导致只读home崩溃，改为项目/临时XDG路径后通过；未申请权限扩张。所有当次MCP GUI与服务已由标准客户端清理。

接到父任务最终SHA后应重新运行受影响模型回归、真实窗口输入/截图以及上述集成门槛，再决定是否接受最终包。当前报告不授权或声称发布。

## 第二轮：交错事务与跨房结束边界

仍针对上文精确阶段 SHA。父任务已安排 QA-001 修复，修复提交尚未提供；本轮不修改被测功能，不重复把同根因生成多项缺陷。

### QA-002：已经结束并起CD的 R1 延迟伤害进入下一房（P2，已复现）

位置：`scripts/combat/combat_sim.gd:424-426` 结束R1并起CD，但保留 `pending`；`:312-315` 在后续世界时间到期执行；`:348-353` 不校验原房间或施法是否已结束，而对当前房敌人结算。`begin_encounter:475-479` 已经替换房间ID与敌人集合。

无需直接强制结束房间的最小重现（准备数据与施法为模型API，不冒称窗口输入）：

1. 配装 E1/R1，英雄原点，关自动结束开启，AI关闭，最后一个敌人在 `(0,0,-1)`、HP1。
2. 依次 `request_action('e', enemy.position)`、`request_action('r', enemy.position)`；此序列被当前动作合同正常接受。
3. `step(0.2)`：E1先在世界时间0.028命中杀敌，房间自然胜利。
4. 读回：`phase=victory`、`r1_active=false`、世界倍率1、R CD130；但 `pending` 仍含旧 `cast_id=2 / r1_damage / due=0.06 / damage=48`。
5. `begin_encounter('after-natural-victory', [{kind:'minion',position:Vector3(0,0,-2),hp:1000}])`，**没有新施法输入**，再 `step(0.05)`。
6. 实际：新敌HP **1000→952**，世界时间0.063记录来源R1、旧cast_id=2、新combat_level_id的伤害和ultimate_impact事件。

预期：既然R1已按公开封房策略强制终止并提交CD，不能再将其已取消的延迟impact应用到下一房敌人。此项针对终止事务内部不一致，不要求擅自清除E3/P2/R2等已明确暂定保留的状态。建议修复精准处理被终止的R1 impact或校验其生命周期/房间归属；不要直接清空所有pending来破坏已公开的Q1归因等机制。

证据：[round2_combat.json](../tests/qa/round2_combat.json)最后一项保留结束快照及完整事件；[脚本](../tests/qa/round2_combat.gd)最后一段是最小不同根因复现；[日志](../tests/qa/round2_combat.log)。脚本在当前版本因该缺陷退出1。这是模型级确定复现，最终宿主可能不开放该切房方式，最终包触达性尚未验证。

### 交错经济事务

[round2_economy.gd](../tests/qa/round2_economy.gd)直接实例化成长原模型，以96条固定种子序列交错买零件、合成blade、买两类药、卖出、消费、不可逆锻体、撤销、safe/combat切换、稳定关ID切换、重复死亡奖励、历史成功/失败命令重放；两种公开互斥策略×是否堆叠×24种子。每条最多160次，发现违反不变量即保留轨迹并停止该条，防止在非法钱包上继续扩散噪声。

独立守恒口径：`金币 + 按fixture标价计价的持有资产 + 不可逆锻体支出 + 已消费药品成本 + 未撤销卖出损耗 = 初始400金`，不从实现的undo账本推导期望值。另检查金币非负、物品UID唯一、数量/槽位/使用额度、实际投资与fixture标价一致、失败原子性、历史请求重放不改状态且回执一致。这里的标价是已披露fixture，不将其认作正式经济数值。

结果：实际执行14799次随机操作，8条轨迹只重现 **KNOWN_QA001_negative_gold**；未发现不同根因的守恒、重放、原子性或额度失败。覆盖包括真正成功的合成和药品消费，并非仅检查被拒分支。完整轨迹及按操作分类的覆盖见 [round2_economy.json](../tests/qa/round2_economy.json)，摘要见 [日志](../tests/qa/round2_economy.log)。样本无新失败不是经济系统正确性的证明；接到QA-001修复SHA后应复跑全部轨迹。

### 其他有价值边界结果

- Q2 首目标在第一跳前死亡：存在替代目标时重选，无替代目标时正常结束；两者均清不可选中并起CD。下一目标在第一跳后死亡也正常收尾，不重复第一目标。
- P2 在活动E3剩5秒时触发：恢复HP、只留一份结束免CD信用，重复E被拒且不重启持续时间；跨房冻结后继续，第一次E3结束免CD，下一次结束正常起32秒CD。按已公开原型重置策略验证。
- R1/R2 演出内致命伤请求确实被免疫，不能用这种请求声称测试到了死亡。另分别测试演出结束后真实致命→true_dead，以及直接生命周期终止→慢动作令牌清空，两种测试不混称。
- 本轮没有新增窗口测试；上一轮XTest输入→MCP状态/截图证据仍只代表那条阶段战斗路径。没有忙等或擅测未提供的最终整合SHA。

运行第二轮：沿用 `tests/qa/run.sh` 中的项目XDG环境后，分别 `godot --headless --path . --script tests/qa/round2_economy.gd` 和 `... --script tests/qa/round2_combat.gd`。经济脚本以JSON分类记录已知问题；战斗脚本有失败则退出1，需检查具体结果而非只看总计数。

## 第三轮：QA-001修复复测与catalog能力门禁审查

新增固定只读工作树：

- `/workspace/shuabao-progression-fix`：`e022b456007287b40828d45f3363634c749f3e42`
- `/workspace/shuabao-catalog`：`fdd18ea34003b6b44794651fe8963cc0e04cf43d`

### QA-001状态：指定源码修复已独立验证，最终整合仍待测

修复先读取 `shop_undo.back()`，在 `state.gold + undo.gold_delta < 0` 时返回 insufficient_gold，再由原事务框架完整回滚，足额时才弹记录。两份上述提交均执行独立场景：

1. 原最小复现现在拒绝，金币40、空背包、锻体1条、买/卖撤销记录2条完整保留，整个快照相同。
2. 补50金后重放原失败command ID，仍返回原失败且不动状态；新command ID恰好足額撤销出售，金币0、零件恢复、锻体保留。
3. 重放成功ID不再次撤销；继续以新ID撤销原购买，金币100、空背包，锻体仍保留。没有用退款锻体解决负钱包。

证据：[round3_qa001.json](../tests/qa/round3_qa001.json)、[脚本](../tests/qa/round3_qa001.gd)、[日志](../tests/qa/round3_qa001.log)。结果分别引用真实模型，未应用作者补丁到测试复制逻辑。

上一轮相同96个固定种子、相同动作选择器在两个新提交分别复跑，均完成15356次操作、没有金币非负/守恒/失败原子性/请求重放/物品及额度不变量失败。此前14799次是8条轨迹遇到已知失败提前停止；本轮无提前失败，但少数首步随机选到尚无历史回执的重放被跳过，所以不等于96×160。证据：[修复提交报告](../tests/qa/round3_economy_fix.json)、[catalog提交兼容模型报告](../tests/qa/round3_economy_catalog_legacy.json)。**这两次使用原fixture及legacy model，验证修复和后续提交兼容性，不冒称对新catalog全部经济内容做了随机覆盖。**

`round2_economy.gd`只新增环境参数指定源码根、基线SHA、报告位置，以及失败退出码；动作生成器和不变量未为了通过而修改。旧round2报告保留。

### Catalog审查：未发现把能力标志当实战实现的生产调用

静态读取核对了12组件/3中级/8成装/2药品、24个prototype_initial数值海克斯与19个unsupported机制草案；所有启用属性定义包含对应 `stat.<属性>.v1` 门禁，无缺项。此处“启用”是可被能力声明开放的数据项，**不是默认可购买/已实现战斗效果**。

指定分支 `scripts/` 中没有调用 `.set_supported_hooks(...)` 的位置；`catalog_demo.gd`的现场模型默认空能力，另建隔离测试模型才声明hook。自动套件的通过结果不会给现场审阅模型开能力。静态证据：[round3_catalog_static.json](../tests/qa/round3_catalog_static.json)。没有读取未提供SHA的最终宿主，结论仅限fdd18ea。

独立动态门禁验证：[round3_catalog.gd](../tests/qa/round3_catalog.gd)、[完整结果](../tests/qa/round3_catalog.json)、[日志](../tests/qa/round3_catalog.log)：

- 默认空hook：全部目录物品购买、锻体、海克斯抽池均原子拒绝，不改变金钱/随机状态/快照。
- 只提供 `stats.v1`：不能买铁刃；提供其他全部声明但移除AP和recovery：AP物品、两类药仍拒绝。
- 即使把19项草案要求的所有hook名称都声明，unsupported状态仍使其不可用；五轮实际数据抽选无草案混入。
- 已购买数值物品在能力移除后停止投影并给出warning；新模型恢复存档保持空能力，已有物品效果不激活，也不能继续购买。
- legacy Model接收playable_prototype目录时返回catalog_adapter_required，不能绕过适配器门禁。
- 在**新catalog模型**用950金买450金铁刃→卖405→买900金锻体后剩5，撤销出售被原子拒绝；已付费三选结果、RNG、账本及余额保持，确认新锻体路径也保留QA-001修复。

重要边界：`catalog_model.gd:13-14` 的 `set_supported_hooks()`接受可信宿主声明，没有能力运行验证器；`:17-21` 的availability由声明与status算出。独立测试也证明声明AD后即可通过数据购买/投影，**这本身不表示存在任何真实战斗消费者**。当前代码/文档明确说明了这点，默认也关闭，故不把这个可信接口本身列为新缺陷。最终宿主若无条件复制测试的全量hook列表，则将是新的集成问题：应逐个核对基础属性重算、实际伤害消费（尤其AP）、HP/CD保持、战斗regen、治疗预检/扣药/去重恢复事务，再开放能力。24项数值海克斯也不能冒充19项未实现机制草案。

QA-002仍OPEN：收到战斗/集成修复SHA后复跑真实跨房事件复现；本轮未修改功能代码，也未把缺少最终整合SHA当作等待理由。

### 第三轮复现

在QA工作树设置 `XDG_CACHE_HOME=/tmp/qa-cache XDG_CONFIG_HOME=/tmp/qa-config XDG_DATA_HOME=/tmp/qa-data`：

- `godot --headless --path /workspace/shuabao-qa --script tests/qa/round3_qa001.gd`
- `QA_MODEL_ROOT=/workspace/shuabao-progression-fix QA_BASELINE=e022b456007287b40828d45f3363634c749f3e42 QA_ECONOMY_REPORT=/workspace/shuabao-qa/tests/qa/round3_economy_fix.json godot --headless --path /workspace/shuabao-qa --script tests/qa/round2_economy.gd`
- 第二次经济复跑将根目录换成 `/workspace/shuabao-catalog`，基线与报告文件名相应替换，保留历史结果。
- `godot --headless --path /workspace/shuabao-catalog --script /workspace/shuabao-qa/tests/qa/round3_catalog.gd`（资源根必须指向catalog提交；脚本和产物仍在QA目录。）
