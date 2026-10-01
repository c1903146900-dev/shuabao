# 第一版可审阅美术精修

基线：`69d58417c157b5855ce50703916318973080e771`。只修改既有美术资产与 `scenes/art`，不改 combat、UI、integration、project.godot。没有安装软件，没有 Library／其他外部文件上传，没有 Release 或权限变更；唯一远端交付为既有 Git 分支。

## 可直接查看

- [同机位前后对比](comparison.jpg)：上排为三类敌人与场地，下排为风厉近景。左侧基线，右侧本轮；只做版面排列与等比缩放，没有修饰截图内容。
- [场地全景](arena.png)、[敌人前摇与预警](enemy_windup.png)、[Boss 遮挡检查](boss_occlusion.png)、[战斗原镜头](combat_camera.png)、[半尺寸镜头](combat_camera_half.png)。
- [动作回归拼图](motion_sheet.jpg)：风厉 idle／run／attack／hit，普通／精英／Boss 的 walk 与 attack。
- [完整风厉攻击采样](fengli_attack_sampled.mp4)：17 张 Godot MCP 图像，时间点 0–0.8 s，间隔 0.05 s；按 20 fps 编排。不是实时帧率录像，不用于性能结论。

## 本轮变化

风厉增加分层胸甲、弧形肩甲内层、肘腕包覆、靴面护甲、鼻梁与前额发束、剑格和握柄细节，保留深刃面／浅刃缘／玉色剑脊。普通敌人以窄尖兜帽、斜胸带和钩刃保持敏捷轮廓；精英增加弧形厚肩甲、护颊、盾边与内凹盾面；Boss 增加低位胸甲、分片腿裙、肩甲错层和重锤端面。仍为非写实测试角色，没有自创最终怪物设定。

`training_tile.glb` 保持 4×4 m、地面 Y=0.01 m，改为低饱和石材、窄缝与小倒角。石材纹理在 Blender MCP 内以确定性程序自制，嵌入 GLB，并保存 PNG 源图。新增 `assets/arena/ruin_pier.glb` 和 `ruin_marker.glb`，仅放在评审场景边缘；中央没有柱子、散物或发光特效。

光源俯角从 55° 改为 72°，评审光源 shadow_bias 和 normal_bias 均为 0，保留四级阴影及既有脚掌接触印记，缩短离脚投影。Godot 运行时直接烘焙蒙皮网格，idle 原靴底最低 Y=0.0100006 m，与地面吻合；run 支撑脚约 0.01 m、另一脚抬起，attack／hit 亦实际采样。贴地表现需连同评审灯光／接触节点使用；只换 GLB 不会修改主战斗场景的灯光。本轮没有在主战斗集成场景验收。

## 实测与接口

- 实际重新握手 Godot MCP 173 工具、Blender MCP 36 工具，并做应用查询；所有建模、材质、导出、Godot 脚本更新、播放与截图均通过标准 MCP 客户端。没有用独立 bpy 或 Godot 脚本进程绕过 MCP。
- 四个角色共 31 个动画：名称、输入／输出浮点关键帧的 SHA-256、插值、骨骼静止变换及层级全部与基线一致，见 [contracts_unchanged.json](contracts_unchanged.json)。单位、正前轴、挂点和时序继续使用 [原接口合同](../../animation_contract.json)。
- Godot live-clock 查询对风厉 run／attack／hit、敌人 walk／attack／hit 分别取得两次不同播放时间与骨骼姿态，证明实际播放，不只截图摆姿势。随后逐帧采样复查。
- Blender 30 Hz 抽样覆盖四个角色 idle、移动、attack、hit，包含新增护甲：武器组对胸、胯、头组网格未检出表面相交，脚底最低约 0.01 m。结果在 `*_polish_metrics.json`。不代表任意混合动画、上臂／袖口全部自碰撞、坡地 IK 或最终性能通过。
- 101 步完整复查之后只调整石材底色，未再改角色；最后 66 步真实 Godot 导入／画面复查保存最终图片。MCP 调用与原始截图位于 `mcp/`；`manifest.json` 记录文件和正式资产校验和。

## 失败记录与边界

首轮肩甲采用共面叠片，近景出现条纹闪烁；改为弧形错层后复拍消除。纹理首次偏亮，下一次又偏暗；最终取实拍中间明度。失败画面保留在 `iterations/`，不把它们当最终预览。

软件渲染的身体阴影仍软，采用短投影和接触印记改善贴地感，没有声称更换了渲染器或在所有平台彻底消除阴影问题。远景主要依靠轮廓、盾／锤方向与颜色识别，微小护甲纹样在半尺寸镜头不清楚。Boss 后方仍有自然遮挡，未实现穿透轮廓。

引擎仍输出 Vulkan 探测、MCP 编辑器保存队列和 XServer／V-Sync 诊断；实际应用查询、导入、播放、脚本／着色器和截图另行核查。不宣称零诊断或性能通过。


## 复现入口

依次用既有 `scripts/mcp/check.py` 执行 `assets/arena/enemies/source/polish_build_workflow.json` 和 `polish_review_workflow.json`。前者从仓库源 blend 开始，在隔离副本中生成四角色和三场地资产；后者在全新 GUI 会话导入、更新评审脚本、播放与测量。只补拍时可执行 `polish_capture_workflow.json`。不并发占用显示和端口。`polish_fix_workflow.json` 属于本轮中间修正记录，最终复现使用上述 build 入口。
