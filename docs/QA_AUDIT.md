# 独立 QA 审查（2026-09-30）

当前结论（第七轮，2026-10-01）：**固定main c1b20bc8的QA-008 Enter/小键盘完整键周期已获OS窗口回归通过；自然药品治疗/满血拒绝/两次上限与跨房重置、HP/AS/CDR消费者及一个纯数值海克斯已独立验证。未发现新的已确认玩法缺陷。** 长MCP会话超时未归因，较短构筑会话正常完成；测试基础设施异常与每项证据边界见第七轮。Windows/导出包、完整技能与视觉仍非最终放行范围。没有修改 main 或任何功能文件；内容仅在 `qa/independent-audit` 的 `tests/qa` 与本文档，没有发布部署或接触用户电脑/阿里服务器。

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

## 第四轮：固定main checkpoint真实窗口验收（2026-10-01）

**唯一被测主线：`a3dd6b47af52b652d293ccc74197060628a6a316`**，包含QA002修复 `5168f6c3a76dd5126f9bd2022a258e1c7c4a150c`。独立只读工作树 `/workspace/shuabao-checkpoint`；没有使用主集成尚在制作的新controller或其他未提供SHA。

执行环境恢复成功，preflight核对Godot4.6.3、Blender4.3.2及显示依赖。复用项目本地固定MCP源码和SDK，未扩权。实际完成标准ClientSession→stdio initialize/tools/list/tools/call→Godot/Blender GUI链路。全部工作流step无工具/应用错误，Godot编辑器日志无Script/Parse Error；启动前几次未连接ready、既有Blender status缺config仍单独记录。标准客户端完成后清理当次GUI/服务。

QA源码仅在本QA分支 `tests/qa`，报告仅本文件；checkpoint工作树git状态干净。MCP隔离fixture内将主场景挂到一个继承原 `scripts/integration/room.gd` 的QA观测脚本，不改变被测room/HUD/战斗/材质逻辑。

### 已知缺陷在实际main的复测

- **QA-001 PASS（源码层）**：直接加载main的 `scripts/progression/model.gd`，原100→买→卖→锻体→撤销序列返回insufficient_gold，仍40金、空背包、锻体1条、撤销账本2条，完整快照不变。这是实际main模型，不是feature分支或复制算法。main还没有实际商店窗口接线，不能称窗口购物通过。
- **QA-002 PASS（源码层）**：原E1先杀最后目标→自然封房→下一房无输入的重现已消失；原旧cast回放也无效。额外检查E1自然结束周边0.135/0.139/0.140/0.141/0.145真实秒，以及无E1的R1 impact周边0.295/0.299/0.300/0.301/0.305真实秒。impact前旧目标1000、impact后旧目标952符合时机，但所有下一房目标均保持1000、世界倍率1。相同房间impact重复回调也未重伤。
- 第二轮Q2目标丢失、P2活动E3一次性重置信用、E3跨房冻结续行、R1/R2正常结束/生命周期终止/演出后真死亡边界，同脚本改为加载main后无失败；仅新增报告路径参数，未改期望或复制逻辑。

证据：[round4_models.json](../tests/qa/round4_models.json)、[脚本](../tests/qa/round4_models.gd)、[第二轮边界在main的结果](../tests/qa/round4_combat_boundaries.json)。手动生命周期结束与真实伤害死亡分列，没有把大招免疫期间的致命请求当成实际死亡。

### QA-003：一次Space同时自救并打开修习面板（P2，真实窗口复现）

位置：`scripts/integration/room.gd:99-100` 处理自救后调用close_panels，`scripts/ui/combat_hud.gd:308-315`恢复/设置allocation按钮焦点；同一Space的ui_accept按钮释放行为没有被隔离。

重现：敌人真实攻击令玩家downed→鼠标在空场→Esc关闭结算→Space一次按下/松开。实际事件只有一次self_rescue，但在同次输入之后 `phase=combat`、`self_rescue_used=true`、修习面板重新打开。连续观测里生命由自救84继续受敌攻击降至48；用户没有按K/点击修习。预期Space完成一次自救，不再触发UI按钮。

