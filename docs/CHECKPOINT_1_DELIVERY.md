# checkpoint 1 构建与交接

构建源码/配置：`085aaa046724871badd2c8df10119911009d860e`。包含可操作单房间 `27495e6863893d8e0f4bb9a01efdda7895156377`、QA-002修复 `5168f6c3a76dd5126f9bd2022a258e1c7c4a150c`、成长目录合并 `e6667f9e8e7500988761158eaf3b846adeafa5f3`。本报告之后只有证据/文档更新，不能将较早的未修复包混用。

## 实际包组成

| 平台 | 程序 | PCK | 解压后程序+PCK | ZIP |
| --- | ---: | ---: | ---: | ---: |
| Windows x86_64 | 104659456 | 15005852 | 119665308 | 51063320 |
| Linux x86_64 | 71075864 | 15005900 | 86081764 | 42222133 |

全部为字节。每个ZIP有程序、对应PCK、README-先读.txt、FONT_LICENSE.txt共4个文件。原始分发目录只有程序与PCK；PCK内也携带字体许可。文件名、每项SHA256和ZIP清单见 [archive-manifest](validation/checkpoint-1-export/archive-manifest.json) 及 [程序校验值](validation/checkpoint-1-export/SHA256SUMS)。

- `build/checkpoint-1/shuabao-checkpoint1-windows-085aaa0.zip`
- `build/checkpoint-1/shuabao-checkpoint1-linux-085aaa0.zip`

两个PCK各47项，包含运行时脚本字节码/remap、默认试炼场景、风厉及三类敌人的导入动画资源、Noto字体/许可、确认技能规则、Godot运行所需导入资源和索引。没有addons开发插件、MCP客户端脚本、tests、docs、preview截图视频、Blender源文件、编辑器或shader缓存、构建工具。Godot的打包场景/导入资源是运行依赖，不能误删为编辑器缓存。`loadout_fixture.gdc` 是当前CombatSim静态依赖，仍随包存在；整合启动即替换为真实成长模型，未给玩家使用其6级初值。尚未接线的prototype catalog不入此包。

## 验证状态

| 检查 | 状态与证据边界 |
| --- | --- |
| Windows实际导出 | PASS；PE32+ x86_64，文件存在且校验完成 |
| Windows程序执行/窗口输入 | NOT_RUN；无Windows执行环境 |
| Linux实际导出 | PASS；ELF x86_64 |
| Linux独立无头启动 | PASS；源码目录外、无DISPLAY/WAYLAND_DISPLAY，10帧退出，实际打印整合就绪，无脚本错误；不是联机专服验收 |
| 包内容/凭据特征检查 | PASS；实际解包校验47项/包，禁止开发目录；已跟踪文件及包字节特征扫描0发现。特征扫描不能证明绝不存在任何秘密 |
| 修复后整合MCP | PASS；重跑30步、9项输入路由断言通过，已查看实战截图；不是窗口级输入或Windows验收 |
| QA-002 | 本任务35项回归+原364项+运行应用内MCP35项通过，独立QA复验待交接 |
| 全房胜利/完整成长/联机/存档 | NOT_RUN或未实现；不能称完整游戏 |

首次选定资源导出漏掉继承脚本，Linux启动失败；保留失败证据，随后改为显式运行资源白名单并重建。`scripts/export/check.sh` 真正调用引擎构建，并不把MCP export_project返回命令当成功。

## Library交付状态

本轮按当前Library技能的受支持批量流程保存先前请求的3个美术评审文件及2个ZIP，在连接阶段报网络错误，尚未上传。五个文件均无library_file_id，未生成可分享链接，未绕过该失败采用其他上传端点；不能声称父对话已收到照片或安装包。文件可在当前云环境上述路径访问；其他新任务请从已推送源码按MCP_HANDOFF及导出脚本复建，或待Library恢复后使用同一受支持流程物化/传输。

3个待交付美术文件仍在 `assets/fengli/preview/quality/arena_v2.png`、`actions_before_after.jpg`、`attack_before_after.mp4`。没有公开Release、部署、付费服务或修改仓库可见性。

下一阶段先由独立QA复验上述修复及默认整合入口，再接已交付的真实UI成长控制器；逐项实现实际属性/恢复hook才注册能力，不能用目录测试开启全部效果。完整窗口级矩阵维持未通过。
