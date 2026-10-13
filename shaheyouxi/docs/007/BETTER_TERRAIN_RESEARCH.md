# Better Terrain 007适用性初核（主工程未启用/隔离评估未执行）

2026-10-05只读检索官方发布入口与作者源仓库：
- Godot Asset Library：https://godotengine.org/asset-library/asset/1806，Better Terrain1.1，页面列Godot4.3，作者Portponky，Unlicense，2026-02-14版本时间
- 作者仓库：https://github.com/Portponky/better-terrain
- 旧TileMap版4.2另有asset2954；本机Godot4.6.3不可误拿旧节点版

当前README说明它处理TileMapLayer/TileSet的邻接匹配与绘制，运行时通过BetterTerrain autoload设格再更新邻域；不负责服务器Seed、材料等级、文明/关键Boss保底或存档。因此可评估为表现/编辑辅助，不能替代原设计世界生成器或成为正式逻辑坐标权威。

待隔离验证：
1. 精确版本/commit/hash锁定，先查本项目已有安装；仅本沙盒独立分支/工程的插件与autoload，不改main/global配置
2. Godot4.6.3实际兼容，项目identity与关闭收尾
3. TileMapLayer多地图层、空洞/边界更新和邻接表现，不重映射逻辑XY
4. 关闭表现TileMap自己的physics以免与006服务器物理双重碰撞；视觉variation不得新增服务器/存档字段
5. 检查随机变化是否能按既定world_seed+cell+正式地面资源ID确定；若API随机源不能隔离，拒绝正式采用而保留技术证据

只有隔离兼容/适用性验证完成才考虑启用；当前没有下载、安装、Godot测试或兼容通过声称，也未另外安装第二种同类插件。

01:29更新：官方下载固定e93040e1cdd9dba0117c87f8f6b2883c83872d5d，归档80,587B、SHA256 b79efec73fc74090fffe3f225602f01a69c0b84e902dff640afc4ef1104fe427，ZIP CRC通过；只复制到experiments/better_terrain007独立工程，未执行。原版rng独立但默认仅hash(coord)；已写公開逐格API适配候选和21检查探针，加入world Seed+cell+两个正式地面ID，并还原vendor RNG状态。主工程配置前后hash守卫、官方源码68文件锁校验。运行时探针将不启EditorPlugin，不代表编辑器兼容通过。Python163项通过，插件实际执行仍待root窗口和阶段预算授权。