证据：[汇总space字段](../tests/qa/round4_window_report.json)、[原始step18 MCP回执](../tests/qa/evidence/round4-window/step-18-execute_game_script.json)、[已亲自查看的截图](../tests/qa/evidence/round4-window/step-19-get_game_screenshot-0.png)、[XTest输入日志](../tests/qa/evidence/round4-window/os-input.json)。这不是“复活两次”，而是一次输入触发两个不同动作。等待新controller后复跑同焦点顺序。

### QA-004：按住W仅经过HUD即永久丢失当前移动输入（P2，真实窗口复现）

位置：`room.gd:117-118`在 `live_hud.blocks_gameplay_input()` 时清held_keys；该函数在 `combat_hud.gd:342-343` 对任何HUD悬停Control都返回true，不限模态面板。

重现：按住W移动→鼠标移入修习按钮→仍按住W移回空场。实际物理键状态仍true，held_keys已空；离开UI后连续采样位置固定 `z=-1.799999`，直到松键重新按下才可能恢复。预期即便悬停期间按约定阻断，移出后应能恢复持续按键，不能丢掉用户尚未松开的输入。

证据：[hover_latch_loss_frames](../tests/qa/round4_window_report.json)、[step03回执](../tests/qa/evidence/round4-window/step-03-execute_game_script.json)。没有把焦点外松键的旧测试结果泛化为HUD悬停正常。

### QA-005：活动/可重施/冻结状态错误显示就绪（P2，运行期复现）

位置：`room.gd:169-171`只提交rank/cooldown，所有已学技能reason硬编码就绪，没有活动阶段、重施窗口或战斗phase；`combat_hud.gd:240-246`仅用CD覆盖文字。

- OS E触发E3后，实际overload_left=6.98、E CD0，HUD仍“超载 / 就绪”，并非技能已结束可以再次开启。
- E2 cast_state.e2仍存在、旋斩未结束，HUD已“就绪”。
- R2 presenting=true或轮次1续施窗口中，HUD始终“就绪”，没有演出/续投区别。
- 补测E1实际marked、expires约5.215时，HUD仍“追踪匕首 / 就绪”，没有标记二段提示。
- victory冻结后Shift仍“就绪”。模拟实际上拒绝冻结动作；这里是UI事实与可用性回显问题，不是证明技能能突破冻结。

证据：[active_ui字段](../tests/qa/round4_window_report.json)、[E1 marked回执摘录](../tests/qa/round4_followup_report.json)、[胜利冻结截图](../tests/qa/evidence/round4-window/step-22-get_game_screenshot-0.png)。未对仍未定的数值作缺陷判断。

### QA-006：E2/R2动作被集成逐帧idle覆盖（P2，运行期复现）

位置：`scripts/actors/actor_view.gd:128-136`将e2_spin/r2_throw映射为attack/ultimate，但集成 `room.gd:177`的hero_clip事件表漏掉两者；`:198-224`逐帧从idle开始重选并play/seek，覆盖视图刚收到的动作。

OS输入E2/R2确实生成技能事件、状态和伤害。QA每0.05秒在原super._physics_process及_animate之后采样实际AnimationPlayer：E2 cast_state存在期间全为idle；R2 presenting=true期间也全为idle。E3对照能采到overload，说明并非所有采样都只能看到idle。期望当前已存在的attack/ultimate动作能在对应技能段播放，不被另一所有者立刻覆盖。没有提出新的美术动作设计要求。

证据：[animation与active_ui字段](../tests/qa/round4_window_report.json)、原始 [E2回执](../tests/qa/evidence/round4-window/step-12-execute_game_script.json) / [R2回执](../tests/qa/evidence/round4-window/step-15-execute_game_script.json)。这些是实际游戏帧动画状态，不以施法结束后的单张静态截图证明动画全过程。

### QA-007：导入GLB没有绑定现有受击闪白材质（P3，受击当帧实证）

位置：`actor_view.gd:27,76`初始化/更新白盒material；`:154-165`替换为GLB时移除原网格，却没有把此闪白通道绑定到新网格。受击事件`:130`仍只设置flash_left。

