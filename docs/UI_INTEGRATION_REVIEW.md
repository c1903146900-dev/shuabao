# UI 首版独立集成审阅

来源提交 `d02a4e8510e280fe50f6ec8a63750e655994d7bb`；合并提交 `f3ae831c017346dbaa29dac21ce679465e5b29ff`。范围仅 scripts/ui、scenes/ui、assets/ui、tests/ui 和 docs/UI_PROGRESS.md。没有改默认入口、战斗代码或成长模型，没有实现成长 controller；后续接线由 UI 任务在其目录继续。

## 代码与接口审阅

- adapter.present 深拷贝快照，request_emitted 携带 actor_id、command_id、state_revision；feedback 和 show_result 只驱动展示。HUD 本体不推进 HP/CD/经验/技能点。demo 内有明确的演示数据模拟，不能当作成长模型或战斗权威。
- HUD 不暂停 SceneTree；模态遮罩与 Control 消费鼠标事件。战斗端必须使用合适的未处理输入路径，或显式检查 blocks_gameplay_input；HUD 无法撤回战斗先行执行的轮询攻击。未接战斗，不能据 UI 单测宣称实际不会误攻击。
- 18点/11候选/R1+2+2显示与现规则一致；R后两阶正式门槛由权威返回拒绝原因。fixture 的短CD和高等级只是演示。成长接口映射已登记，但 fixture 的“撤销本场”不是 model.undo_skill 的“撤销最新一笔”；UI 下一轮必须按原文修正，不由集成方擅自循环撤销或代接 controller。
- 字体为 NotoSansCJKsc-Regular.otf（16437340字节），随仓库有 Debian 来源与 SIL OFL 1.1 许可。真实发行包用到字体时须携带许可；本轮未构建新发行包，不能以仓库有许可代称最终包已含许可。

## 验收边界

这次复核调用标准 MCP 客户端，在独立副本运行现有 UI verify 工作流。没有替换原生工具或直接脚本制作场景。源码主入口保持非战斗骨架；UI demo 与 progression demo 均是独立诊断/展示入口。

UI 测试使用引擎 Input.parse_input_event 的合成输入，覆盖事件路由与控件响应；它不是物理键鼠操作，不是完成真实敌人击杀、战斗HP/CD冻结、成长账本保持或发行客户端可玩性验收。12次开关测试也不能替代可玩集成矩阵中20次交错开关/按住松开/窗口失焦等全用例。

后续接口重点：协调层保留唯一成长模型与 adapter；将真实快照映射至UI，不通过重建对象刷新CD或重授点；slot_index 映射实际物品 uid；奖励/阶段/关ID仅由权威提供；命令回执中的外部副作用消费需要幂等。模型已合入的不可逆消费撤销修复见 PROGRESSION_INTEGRATION_REVIEW.md。

## 本轮实际结果

独立运行24步MCP工作流全部通过；1920×1080和960×540各29项断言、0失败，六张PNG实际尺寸与请求一致。已打开主HUD、修习及结算截图检查中文与边缘：主状态和按钮可读，窄窗辅助说明偏小，修习遮罩对背景的压暗符合当前模态设计；不宣称无障碍字号或复杂战斗遮挡已验收。get_editor_errors返回0，驱动环境告警仍单列。主项目 scripts/check.sh 实际通过，默认入口和战斗目录与集成前一致。证据见 [ui-integration](validation/ui-integration/manifest.json)。
