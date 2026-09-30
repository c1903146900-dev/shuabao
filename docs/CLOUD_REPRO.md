# 新云任务复用工具链

本流程在 shuabao 云环境的独立干净 clone 已执行通过，验证代码提交为 `20be58282ad9a9f9ba93c89d11e7a207b6ce1511`。没有复制原 checkout 的 `.local`；两套 MCP 源码、Node 依赖、Python 虚拟环境均重新安装。它验证的是同一云基础环境中的新 clone，不是空白操作系统安装。

## 基础环境要求

需在可执行 shell 的环境中已有 Python 3.11+、git、Node 18+/npm、uv、Godot 4.6.3、Blender 4.3.2、Xorg、发行版 dummy 显示驱动、xauth、xdpyinfo、ImageMagick 的 `import`。`preflight.py` 检查命令、引擎版本与驱动文件；不安装系统软件。Xorg 配置随仓库提供，无需依赖本任务的 `/etc/X11/xorg.conf`。缺项时先按输出核对官方或发行版来源，在项目授权范围内补齐；不要跳过版本检查。

## 完整执行顺序

```sh
git clone https://github.com/c1903146900-dev/shuabao.git shuabao
cd shuabao
python3 scripts/mcp/preflight.py
bash scripts/mcp/setup.sh
.local/blender-mcp-venv/bin/python scripts/mcp/check.py \
  --fresh-fixture --workflow scripts/mcp/animation_probe.json \
  --evidence .local/mcp-basic-evidence
.local/blender-mcp-venv/bin/python scripts/mcp/check.py \
  --fresh-fixture --workflow scripts/mcp/glb_probe.json \
  --evidence .local/glb-evidence
python3 scripts/export/install_templates.py
bash scripts/export/check.sh
```

两次 MCP 验收顺序执行，不能并发占用同一显示 `:97`、Godot `127.0.0.1:6505` 和 Blender `localhost:9876`。显示已有进程时脚本拒绝启动，不要杀掉其他任务。客户端通过标准 MCP SDK 的 stdio 会话执行 initialize、tools/list、tools/call；应用内制作全部经 MCP 工具。每次完成后清理当次应用和服务，不设置开机启动或持久用户权限。

`setup.sh` 固定两套已选 MCP 源码提交和依赖，不会下载整包技能或付费服务。`{{ROOT}}` 在工作流运行时替换成当前 checkout 根目录。`--fresh-fixture` 将已有隔离副本改名保留；源码游戏不被验收场景覆盖。证据目录中的 initialize、工具列表、逐步返回、截图和日志应留存，不能只看进程退出码。

模板安装从 Godot 官方 GitHub release 下载约 1.26 GB 的完整 TPZ，校验公布的 SHA-256，仅解包 Windows/Linux x86_64 模板到项目 `.local/data`。预留下载、解包、两个应用和 clone 所需磁盘空间。网络失败留下 `.partial` 时，检查失败原因后明确移除不完整下载再重试；不绕过网络限制。下载源与完整校验值见安装脚本及验证报告。

导出在 `build/windows/` 和 `build/linux/`，每个平台的可执行文件必须与其同名 PCK 一起携带。脚本真的调用引擎构建并启动 Linux 产物；不依赖 MCP `export_project` 返回的命令字符串。Windows 启动需要 Windows 环境另行验收。

## 后续 MCP 制作

以 `scripts/mcp/glb_probe.json` 为已验证调用示例，通过新的工作流指定 server、tool、arguments；未验证工具先读实际 tools/list schema。工作流修改隔离项目，经检查后再按分工把资产或代码纳入正式仓库。Blender 源文件留在 `.local/blender-sources`，GLB 放入隔离 Godot 项目。新资源须通过编辑器文件系统扫描和重导入后再实例化，否则可能尚未被 Godot 识别。

## 启动失败的边界

若云任务在 shell 出现之前报告 `executor_registration_failed`，本仓库脚本尚未执行，现有证据不能将其归因于 MCP 或仓库配置。最小处理是由平台重新关联可工作的 shuabao 环境或重试环境启动；无需再次初始化 main、修改安全网络、开放公网端口。此任务的独立 clone 已通过，不能据此保证其他云任务的环境注册服务正常。