补测使用真实敌人攻击，命中事件amount18/world_time0.855发生当帧，英雄flash_left=0.12；遍历该实例41个可见GLB MeshInstance3D的material_override及active surface material，匹配闪白material的绑定数为0。敌人实例29网格也为0。因此该受击计时/材质更新不会作用于导入外观。期望保留已存在的可见受击闪白效果或等价绑定；**不是声称所有受击反馈都不存在**，HP、伤害标签与其他动作另有渠道。

证据：[hitbindings](../tests/qa/round4_followup_report.json)、[受击当帧记录的原始MCP回执](../tests/qa/evidence/round4-followup-window/step-03-execute_game_script.json)。这条记录发生在实际hero_damaged之后，不是仅静态猜测或空场截图。

### 窗口正例与验收边界

本轮使用Linux XTest将输入送到真实窗口，MCP只负责准备fixture/读回/截图；没有引擎内Input.parse_input_event冒充OS输入。准备明确简化：敌人数量/HP、AI开关、初始英雄HP、自救是否已用、技能装配点数为测试夹具；随后普攻/技能、击杀、受伤、倒地、自救、真死亡及F5由窗口输入/真实模拟推进。**不声称自然完成整局、通过UI学全技能、拿奖励升级或真人手感**。

- 普攻胜利：OS左键触发两次32伤害，64HP靶子死亡、一次kill并胜利；已查看结算截图。
- 倒地：准备低血后真实敌人攻击→downed；Space自救事件真实发生，但QA-003失败。
- 真死亡：单列自救已使用fixture，真实敌人致命攻击→true_dead；[死亡截图](../tests/qa/evidence/round4-followup-window/step-10-get_game_screenshot-0.png)已查看。没有把该fixture当成玩家自然耗尽整局自救次数。
- 胜利后及真死亡后分别通过Esc/F5真实按键进入preparation，无敌人；F5是已公开的全新局，不是保留旧局成长的retry验收。
- 面板20次K/Esc开关实测panel_opens=20；第一次先按住攻击再开面板并在面板内松开。面板打开帧attacking均false；只出现开始前和全部关闭后新按键产生的两次attack_started，没有松开补发/面板穿透。点数仍1；本用例未点击学习，故不推断重复扣点/成长订阅全部通过。
- 战后墙钟 **61.4976秒**，完整hero快照（含CD）及world_time相同。不是直接调用step(60)的模型检查；截图/界面可以继续显示，不驱动战斗时钟。
- main明确显示奖励未接入，实际金钱/经验仍0、等级1。正式杀敌奖励、成长hook/装备海克斯战斗消费者、恢复事务、30%正式经验死亡罚款均不能因本轮通过而标完成。
- 截图实际1228×690（嵌入窗口），不是1280×720/1920×1080双分辨率验收。Windows没有执行环境，**NOT_RUN**；本轮是Linux编辑器运行，不是Linux导出包复测。

完整窗口汇总：[round4_window_report.json](../tests/qa/round4_window_report.json)、[补测汇总](../tests/qa/round4_followup_report.json)。输入：[round4_input.py](../tests/qa/round4_input.py)；观测器：[round4_window_harness.gd](../tests/qa/round4_window_harness.gd)。两个build工作流分别保留该轮当时传入的观测脚本，不依赖热重载成功，均独立重启后运行窗口测试。

### 第四轮复现入口

依赖目录用项目内symlink复用前轮安装的固定上游源码/SDK；checkpoint标准 `scripts/mcp/check.py` 自带data/tests复制支持。依次运行QA目录的 `round4_build.json` → 独立重启跑 `round4_window.json`，并行启动 `round4_input.py <新证据目录>`。补测同理使用 `round4_followup_build.json` → `round4_followup_window.json`，输入驱动第二参数传 `round4_followup_stages.json`。每次证据目录必须全新，不能误读旧step作为准备完成信号。脚本不直连插件socket。

新controller/集成SHA到达前不关闭QA-003至007，不将本固定checkpoint结果套用于正在修改的主集成。没有发布或部署。

## 第五轮：15e694e2独立窗口回归（2026-10-01）

唯一基线：`15e694e2e260953076d37cc81cf0c23eaa658487`，工作树 `/workspace/shuabao-checkpoint2`。与第四轮a3dd固定证据分目录保留；没有切到正在开发的奖励/两房循环版本。未修改任何功能源，checkpoint2 git状态干净。

