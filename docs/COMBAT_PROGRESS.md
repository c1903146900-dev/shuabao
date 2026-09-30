# 风厉单人战斗原型进度

首个可运行阶段，2026-09-30；基线 d7d1161，分支 feature/fengli-combat。没有改 main、project.godot、主入口、工具目录、UI目录或美术资产。

## 运行

Godot 4.6.3 打开 `scenes/combat/fengli_arena.tscn`，F6运行当前场景；或 `godot --path . scenes/combat/fengli_arena.tscn`。WASD移动、鼠标瞄准、左键长剑攻击、Shift冲刺、Q1/E3/R1、P3初档预置。H隐藏临时调试HUD，F5明确开始**全新测试局**；倒地后空格使用本局一次自救。该场景独立于主入口。

普通/精英/测试Boss追击、锁定地面圆预警、Boss扇形攻击、受击数字/击退、死亡及胜利冻结已可运行。模型是白盒，正式模型不依赖；角色有 `Visual/AnimationPlayer` 适配口。无碰撞物理体，当前边界是权威模拟平面矩形夹限，敌人软分离；后续场景障碍需要独立的合法落点/导航接入，不把夹限冒充复杂地形碰撞。

## 实际验收

已按 docs/MCP_CLIENT.md 在本任务环境安装固定源码，官方 Python MCP SDK → stdio initialize/tools/list/tools/call → GUI插件。Godot 173工具、Blender36工具应用查询成功。场景/脚本/运行/截图/模拟输入均为真实MCP工具调用；不是仅安装或CLI启动。

- MCP创建7个实现脚本及测试脚本，创建/打开/挂载/保存独立场景，重启编辑器后运行。
- Godot运行时通过MCP执行核心测试：**104/104**，证据 `tests/combat/evidence/core-stage/step-08-execute_game_script.json`。
- 同测试可无头复查：`XDG_DATA_HOME="$PWD/.local/data" XDG_CACHE_HOME="$PWD/.local/cache" XDG_CONFIG_HOME="$PWD/.local/config" godot --headless --path . --script tests/combat/runner.gd`。
- 覆盖Q1几何/去重/退款/4层/助攻不刷新/最后击杀；E3全基础效果/真伤/续时/结束计CD/帧长一致；P3三档阈值；R1圆/Boss/严格5%/演出免伤/冷却；防御/暴击/吸血/韧性/上限；房间60秒冻结及死亡事务；移动/冲刺/边界；单层世界减速；单次自救/真死亡XP。
- MCP键盘W与E/Q、鼠标移动和左键已调用并读取前后快照。截图含竞技场、Boss预警、大招。还未完整覆盖每个方向与Shift/R输入的独立断言，不能说全键鼠验收已完。
- 初轮104项曾有5个计时精度失败，已修正浮点到零边界后重新全部通过；真实失败日志留于忽略目录.local。首次MCP新场景保存因缺父目录失败，建立目录后重试通过。
- 上游已知Blender addon status缺config、Godot保存进度队列/退出XServer/驱动探测诊断仍存在；未修改工具源码掩盖。无游戏脚本解析错误，软件渲染不代表目标GPU性能。

## 数据、策略与接口

`data/combat/tuning.gd` 分列 CONFIRMED、INITIAL、TEST_RANKS、POLICIES。单位米/秒，模型固定5ms模拟tick，世界与大招演出时钟分离。初始生命240、AD32、移速6、攻速1.7；攻击1AD、2.8×2.6米、前摇0.1秒；Shift4.2米/0.16秒/CD3.2秒；无自带攻击或无敌。技能空间与动作不是已定值。

显式暂定解释：Q1每层基础加算30%，每次施法命中仅减一次完整有效CD的30%，仅该cast致死计击杀，每次最多涨一层；0.2世界秒宽限，最后一击封房时先结束归因事务。E3真伤以暴击后防御前普通攻击量25%计算，不触发吸血；E3/P3仅本单人致死归因，不暗改助攻。E3减Shift与CDR相乘、只作用新冲刺，不更改正在转的CD；无续时上限。R1以施法者位置为中心半径10米，Boss与普通目标同样严格低于5%才斩杀。P3只改本局增量，不改基础AD或局外值。

P1/P2已在模拟中保留初步实现但尚未专项验收；三档2/4/6%吸血、7/11/15%回血及120/100/80秒CD是**新测试表**，不是已批准三档。P2活动Q/E重置暂定不取消活动状态，给一次结束免CD信用；不得靠重复E3叠两份状态。Q/E/R后续档均为数值成长测试值，尚未做升级集成验收。

- `CombatSimulation.request_action(action, aim, command_id)` 返回accepted/reason/cast_id；重复command_id不重复施法。
- `step(real_delta)` 唯一推进入口；`snapshot()` 返回深拷贝；`combat_event`、`state_changed`、`encounter_finished`给表现/UI接入。
- 事件含sequence、combat_level_id、world_time，伤害分ordinary/true、source/cast_id/target。hero快照提供HP/CD/loadout/ranks/状态，敌人包含预警形状、固定目标点与进度。
- 视图和HUD不反写伤害；显示关闭不影响模拟。普通敌人击退，Boss击退转硬直0.12/强度、阈值1、0.65秒为测试值。

## 战后状态表

HP、所有CD、Q1层、E3剩余时间、P3进度/本局AD、待决状态、控制状态全部冻结，等待不回血、不按墙钟补算。大招演出令牌清理；若封房强制结束R1演出，在结束事务中进入R冷却后冻结。Q1最后击杀先提交归因再封房。跨房保留策略仍待设计确认，本实现只提供冻结快照，不默认全部清除。

## 未完成

Q2/Q3/E1/E2/R2扩展正在草稿中；P1/P2专项、点数账本与战斗集成、完整11候选验收、全部键鼠输入、短演示仍待完成。死亡时序暂定首次致死倒地/按空格35%HP自救并1秒无敌，下一次真死扣经验进度30%；这些时序/恢复值是测试初值。无装备/海克斯/奖励经济/四幕/联机/生产导航/正式美术整合/性能结论。此次未执行客户端导出；主线已有导出验收不等于本战斗场景已导出。

已只读参考 main abb91cf 的 CLOUD_REPRO.md 及美术9fea8df 的 ART_PROGRESS.md：后续GLB正前-Z、脚底原点、Visual子节点，动画按AnimationPlayer递归发现；伤害绝不依赖动画轨道。主任务统一集成资产，本分支不改它们。
