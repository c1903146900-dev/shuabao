# 001验收映射

原任务来源：接收目录roadmap_review/auxiliary_extracted_full.txt，001段（原表E2:M2）。最新所需工具.md允许等效自动化、不强制Better Terrain。

| 原要求 | 落实与证据 | 结论/范围 |
| --- | --- | --- |
| 独立目录，不碰旧工程 | 新路径shaheyouxi_project；runtime/data/shaheyouxi_experiment_20261004 | 本工程独立；无旧档兼容承诺 |
| 版本管理首稳定提交 | Git main从6258a3a起，后续分项提交与修复保留 | 已做 |
| Godot工程启动/关闭 | headless导入/启动exit0；GUI截图和正常退出0 | 4.6.3基础生命周期已测；非可玩版本 |
| 三份权威引用 | authorities/manifest.json有正式ID/字节大小/原件缺失状态 | 引用完整；原字节阻止002正式导入，不伪造 |
| 状态/登记/预览/源/测试/构建目录 | 各独立目录与README | 已建，不代表资产已制作 |
| Godot MCP | 173工具，项目绝对路径、16515、退出0、端口关闭 | 守卫补丁前后均留证据；默认连接失败关闭 |
| GdUnit4可用 | 官方6.2.1，3/3正例exit0；独立故意失败exit100 | 框架可用，不等于005完整测试体系 |
| Better Terrain隔离评估 | 最新工具要求明确非必需 | 留后续地形任务适用性评估，不安装重复框架 |
| 专业派单与读回 | 独立只读审查，多项问题真实发现/修复 | 已运行；最终复核待登记 |
| 旧岗位/缓存模板 | 新工程不复制旧72提示词/6 Skill或旧状态 | 不是当前环境必需项，不假称拥有 |

## 当前结论
001工程候选已实测，等待独立最终复核与主控记录。不能用此页把002正式数据、联机、存档、玩法写成通过。

## 证据
- evidence/001_verification_runs.json：完整命令、PID、时间和退出码；导入不带桥绑定时禁用标记true
- evidence/001_gdunit_positive.log与gdunit_positive.xml：3/3，0错误/失败/跳过/孤儿
- evidence/001_gdunit_fault.log与gdunit_fault.xml：明确故意失败，exit100
- evidence/bootstrap_gui_20261004.png与gui_lifecycle.log：正常启动和关闭
- evidence/mcp_20261004T160210705255Z.json：守卫后精确路径、173工具、正常退出、端口关闭
- evidence/editor_guarded_20261004.png：实际编辑器画面
- evidence/source_gate_tests_20261004.log：12个负例；source_gate_check_20261004.log：真实缺原件拒绝

限制：无音频设备导致dummy回落，Vulkan探测错误但GL显示正常；这不构成音频、GPU性能或正式平台通过。初次默认用户目录不可写崩溃与修复后的隔离成功分别留档。
