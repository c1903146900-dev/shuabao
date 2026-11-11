# G28 断后炮台世界表现：独立源码草案

状态：静态合同 59/59 通过。没有启动引擎或 GUI，没有 GDScript 解析、类型检查、fixture 执行、截图或首层自然游玩验收。因此不能合入或视为可玩通过版。

## 真实缺口与现有消费者

- 基线：`source/rebuild_20261106/dash_trail01/runtime`，父任务标识 PCK `4112ebb6`。
- `common_hex_runtime.gd:381–385` 在正常 Shift 结束时，将炮台写入真实 `turrets` 数组，位置来自该次冲刺起点。`867–877` 使用现有世界时间更新寿命和发射间隔，直接向原规则选中的最近敌人排入伤害，没有 G28 飞行实体或飞行速度。
- 原 `common_hex_bridge._apply` 先提交伤害，再转发事件，不创建世界节点。风厉表现层的实体绘制实际读取英雄、敌人、死亡残影、敌方 `sim.projectiles`、英雄 `wind_projectiles` 和骨钉 `ultimates.nails`，没有把通用运行时的炮台实体接到画面。
- 不是“完全没有命中反馈”：原 `hit_reaction.accept` 已消费 G28 的正数伤害，原 HP 条、死亡处理也已覆盖。新的实现不重复添加目标命中火花、受伤动画或伤害文字。
- 已用现有 decoder 读取公开运行包 `hex.bin`、`g20.bin`、`machine_templates.bin`，三者均逐字节 roundtrip。G28 已批准、权重 100、无技能依赖、无远程限制，所需 hook 存在，未受 G17/G21 的特殊 hold 限制。这里只证明原首层候选链和 Shift 触发条件可达，没有声称自然抽选或游玩已跑通。

## 两项实际源码改动

1. `changes/fengli_route_20261024/turret_view.gd`：只读炮台实体；按原位置和 `left > 0` 显示小型友方机械图形。每帧重新读取实体，原数组删除、寿命结束、换代、离开战斗或英雄死亡即隐藏。
2. `changes/fengli_route_20261024/presentation.gd`：接入同步事件、清理边界和原脚点深度排序。炮台不参与角色选取、碰撞或操作。

发射反馈只接受原 bridge 正在 drain 的 G28 伤害对应的已提交 `damage` 回调，保留真实 `source_position`、目标位置、cast、event ID、伤害和 sequence。整条细线在命中回调时同时出现，仅以原世界时钟淡出 0.12 秒，没有飞行头、预计命中时间或二次目标命中特效。炮身和线条共用中性炮口视觉偏移，偏移不写回世界位置。

保持内部 Common run ID 与外层 route run ID 的既有差异：分别校验原效果的 Common 身份与外层事件的 route 身份，不制造错误的新身份绑定。

没有修改规则、伤害、原数值、范围、索敌、冷却、时钟、资产、守卫、manifest 或 PCK；没有混入 G10 战魂草案。G11/G16 炮弹/导弹不在本次实现范围。

## 检查与后续

- `tests/check_static.py`：只做源码/字节/patch 合同检查。当前 59/59 通过，包含原 manifest 的全部绑定源未变、两文件隔离、原发射与寿命链、真实提交事件证明、无模拟写入、无新增范围或时钟、深度和清理接线、patch 精确应用。
- `tests/observe_turrets.gd`：未运行的显式选择 fixture。准备检查真实 Shift 创建、原点和 TTL、真实发射回调、视图无写入、暂停、重复/伪造通知拒绝、反馈过期、源清除、换代、死亡和战斗结束。不是自动入口，不启动引擎，不放宽守卫。
- 后续必须在原受保护流程中先解析与执行 fixture，再验证炮身遮挡、炮口起点、敌我可读性、暂停/恢复、最终一次炮台射击和自然首层。视觉锚点和静态合同都不替代运行验收。
- 本目录保留 `SOURCE_HASHES.json`、`RULE_EVIDENCE.json`、`STATIC_QA.json` 和 `turret_view.patch`。父任务如需封装，应只封独立候选；共享 presentation 与其他草案的合并必须另做检查，不能拿此静态结果当作组合版本验收。

## Parent sealing result

Pure Python resealing passed with 258 bindings; candidate PCK SHA256 bf909091de42b35360337cc4a53aac7fdc04b88486234ef2f6b250ec8bf3a201. All gameplay files remain byte-identical to passed 4112ebb6. This is still unrun and not selected. No guard or engine operation was performed. G10 and dash-attack visual candidates are not included.