### 本轮可关闭的缺陷与通过的范围

- **QA-001/002在实际main再次PASS**：同一独立模型脚本执行负钱包原序列、E1自然封房、旧R1回调、邻接真实时间边界与下一房敌人HP检查；P2/E3/Q2等第二轮邻接机制也重新加载本main，无失败。证据：[round5_models.json](../tests/qa/round5_models.json)、[round5_combat_boundaries.json](../tests/qa/round5_combat_boundaries.json)。仅新增输出路径参数，未改断言来适配修复。
- **QA-004真实窗口PASS**：同样按住W→移入修习按钮→移出空场，物理W按住但held W丢失的采样帧为0；全程继续移动至z=-9.000015，对照a3dd停在z=-1.799999。没有用直接修改move_intent替代输入。
- **QA-003真实窗口PASS**：真实敌人造成downed，Esc关闭结算后一次Space短按，只产生一次self_rescue，之后所有combat帧无意外修习面板。另一次新fixture重复同焦点序列、Space按住0.85秒，实际收到5次echo自动重复及最终release，仍只有一次self_rescue、无意外面板。两张 [短按截图](../tests/qa/evidence/round5-window/step-10-get_game_screenshot-0.png) / [长按截图](../tests/qa/evidence/round5-window/step-13-get_game_screenshot-0.png) 已亲自查看。生命继续被敌人正常攻击减少不作为失败；本次修复的是误开UI，不是给予额外无敌。
- **20次面板压力PASS（该路径）**：沿用同一XTest脚本20次K/Esc开关，首次攻击按住跨面板、面板内释放，关闭后新按键再次攻击；面板内attacking为false，没有额外attack_started或释放补发。没有用此结果替代UI学习/交易扣款去重测试。
- **胜利冻结/重开PASS（该路径）**：窗口左键完成64HP目标击杀，胜利后实际墙钟61.4619秒，hero完整状态及world_time不变；Esc/F5回preparation且无敌人。

完整复核：[round5_window_report.json](../tests/qa/round5_window_report.json)、[独立验证脚本](../tests/qa/round5_verify.py)、[OS输入日志](../tests/qa/evidence/round5-window/os-input.json)。MCP build与运行步骤均无application_error；独立重启后验证，GUI与服务已清理。默认复用第四轮观测器；长按用相同death准备函数，仅改变真实窗口Space按住时长，没有改变被测功能或初始场景条件。

### 仍不能通过的内容

`4dd32d412fa8a6be01efea2a7b3ba082b2ca6afb` controller文件已合入，但本main入口 `integration/room.gd` 仍使用原CombatHUD及ledger_bridge，不是新成长demo/controller。父任务也明确当前hooks关闭、完整循环待接。UI源码入仓、demo自测、能力flag不能算真实奖励/成长/药品/装备/海克斯战斗消费者完成。

QA-005技能阶段回显、QA-006 E2/R2动画覆盖、QA-007 GLB闪白仍OPEN：本提交diff没有这些修复；本轮未重复宣称全部视觉问题已修。Windows执行、Linux导出包、双分辨率、自然全局获奖升级、完整两房循环均不在本轮通过范围。第四轮fixture与窗口输入的区分继续适用。

复現：`round5_build.json`经checkpoint2标准MCP客户端创建隔离观测器；独立重启跑 `round5_window.json`，同时运行 `round4_input.py <新证据目录> round5_stages.json`。模型脚本使用 `QA_MODEL_REPORT` / `QA_COMBAT_REPORT` 指向本轮QA报告文件。所有产物仅QA分支，未发布部署。

## 第六轮：a294d042真实两房整合（2026-10-01）

唯一基线 `a294d0420f5b5a23027d94755a9f78509b6929b4`，实际工作树 `/workspace/shuabao-checkpoint3`；已打印SHA、确认无功能改动、默认入口 `res://scenes/integration/room.tscn` 使用 `scripts/integration/room.gd`。本轮不以旧QA001/002、成长目录或作者输入回归代替验收。观测器 `round6_observer.gd` 不改生命、敌人、技能、AI、账本或时钟；键鼠来自Linux XTest真实窗口，标准MCP负责构建隔离副本、读回及截图。

