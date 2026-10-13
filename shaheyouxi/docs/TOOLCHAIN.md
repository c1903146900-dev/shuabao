# 工具链实际状态

2026-10-04 16:04 UTC。仅本工程、局部安装和局部运行目录；不修改共享全局配置。

## 引擎和基础工具
- Godot入口/usr/local/bin/godot → /opt/godot/4.6.3/Godot_v4.6.3-stable_linux.x86_64。资料目标4.6.2，4.6.3已实测基础导入、headless与GUI生命周期、GdUnit及MCP，尚无全内容兼容结论
- Blender入口/usr/bin/blender，root提供已验证版本4.3.2；本项目此批未运行
- ffmpeg可定位；Python openpyxl、python-docx和Pillow可定位；尚未验证正式权威原件导入或音频试听
- GUI音频设备缺失回落dummy，Vulkan扩展探测有错误但GL Compatibility正常显示；限制保留

## Godot MCP
- 复用root明确授权的engine_mcp依赖根，未读取父游戏目录、队列、状态或其启动脚本
- 上游锁定commit 328e15f7d38092371b2aca8b81c40b8188bbe747；MIT许可保留于game/addons/godot_mcp
- 本项目局部守卫：SHAHEYOUXI_MCP_PROJECT必须与res://绝对路径一致，GODOT_MCP_PORT必须16515，否则插件不注入autoload、不连接任何桥
- 专用probe先核端口空闲，连接后首先只读get_project_info校绝对路径。普通run_game清桥变量且拒绝任何项目/脚本/editor参数覆盖
- 173工具握手、专用路径身份、正常退出0及端口关闭已实测；唯一run_id证据mcp_20261004T160210705255Z.json
- 只读指身份查询本身。插件在自身编辑器生命周期会对本工程project.godot注入/移除autoload；非全局写入
- 自动消警保持false；运行须root明确授予资源窗口，仅关闭自有进程

## GdUnit4
- 获准工具根无已有副本后，从官方仓库tag v6.2.1下载，仅安装本工程game/addons/gdUnit4
- commit 08ffc7c65b61b1b2edd545616061a99973c13ce1，MIT许可保留。只用一个测试框架，无全局安装
- 官方兼容表含Godot4.6.3，本机正例3/3通过exit0、故意失败1项准确exit100；命令/PID/退出码见001_verification_runs.json
- 这些是001框架和工程测试，不能当作005故障体系/真实联机测试完成
- 官方来源：https://github.com/godot-gdunit-labs/gdUnit4/tree/v6.2.1
- 官方发行：https://github.com/godot-gdunit-labs/gdUnit4/releases/tag/v6.2.1

## 后续按需
Better Terrain按最新工具需求非必需，留地形阶段隔离评估。Blender桥上游commit 60d2a31b4632a7bc178f3dd636f7e68dfb5c8ae4、SDK1.30.0/包2.1.3仅为root提供工具信息，本项目未启动，后续须绑定自己的blend文件再操作。
