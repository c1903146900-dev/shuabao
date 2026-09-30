# 初始化状态与交接

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
