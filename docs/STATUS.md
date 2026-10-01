# 初始化状态与交接

最新阶段：[药品与最小数值构筑 checkpoint 3](INTEGRATION_CHECKPOINT_3.md)，已验证MCP自然输入与受控机制检查，独立窗口QA及新发行包仍待完成。下列checkpoint2及更早包为历史记录。


最新进展：默认入口升级为[两房真实奖励成长 checkpoint 2](INTEGRATION_CHECKPOINT_2.md)。本轮MCP引擎输入通过与独立窗口QA待验明确分开；以下历史checkpoint1及导出包结果不代表本版已导出。

> 最新集成状态：骨骼 GLB 经 MCP 导入 Godot 播放、干净 clone 复用、Windows/Linux 实际导出通过；Linux 独立无头启动通过，Windows 启动未运行。见 [集成验收](INTEGRATION_VALIDATION.md)。下文为历史阶段记录。

> 最新接入结果：标准 MCP SDK 客户端已完成两服务握手、工具调用和动画往返，见 [可复用 MCP 客户端](MCP_CLIENT.md)。下文保留此前阶段记录。

> 后续复核：图形入口与部分网络访问已验证可用；MCP 仍待宿主接入。最新证据见 [MCP 与图形接入复核](MCP_HANDOFF.md)。以下保留初始化阶段的历史结果。

日期：2026-09-30。本任务只初始化项目，不实现完整游戏。

## 交付范围

最小 Godot 3D 白盒启动场景、中文 README、设计/计划/决策/工具链文档、忽略规则和 CLI 检查脚本。没有第三方插件、下载资产、内部研究笔记或凭据进入仓库。`.uid` 为 Godot 源文件标识，应提交；生成缓存不提交。

## 验证矩阵

| 检查 | 状态 | 证据与边界 |
| --- | --- | --- |
| 本地仓库和 origin | 通过 | `/workspace/shuabao`；origin 为 `https://github.com/c1903146900-dev/shuabao.git`；初始 work 分支 unborn，远端无 refs |
| Godot 版本 | 通过 | `4.6.3.stable.official.7d41c59c4` |
| 编辑器无头导入 | 通过 | `bash scripts/check.sh`，导入退出 0、无 ERROR/SCRIPT ERROR |
| 最小场景无头启动 | 通过 | 同一脚本，输出 `SHUABAO_BOOT_OK`，退出 0 |
| Blender 后台运行 | 通过 | `blender -b --factory-startup --python-expr 'import bpy; print("BLENDER_RUNTIME_OK", bpy.app.version_string)'` 输出 4.3.2、退出 0；仅二进制运行检查 |
| 缓存/本地资料忽略 | 通过 | `git check-ignore` 命中 `.local/checks/boot.log` 和 `.godot/editor/project_metadata.cfg` |
| Library 基线 | 失败 | 已解析文件 ID，签名下载被代理 403；一次明确 `/workspace/shuabao/.local/baseline` 目标重试仍失败，无可读 ZIP，未解包未阅读 |
| Godot/Blender MCP 查询与场景动画往返 | 未运行（阻塞） | 当前助手未暴露相关工具，CLI 无服务器配置；平台没有已确认的动态本地接入通道 |
| 可见运行/中文排版/鼠标键盘交互 | 未运行（阻塞） | 无显示会话，不将无头通过解释为画面通过 |
| Windows 客户端/Linux 专服导出 | 未运行 | 未发现导出模板，未生成或检查任何导出文件；尚无专服实现 |
| 云服务器/部署 | 未运行 | 本任务范围明确排除 |

CLI 日志在忽略目录 `.local/checks/`，下次可重新运行脚本生成。首次直接查版本出现不可写 fontconfig 缓存告警，检查脚本将 XDG cache/data/config 放入项目 `.local` 后运行正常，不修改用户电脑或用户主目录。

## 附件溯源

Library ID：`libfile_137d44c0b4c08191bc25116c300fc08b`；服务返回 file ID `file_000000006d7c8210b3342e3639fc897e`，文件名 `game_design_baseline_v0_1.zip`，声明大小 14846 字节。本地未取得，不能验证实际字节、哈希或四份文档内容。以后消费者必须在自己的环境重新物化，不依赖此任务路径。签名 URL 不入库。

## 下一任务建议

1. 在受支持环境物化并核验附件，补全基线，保留最新 18 点规则及所有未确认项。
2. 平台提供真正 MCP 挂载与图形会话后，仅接入指定两套 MCP，完成应用查询、场景/动画保存重读及可见运行。需要安装或持久授权时明确范围后确认。
3. 独立交接风厉单人战斗白盒；确认输入和招式，约定一个训练目标验收。暂不展开第一幕全流程与六英雄。

初始提交与远端 main 的最终 SHA 在任务交付消息中记录，避免文档自引用提交哈希。后续可用 `git rev-parse HEAD` 与 `git ls-remote origin refs/heads/main` 对照。

## 首个单房间整合 checkpoint

默认入口已切换为 `scenes/integration/room.tscn`。实际1级1点技能选择、GLB敌人/风厉、真实HP/CD HUD与战斗接线完成；9项MCP输入链路检查通过，实测8击杀后倒地，非胜利通关。独立QA窗口输入、完整成长目录/控制器和新入口导出仍待完成。见 [checkpoint说明](INTEGRATION_CHECKPOINT_1.md)。较早的“只有骨架/未战斗”记录仅描述当时版本。

QA-002修复已推送，成长目录v2已合并但能力全关；Windows/Linux已从085aaa0实际重建，Linux独立无头启动通过，Windows执行未运行。包内容审计通过；Library连接网络失败，无新ID。详见 [checkpoint构建交接](CHECKPOINT_1_DELIVERY.md)。

## 2026-10-01恢复开发小阶段

UI真实成长controller已在当前main模型上完成106项复核并合入，但默认游戏尚未绑定该controller。两个输入问题有实际红绿回归：HUD悬停不再打断W，空格自救完整周期不误开修习；5项边界检查通过。见 [本阶段交接](RESUME_CHECKPOINT_20261001.md)。其余反馈/动画疑点与完整成长循环继续分阶段处理，未启用目录hook，未重建安装包。