### QA-008：Enter进房同时重新打开修习面板（P2，窗口复现）

最小路径：默认新局→K→鼠标学习Q1→Esc关闭→Enter。预期一个按键按既定输入策略处理，不能在开始战斗的同时意外弹出面板。实际进入第1房且 `phase=combat`，但 `panel_open=true`；后续Q/左键无法施放，敌人继续攻击直至倒地。本轮没有设置低血或直接调用开房/战斗方法。

定位：`scripts/integration/room.gd:155` 将Enter交给start_room，但没有完整键周期归属；`scripts/ui/combat_hud.gd:308-315` 关闭时把焦点恢复至allocation，`:87` 的Button pressed又打开修习。符合先前Space类输入双重消费形态，但Enter是尚未覆盖的入口；不重复重报已修Space问题。

证据：`evidence/round6-window/os-input.json`记录完整OS键周期；`step-05-execute_game_script.json`已学Q、面板打开；`step-06-execute_game_script.json`记录Esc/Enter之后combat+面板打开；到`step-18`真实敌人造成downed且无attack_started/q1事件。`os-samples.json`保留initial/learned/unexpected_terminal_room1，`step-24-get_game_screenshot-0.png`倒地截图已亲自查看。该首轮在缺陷成立后主动中断MCP客户端（exit130），不称整套完成；另起干净会话用鼠标进房继续独立两房路径。

### 测试自身异常的隔离

首个完整两房会话 `evidence/round6-two-room` 已取得自然两房、自救、真死亡样本，但第203步发生 `Runtime request timed out`，未走到F5。期间QA错误地在同一MCP fixture并行启动了无头集成类测试，后者加载同一运行插件；这可能干扰运行连接，不把此次超时定性为游戏逻辑缺陷。已保留整个失败会话，并以 `round6-two-room-final` 独占GUI/MCP重新执行全部窗口路径。

补充集成夹具首版在直接伤害后未推进胜利检查、也未等待自救免伤结束，导致购买仍处战斗期及第二次伤害无效。保留 `round6_boundaries_fixture_error.json/.log`；修正为推进真实simulation.step、明确断言victory/true_dead前置，再作交易及处罚判断。不是修改功能或把失败断言删掉。最初从未导入资源的checkout无头启动还遇到GLB预加载失败；最终使用由标准客户端完整导入的隔离副本，其关键功能源SHA256与a294检出逐一相同，见`round6_baseline.json`。无头测试与OS会话最终顺序执行，不再争用MCP运行连接。

### 本轮亲自完成的OS窗口路径

以独占会话 `evidence/round6-two-room-final` 为最终证据，`os-finish.json` 达到done。没有引擎内Input.parse_input_event，没有直接授XP、修改血量、关AI、造敌人或调用战斗方法来完成这些路径：

- K→鼠标学习Q1→Esc→鼠标点击进房，左键及Q实际清完第一房；3个不同击杀身份到账450金币、180总经验，Lv2/本级80，升级获得1点。
- 战后实测 **62.416秒**，完整hero快照和world_time相同；普攻CD **0.338235秒**确实被冻结，不是只验证全零CD。再用窗口升级Q到2级、P打开商店、点击铁刃，450金币全部支付，实际AD32→40，HP及CD保持冻结值。
- 鼠标进入第二种布阵，同一账本保留技能、装备与奖励ID；读回时已走0.45战斗秒，CD按经过时间继续而不是场外补走。第二房仅左键，命中记录为40/40/40/24/24/24，末击24是目标剩余生命，不是AD失效；真实敌人造成伤害，结束HP204.1925。累计6个唯一奖励，金币450，Lv3/本级135。
- 第三房继续真实普攻；OS观察间隔内已击杀2个，随后放开鼠标，不把预想的“杀1个”写成实际结果。累计8条奖励，金币750，Lv4/本级105、可用2点。自然倒地未扣经验；Esc后Space自救一次，无意外面板；下一次自然致死仅扣本级经验 **105→73**，Lv4、金币750、技能、装备与点数保持。
- 真死亡后实测 **62.603秒**，hero及world_time不变。Esc/F5窗口续战，仍是同一第3房，enemy_7/8保持死亡，未重新生成或再给钱；8条奖励和死亡处罚ID保留。活着时再按两次F5也不加钱、不改经验。读回HP84.4325及84.8575包括续战后的正常自然恢复，不把35%初值84与稍后读回差异误报为回血缺陷。
- 每个具名快照核对HUD的钱、经验、等级、点数与账本一致；观察到的等级内，剩余点+已投入成本=授予等级数，死亡不降级或回收技能。没有以这些低等级窗口样本冒充自然玩到18级。

