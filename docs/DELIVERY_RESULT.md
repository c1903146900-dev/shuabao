# Windows 最小试玩包已准备（仅本地，未上传）

构建源码：`50f6bf3c8df264da80edc5b4f1262e7a49942ab1`。
QA009 独立修复：`5bac39160a62faa24eb179fc8e78afaf66fad2d5`，已推 main，见 [QA009_FIX.md](QA009_FIX.md)。68项专项、54组rank1矩阵、原364项及邻接35项通过，真实MCP专项68项通过；独立QA复验仍以其回报为准。

ZIP：`build/playtest/50f6bf3c8df264da80edc5b4f1262e7a49942ab1/shuabao-windows-playtest-50f6bf3c8df2.zip`。
大小 **51,869,469 bytes**，SHA256 **`ccf498cc4b18c9bc4028e5bb09451632600cb1a33b454b15033bf2a7295e1674`**。
包含且只包含 `shuabao-smoke.exe`、`shuabao-smoke.pck`、中文 `README-试玩说明.txt`；ZIP完整性通过。PE/PCK已检查，**Windows实机未执行**，未宣称Windows兼容性或帧率通过。说明包含启动、键位、两房试玩步骤和原型范围。

[包及二进制清单](validation/windows-playtest/manifest.json)、[哈希表](validation/windows-playtest/SHA256SUMS)、[逐PCK条目审计](validation/windows-playtest/package-audit.json)。每包94个运行资源条目，15个音效齐全；保留运行必需的导入资源/UID表，未包含测试、MCP开发端、文档、预览、日志、Blender源文件或编辑器缓存。已知凭据格式扫描无命中，范围与局限见审计。

Linux无头包已在源码目录外、无DISPLAY、未显式传--headless时启动并退出0。Linux桌面包实际OS两房输入、Q学习/升级、六次击杀、两次结算已看图确认；连续32.067秒视频在 [two-room-os-export.mp4](preview/two-room-os-export.mp4)。视频 SHA256 `b8e878bf0d64a92a759033a81e7350b686c36776a64edb40110d666de8483d1d`。正常引擎帧预算退出0、完整日志无ObjectDB/resource残留，见 [录制记录](validation/windows-playtest/linux-window-recording.json) 与 [日志](validation/windows-playtest/linux-window.log)。15FPS渲染上限/30FPS采集只用于云端软件渲染验收，不是性能结论；视频无音轨，未试听。虚拟显示WM_DELETE_WINDOW尝试未退出，关闭按钮仍未验，未掩盖成成功。

当前两房/药品/输入回归：12+11+10+5项，补充自然死亡/F5流程共19项，另103项受控消费检查均通过，见 validation/delivery-regression。音效生命周期独立220组件循环/20场景往返通过，35个引用32ms回收；不是无限时长保证。

非阻断已知项：QA010飘字描边淡出与聚怪血标签重叠；视觉仍为原型。ae673独立表现QA报告 `eeebef5f6bf6086fd7fa9fc3694418e0e5350f85` 无新增试玩阻断。尚未实现完整四幕、联机和保存；所有实验初值仍非正式定稿。

本交付记录及录制工具改进提交不改变上述构建源码或ZIP。包保留在云端本地；没有上传Library、公开Release或部署。下一步优先取得上传授权并通过受支持流程交给用户试玩，不继续扩功能拖延。
