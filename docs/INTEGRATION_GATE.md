# 集成与测试包回归门槛

## 美术 v1 集成结果

已审阅 `main...9fea8dfb739f3abab25367329ee9e1f8f34516fb`（相对共同祖先的变更），仅新增 assets/arena、assets/fengli、scenes/art 和 docs/ART_PROGRESS.md，无删除或战斗目录改动。合并提交 `239e44e0c30756aab1cfad02f279ab3736a8aa4e`。不能用两个分支末端的直接 diff，将美术分支尚未包含的 main 新文件误判为删除。

实际 GLB 解析确认 19 关节、九个约定动画；通过 MCP 启动合入后的 showcase 场景，九动作均读到 13 条轨道，逐个姿态查询成功。run 两次运行采样从 0.0774 秒变为 0.2125 秒，手臂、大腿、小腿骨骼四元数变化。实际截图确认人物、两类敌人占位及地块显示。19 次工作流工具调用无错误，证据见 [验证目录](validation/art-integration/manifest.json)。

初次调用发生在场景尚未完成启动时，inspect_art 查询失败；增加启动等待并用输出日志核对资源加载后通过。软件渲染冷启动不能按 12 秒必然就绪处理。没有修改美术模型、动画名或评审代码。图形启动仍有驱动/Vulkan 探测及嵌入窗口诊断，不能宣称所有日志零错误；九动作查询和实际图形通过不代表最终动作质量或战斗判定通过。

## 执行顺序

1. fetch 指定提交；按共同祖先审阅路径、规则和资产合同，不取代其他任务正在工作的分支。
2. 无冲突合并到 main；保持正式战斗目录的作者分工，不修改未完成分支。
3. `python3 scripts/mcp/preflight.py`，必要时 `bash scripts/mcp/setup.sh`。
4. `.local/blender-mcp-venv/bin/python scripts/mcp/check.py --fresh-fixture --workflow scripts/mcp/art_review.json --evidence .local/art-integration-evidence`，读取每次返回及实际截图。工作流通过 MCP 操作应用；检验程序仅复制隔离文件、启动、记录和清理。
5. `bash scripts/export/check.sh` 实际构建两个平台、启动 Linux，并自动运行 `scripts/export/audit.py`。将报告、哈希和启动结果入 docs；二进制留 build，临时工作流日志留 .local。
6. 确认 Windows 启动是否真的执行。未运行必须保留标记。未来 combat 集成后需增加战斗回归，不能用美术展示或启动标记代替。
7. 检查 staged 差异再提交并非强制推送 main；记录远端 SHA 与包校验值。测试包使用 Library 私有交付，不创建公开 Release，不部署。

## 发行边界

目前两个 preset 都选择 main.tscn 及其依赖，include_filter 为空。exclude_filter 额外排除 docs、MCP/导出/验证脚本、addons、assets 下 source/preview，以及 blend、制作 Python、日志、视频、Markdown、ZIP。不依赖排除字符串推断结果：审计实际 PCK 目录，每个条目核验 MD5/尺寸/偏移，拒绝开发目录、凭据路径、源码制作材料；未知或加密包格式失败退出。

PCK 内允许 Godot 运行时所需的 .godot/exported 场景、.godot/imported 转换资源（若有依赖）、UID 映射和类表。它们不同于不应入包的编辑器状态、着色器缓存、Node/Python 源码构建缓存。当前包不包含美术评审场景或英雄 GLB，因为主场景尚未接入它们；不要将其标为风厉战斗演示包。美术文件保留原路径，未通过删除源文件或证据解决打包问题。

当前目录精确包含每平台一个可执行文件和一个同名 PCK，无额外文件。最新构建清单见 [package-audit.json](validation/art-integration/package-audit.json)：

| 平台 | 可执行文件字节 | PCK 字节 | 合计字节 |
| --- | ---: | ---: | ---: |
| Windows | 104659456 | 10128 | 104669584 |
| Linux | 71075864 | 10176 | 71086040 |

两 PCK 各 7 项：编译 main.scn、global_script_class_cache.cfg、uid_cache.bin、project.binary、main.tscn.remap、main.gd.remap、编译 main.gdc。报告保存精确路径及各项 SHA-256。Linux 独立无显示启动通过；Windows PE 文件验证通过，Windows 启动未运行。

## 凭据扫描范围

审计只读仓库跟踪文件和分发包字节，不读取用户配置、环境变量或账号凭据。检测私钥内容、GitHub token、AWS access ID、明显密钥赋值和签名 URL。此次无匹配；有限规则不构成“绝无任何敏感信息”的数学证明。仅有 PEM 标记的引擎内置解析字符串不算私钥，规则要求标记后有换行及实际编码内容。反例测试确认伪凭据与禁止目录会被拦截。若命中只记录路径和规则，不输出疑似秘密原文。

Library 交付须等待实际上传成功回执；发现工具不等于传输成功。包签名、Windows 实机、联机战斗和外部部署均不在本轮已通过范围。