[窗口独立验证](../tests/qa/round6_window_report.json)、[完整具名样本](../tests/qa/evidence/round6-two-room-final/os-samples.json)、[OS输入时间线](../tests/qa/evidence/round6-two-room-final/os-input.json)。亲自查看了真实MCP [第一房结算图](../tests/qa/evidence/round6-two-room-final/step-45-get_game_screenshot-0.png)，以及X窗口即时抓取的 [F5续战图](../tests/qa/evidence/round6-two-room-final/os-retry.png)；后者的抓取方法与时间另在os-retry-capture.json。另已查看前个会话的战斗/真死亡MCP图。截图为编辑器嵌入窗口1228×690（OS抓取窗口约1228×691），不是1280×720/1920×1080双尺寸验收。

### 与窗口路径分开标记的边界夹具

`round6_boundaries.gd`实例化a294真实integration/room及其真实模型，暂停自动physics后显式调用原模拟接口，不复制奖励/交易算法。纯夹具伤害用于：活目标不得领奖；胜利后重复击杀/结算回调保持完整账本；下一房拒绝旧房奖励；同一死亡敌人重复致命伤害不再给钱；倒地、自救免伤结束后的真死亡、重复终止与重试防刷。

OS购买时英雄满血，不能证明缺血不补满；因此另设 **HP71、Q CD4** 夹具，原购买接口+原成长完成回调+反复投影，确认HP71、Q CD4、AD40不变；换房继续保留。该结论不混写为自然窗口缺血购物。

目前新增确认缺陷为 **QA-008 Enter输入归属**，见 [结构化最小复现](../tests/qa/round6_enter_report.json)。药品、锻体、海克斯仍按本checkpoint明确关闭；本轮只验铁刃AD消费者，不把stats flag扩张为所有装备或机制已实现。技能全部候选阶段、全套新HUD组合、20次面板压力、Windows及新导出包仍未在a294本轮完整重跑。QA-005本版有映射改动，不能沿用旧结论称全部仍失败，也不能仅凭源码将全部阶段关闭；QA-006/007仍按checkpoint公开说明未修。

补充的a294级别上限夹具独立执行固定种子分批XP奖励直至18级；每笔唯一奖励与不同command重复同reward身份交错，始终授点数=等级且不超过18，最终18点；携带额外points字段的奖励原子拒绝。证据 [边界结果](../tests/qa/round6_boundaries.json)，明确不是OS玩到18级。最终无头边界与OS验证的failures均为空，但不因此关闭QA-008或未测平台/技能组合。

最终标准MCP工作流正常到 `MCP_CHECK_COMPLETE`，338条预设步骤完成，所有workflow业务回执无application_error；这里只说明工作流结束，不以工具数量代替质量。具名retry样本之后游戏仍在继续，后续空闲再次死亡属于另一个时刻，不能用后续截图冒充第一次F5状态。显示、应用和当次Xauthority均已清理。复现时先运行 `round6_build.json`（fresh fixture），独立重启后运行 `round6_window.json`，同时执行 `round6_input.py <全新证据目录>`；查看OS样本并运行 `round6_verify.py`（默认final目录）。无头 `round6_boundaries.gd` 必须在GUI/MCP会话完全结束后运行。

## 第七轮：c1b20bc8药品与数值构筑独立窗口QA（2026-10-01）

唯一被测提交 **`c1b20bc8da414452c113936b26ce9a4874bb733d`**，实际工作树`/workspace/shuabao-checkpoint4`；已打印SHA、git状态干净、默认入口仍为`res://scenes/integration/room.tscn`。读取了`QA008_ENTER_BOUNDARY.md`、`INTEGRATION_CHECKPOINT_3.md`，关键原功能源与MCP副本SHA256一致，见[基线记录](../tests/qa/round7_baseline.json)。仅新增QA观测脚本与OS驱动，没有修改功能代码。

