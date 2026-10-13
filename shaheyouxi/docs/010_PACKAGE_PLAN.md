# 010 Linux技术包与联网GUI补验

root于05:55明确需真实联网GUI及本机可运行包，05:57认可依赖已装Godot4.6.3的Linux技术PCK方案。此文件为候选；目前只有轻量准备和Python检查，尚未构建PCK/实际运行包。

## 打包
- tools/package010.py prepare：从实际world场景解析静态脚本依赖，加入12份当前数据JSON、独立技术project.godot、3个已有运行全局类注册。29资源/934549B；不含测试/插件/runtime或开发绝对路径
- tools/pack_world010.gd：用Godot PCKPacker原生API逐项检查hash并写PCK，非editor，不下载导出模板。API依据 https://docs.godotengine.org/en/4.6/classes/class_pckpacker.html
- Python finalize：封ZIP/清单并解压校验全部文件hash；只把manifest的相对资源路径放交付包，构建绝对路径仅本地build清单
- 解包目标builds/technical010/unpacked，game目录仅PCK。launch010.py用此目录与--main-pack，不回源项目，不依赖外部Godot导入缓存；运行后如失败即记录失败，不以源工程运行替代
- 启动说明明确依赖已安装Linux Godot4.6.3与Python3；这是技术资源包，不是Windows独立可执行完整游戏

## 第一窗口候选：PCK+实际解包单服务器
三个串行命令：原生PCK制作→Python封校解包→真实包入口单headless服务器ready→正常stop/存档/端口释放。最多一个引擎，192自有PGID/900effective/raw192、45秒单命令110总，10秒延迟reset入口tools/desktop_world010_pack.sh。首失败停，保留产物/证据。不重复57项已经通过的同源测试。

## 第二窗口候选：实际PCK联网GUI
以解包目录独立runtime/world和每客户端独立身份/报告启动专用服务器、一个headless客户端、一个GUI客户端，峰3。展示同世界/Seed/组件SHA，真实GUI看到3层技术代理/19对象房间，截图；按F10后正常关闭GUI，再停headless与服务器并核端口。只读观察，不重画编辑器或冒称人物操作。
预算候选：引擎合计480MiB/含Python整体PGID512MiB，effective900/raw192，170秒命令180秒总。估计来自实际两个headless约200MiB与009GUI约220–245MiB；独立窗口另请root许可，当前刷宝独占不启动。
