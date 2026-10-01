# 恢复开发首个小阶段：UI兼容性与输入边界

基线 `a3dd6b47af52b652d293ccc74197060628a6a316`。UI成长controller分支4dd32d4已合并并推送于 `354feca4211c94cbfb6373a800ed3c5c5571f5e2`，其当前main模型兼容性与106项回归见 [UI审阅](UI_CONTROLLER_INTEGRATION_REVIEW.md)。Godot/Blender MCP恢复后均通过真实initialize、tools/list和应用查询，没有额外安装或扩大权限。

## 两个实际复现与修复

- 普通生命HUD悬停：旧版按住W后移入HUD即清空held_keys，角色停止。现在只有模态清理移动；普通HUD仍阻挡鼠标攻击，但不打断移动键。面板打开时模拟时钟仍前进，面板内松开W后关闭不会自动续走。
- 空格自救完整周期：关闭倒地结算后，修习按钮持有焦点。旧版实际自救成功，但按下/松开后误打开修习；不是“未执行自救”。现在宿主在GUI接受事件前接管自救按下与匹配松开，不让按钮同时处理ui_accept。

通过真实MCP创建测试、编辑room.gd、验证语法，并独立重启运行；修复前3项中2项失败，修复后加入两个模态邻接检查共5项全部通过。已查看修复前后的实际1280×720截图：旧版恢复HP但误开面板，新版恢复HP且留在战场。测试使用Godot InputEvent经实际GUI/未处理事件路径，不是OS级XTest。AI关闭及伤害调用只用于准备输入边界，不能冒称自然战斗、玩家击杀或真人手感验收。首次结果读取使用不受支持的JSON类表达式失败；保留回执，随后改为受支持的get_meta读回。

- [结构化红绿结果](validation/input-boundaries/reports.json)
- [修复前截图](validation/input-boundaries/red-readback/step-04-get_game_screenshot-0.png)
- [修复后截图](validation/input-boundaries/green/step-04-get_game_screenshot-0.png)
- 主项目Godot导入/无头启动通过。工作流：`scripts/mcp/input_boundaries.json`，使用当前源码重新创建/同步隔离副本后运行。

## 下一阶段与未完成项

本阶段没有把成长demo接成默认游戏，没有打开任何目录hook，没有重建发行包；此前085aaa0包不包含本次输入修复。动作失败/持续/重施/锁定/冻结到HUD的反馈，以及e2_spin/R2动作覆盖、导入GLB受击闪白仍待运行复现与修复。随后才接真实击杀奖励、技能升级、安全商店、药品和数值海克斯；19机制草案保持关闭，不通过测试flag全开假装完成。

QA-002修复仍为main中的5168f6c，独立QA由父任务安排复验。本阶段不把MCP输入路由检查替代完整窗口级可玩验收矩阵。