### QA-008：本提交对应OS路径通过，可关闭该缺陷

K→鼠标学Q→Esc→Enter短按：只开始第1房，没有重开修习。小键盘Enter长按、普通Enter长按各实际收到 **5次echo**，按下/重复/松开没有重复进房；小键盘Enter短按也通过。此前仅引擎InputEvent的修复现已获得独立OS窗口证据。

初始安全焦点经Tab到修习，Enter只打开GUI而不开始战斗；Esc关面板后可以继续正确进房。**一个新Enter键周期在战斗中激活当前聚焦的修习按钮，是本版明确保留的GUI键盘用途，不是同一周期双重消费。** 首个驱动在长按结束后又发送两个新周期，把合法GUI打开误列为unexpected；保留`round7-window`和`round7_input_first.py`，纠正测试预期后在`round7-sustain`分别观测长按独占、后续GUI激活及Esc关闭，没有改游戏。

### 自然药品OS路径：亲自跑到第5房

全部金币来自窗口左键/Q实际击杀，未直接加钱/XP、改血、关AI或模拟点击游戏API。房号是两种布阵重复，不是新增地图。标准MCP只建隔离观测器、运行、读回、截图；真实按键、鼠标点击与商店滚轮由Linux XTest发送。

- 前3房获奖后购买血晶：最大生命 **240→340**，当时受伤HP **153.7125保持不变**，已有CD不刷新。铁刃由第一房真实收入购买，不是预置装备。
- 买4份普通药堆一槽；持有普通药时买特殊药返回`recovery_mutex`，金币/库存/次数账本原子不变。
- 安全胜利阶段通过六槽“使用”按钮，HP **153.7125→214.9125→276.1125→337.3125→340**，前三次各+61.2，末次仅补剩余缺口；每次消耗1份，CD不变。实际自然损血高于驱动预估，四份全部用完，初段在尝试出售不存在余药时停止。未将该预估失败算游戏bug，也未篡改HP；在同一冻结账本接续OS操作，再买一份，满血使用返回`full_health`，HP/CD及完整库存账本不变，然后真实出售。
- 第4房等待真实敌人攻击至HP92.58，再用普攻/Q清房，结束 **HP75.2375**；买3份特殊药各占一槽，使用前共5个装备/药品槽。
- 特殊药第一次HP **177.2375**，第二次 **279.2375**，各+102；次数0→1→2。第三次仍未满血，明确返回`special_cap`，生命、CD、金币、库存、次数不变。
- Enter进入第5房：次数重置0，剩余那1份库存没有补充或丢失。战斗中打开行装，“使用”按钮禁用，OS点击不产生新的消费回执，库存不变；HP随真实战斗自然恢复/受伤，不错误要求活战斗HP静止。
- 第5房真实清完后，剩余特殊药成功使用，HP **227.5775→329.5775**，次数变1。证明跨房重置后真实治疗，不只是检查一个计数字段。

证据：[OS具名样本](../tests/qa/evidence/round7-sustain/os-samples.json)、[连续输入日志](../tests/qa/evidence/round7-sustain/os-input.json)、[独立验证结果](../tests/qa/round7_window_report.json)。`round7_resume.py`在同一场景继续药品步骤，未重置账本；初段样本与结束状态分别保留`os-samples-first-segment.json`、`os-finish-first-segment.json`。亲自查看 [第5房真实战斗MCP图](../tests/qa/evidence/round7-sustain/step-253-get_game_screenshot-0.png)，可见实际受伤、40点伤害、铁刃/血晶/剩余特殊药。

### 独立自然构筑OS路径：AS、CDR、纯数值海克斯

另起新局`round7-build-window`，靠自然击杀与窗口购物完成，不接续失败会话或恢复fixture账本。实际完成5房：

