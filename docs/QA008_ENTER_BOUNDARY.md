# QA008：Enter 房间快捷键与 GUI 焦点归属

独立QA在a294复现：K→学习Q→Esc→Enter会同时开始战斗并重开修习。原宿主在_unhandled_input开始房间，而已恢复焦点的修习按钮仍处理同一ui_accept键周期。

修复在宿主输入层完成：

- 无模态且准备/胜利阶段，仅当焦点为空或在开始按钮时，Enter/小键盘Enter由宿主接管完整按下、echo重复和松开周期，且只开始一房。
- 移除未处理事件中的重复开始入口。焦点位于其他按钮或面板内时，Enter保留GUI键盘激活用途，不再穿透为开战命令。
- 安全阶段关闭面板后将焦点交给开始按钮；初始安全阶段同样聚焦开始。战场HUD建立显式Tab/Shift+Tab循环，修习、补给、技能和六个装备槽均可到达。模态内部继续使用原有独立焦点循环。
- 输入焦点丢失会清理宿主键锁；已有Space自救完整键周期处理保留。

通过真实MCP创建、保存、运行测试，使用Godot InputEvent，不是OS级测试。输入边界fixture关闭AI，并人为设置一次胜利以独立测试下一房按键；不将这段测试冒充实际清怪。药品/构筑自然输入流程另行在相同最终源码上复跑。

红版9项中5项失败。第一次修复后开战冲突已消除，但Tab到达修习失败，促成显式HUD焦点循环；随后9项全部通过，且既有Space/HUD边界5项通过。最终补充初始焦点检查后10项全部通过；相同最终源码的药品自然11项与消费者103项也重新通过。结果与原始回执见[证据](validation/enter-boundary/reports.json)。早期一次读取在异步测试完成前得到null，不算通过；复跑等待完整结果。

```sh
.local/blender-mcp-venv/bin/python scripts/mcp/check.py --fresh-fixture --workflow scripts/mcp/enter_boundary.json --evidence .local/qa008-recheck
```

请独立窗口QA固定交付SHA复验原始复现、Enter/小键盘Enter短长按、Tab选按钮后激活、键盘关闭面板及攻击隔离。未把此引擎事件回归代替独立OS级放行。
