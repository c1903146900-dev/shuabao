# 表现与音效接线 checkpoint（第 1–3 项）

基线是 `c1b20bc8da414452c113936b26ce9a4874bb733d`。独立玩法 QA 的报告为 `712ecec3e07ababcdf241becaff40ac0eebcdc84`，它验收的是该基线，不自动覆盖本次改动或未来导出包。

## 已接入

- 美术 `b5bcc203668f8c4771fb595d2995bba0de34fd93`，独立合并 `18ff3aa2501c31f28b39db3e25ecc2f73fc009b1`。
- 原创音效 `00bd1141113f8a581ef19be28f589a71dbe0f46d`，独立合并 `8796b1339b59513b668627ef1cead2bb9eac7be1`。
- 集成场景的 ActorView 禁用自主动画播放，唯一姿态采样入口为 room._animate。补齐 E2 旋斩与 R2 投掷；E2/R2 按世界时间，R1 按模拟器的演出剩余时间采样。战后活体姿态冻结；死亡动画允许完成。
- 导入 GLB 的每个 MeshInstance3D 接入该角色独享的闪白覆盖材质。结束时恢复原 overlay，不修改共享 GLB 原始材质。闪白是 0.12 秒表现反馈，不参与伤害计算。
- 音效路由由真实 combat_event、成长 command_completed、唯一结算及实际升级触发。普通攻击、命中、受伤、击杀、Q、E3、R1、E2/R2、冲刺都有映射；R1 伤害包不重复叠加命中音。伤害音按房间/施法/世界时间聚合，避免群体与 E3 额外包重复。
- 持续攻击失败轮询不发拒绝音；显式输入失败与 UI 完成结果分别发拒绝/确认音。战斗 sequence 去重；最近 UI 命令去重缓存上限 256、伤害分组缓存上限 128、诊断历史上限 64。
- 音频模块保持全局 8 路、同类 2 路、40ms 间隔，过量丢弃。主界面有静音按钮，静音立即停止所有声音，弹出面板时隐藏按钮。

## 验证及边界

源文件经真实 Godot MCP create_script 写入并运行后同步回仓库；没有用直接执行软件脚本替代 MCP 创作。MCP validate_script 对已有 class_name CombatAudio 会报告“hides a global script class”（工具临时脚本重复注册），因此该文件以实际项目加载、运行和 142 项组件测试验证，不将那次工具调用记为通过。

`docs/validation/presentation` 保存 16 项受控接线检查、GLB 闪白前后真实窗口截图、资源残留日志及动画合同比对。16 项包含 E2/R2 不覆盖、R1 时间源、冻结姿态、真实网格绑定/实例隔离/恢复、UI 学习确认、显式失败、轮询静默、战斗重放抑制、受伤、GUI 静音与 8 路上限。该套件明确使用受控战斗夹具，不能代替真实游玩。闪白截图为放大观察，测试相机 size=12；正式相机未据此更改。

独立读取旧/新 GLB 的动画轨道目标、插值和 input/output accessor 数据：风厉 9、普通 7、精英 7、Boss 8，共 31 动画保持一致。网格外观变化另通过 Godot 实际图片查看；未据此声称完整美术审美验收。

音效测试使用 Dummy 驱动：142 项行为断言通过，但未试听，不能评价音质。退出仍报告 ObjectDB 泄漏和 12 个 WAV 资源残留。verbose 指向 AudioStreamPlaybackWAV 持有引用；stop_all 后解除 player.stream、清空资源表仍未消除。根因尚未归因到引擎或组件，不隐去此错误，不宣称修复。需继续验证真实音频后端和长期反复启停。

复测受控表现：

```sh
.local/blender-mcp-venv/bin/python scripts/mcp/check.py --fresh-fixture --workflow scripts/mcp/presentation.json --evidence .local/presentation-recheck
```

必须检查 presentation_report 的 failures，而非只看 MCP isError。

两房实际 InputEvent 流程新增复测 12 项全部通过；真实播放记录包含 6 次击杀、2 次升级、2 次结算，以及攻击/命中/受伤/Q/UI 的播放器启动。第一次旧坐标助手未关闭面板、未进入战斗，明确记失败；修正后的独立 presentation_input 测试通过 Viewport final_transform 将 HUD 逻辑坐标换算为 1228×690 实际窗口坐标，未改玩法。此输入是 Godot InputEvent，不冒称操作系统输入。

项目导入及主场景无头启动也通过。

## 未交付

第 4 项完整的本提交药品/输入回归尚未重跑；先前独立 QA 基线结论保持原适用范围。第 5 项新 Windows/Linux 包、Linux运行和包内容审计未完成，旧 build 不代表本次改动。第 6 项真实窗口连续游玩录像未录制。音效动态资源需要在下一次导出明确收录，不能依赖静态依赖扫描。没有上传 Library、发布 Release 或部署。

后续音频诊断已由 `85b14d33` 完成并在集成端复跑；参见 [DELIVERY_WORKFLOW.md](DELIVERY_WORKFLOW.md) 的生命周期增量。上文保留 checkpoint 当时的未解决记录。