- 机簧让真实AS **1.7→1.904**，购买时HP223.35和已有CD不变。
- 冷凝核心让真实CDR **0→0.06**，购买时HP224.4825与已有CD不变；新房窗口Shift实际冲刺，剩余CD与`3.2×0.94−已过战斗时间`一致。
- 鼠标切海克斯页、选第一张真实候选，抽到`fengli_quick_draw`，AS **1.904→2.21**，HP与已有CD仍不回填。后续真实按住左键普攻的事件间隔按实际AS核对，不只看UI数字。
- [构筑具名样本](../tests/qa/evidence/round7-build-window/os-samples.json)、[OS输入](../tests/qa/evidence/round7-build-window/os-input.json)。亲自查看 [最终房结算MCP图](../tests/qa/evidence/round7-build-window/step-78-get_game_screenshot-0.png)，可见铁刃、机簧、冷凝核心及冻结中的Shift冷却。

### 补充边界的输入类型与范围

`round7_boundaries.gd`使用c1b20真实Room/Consumer/Model，显式金币/HP/伤害夹具；**不是自然OS操作**。覆盖准备态/战斗态/战斗与模型阶段不一致拒绝、成功与失败请求重放、重建消费者不重复治疗、特殊药次数在同房真死亡重试保持而新房重置、普通5份一槽与第6份拒绝、六槽满后不能买药、出售余药换另一类不能绕过本房使用互斥。

另在HP71、Q CD4条件下反复实际买血晶→卖→撤销出售→撤销买入，HP和CD不变；六件机簧把实际AS限制为2.5而不改已开始CD。仅7个无依赖数值海克斯可用；有技能依赖的条目由实际support拒绝。**本版没有开放依赖项休眠政策，不能将拒绝路径写成“休眠效果已实现/通过”。** 第三次特殊药、正常治疗、满血与跨房重置既有OS证据也有分开的夹具补充；没有用夹具替代前述玩家链路。

### 本轮未完成与基础设施异常

药品长会话在已完成第5房治疗、准备后续买机簧时，第267步标准MCP返回`Runtime request timed out`；此时没有并行Godot测试，原因未定位。保留原回执与应用日志，**不把后续构筑判通过，也不把超时定性为游戏缺陷**。因此另跑较短构筑会话，并把观测返回的输入/事件/回执历史限制为最近96/160/16条；原始逐步MCP回执持续保存，不修改游戏状态。该结果也说明第六轮对超时原因的并行干扰推测尚未证实，不能当根因结论。

本轮窗口核心路径已覆盖，但Windows/导出包、1280×720与1920×1080双分辨率、全部7海克斯逐项数值、全部技能/属性组合未测；OS截图仍为Linux编辑器嵌入窗口。F5药品次数、六槽拒绝、买卖撤销/训练洗点防回血CD主要是明确标注的集成夹具。旧QA-006/007视觉问题不是本提交修复范围，不因本轮核心通过而关闭或宣布最终完整可玩放行。

最终补充夹具还验证了已学习Q在真实训练洗点后变为未学，但HP71与正在转的Q CD4保持，结果见 [round7_boundaries.json](../tests/qa/round7_boundaries.json)。这与OS缺血买血晶不回血相互补充，不混称窗口洗点验收。所有本轮具名核心断言无失败；未对未开放依赖海克斯宣称休眠测试通过。

构筑OS脚本已写入`completed=true`、捕获done后，退出清理阶段发生一次脚本自身别名冲突（步骤简写C覆盖ctypes别名，XCloseDisplay参数声明失败）。保留实际执行的`round7_build_input_executed.py`和`os-driver.log`；复跑脚本改名capture_step，未改已执行操作或证据。该非零退出不抹掉已完成输入与读回，也不称脚本全程零错误。标准MCP后续正常到MCP_CHECK_COMPLETE并清理当次应用/显示/Xauthority。

复跑：先用本SHA标准客户端运行`round7_build.json`建立只读观测器，独立重启执行`round7_window.json`与`round7_input.py`；药品自然受伤会变化，不能假定固定份数必定留药，应据实际读回调整OS步骤，本次接续脚本为`round7_resume.py`。构筑用`round7_build2.json`→独立重启`round7_build_window.json`，并行OS驱动`round7_build_input.py`。全部GUI结束后再顺序运行`round7_boundaries.gd`，不并行开启加载同一MCP插件的Godot进程。`round7_verify.py`使用本次具名结果目录；原长会话超时保持原始失败记录，不改写成完整通过。
