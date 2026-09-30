# 风厉美术试样（2026-09-30）

分支 `feature/fengli-art`，基线 `d7d1161235de1431140456596c29f1828dab1549`。首轮记录对应 `9fea8df`，当前新增质量迭代见本文第二轮；仍不是最终人物雕刻或完整战斗验收。

## 资源与接入

- `assets/fengli/fengli.glb`：自制非写实人形，青灰轻甲、银白短发、不对称肩甲、分片衣摆、细长钻石截面剑；19 骨骼，37 网格、4,208 导出顶点。采用刚性骨骼权重，肘膝接缝后续需精修；没有外部资产或付费服务。
- `assets/fengli/source/fengli.blend`：可编辑网格、材质、骨架、九个 Action。`build_fengli.py` 为提交给 Blender MCP 的制作代码，不可用 bpy 直连方式冒充 MCP。
- `assets/arena/training_tile.glb`：4×4 米可拼接石质地块，暖灰石板、暗色基座、少量黄铜标记，顶面约 +0.01 米。只含美术，无碰撞。
- `assets/arena/enemy_regular.glb` / `enemy_elite.glb`：普通敌人为陶红窄肩面甲训练傀儡；精英为象牙色宽肩、双角和盾牌。是静态占位，不包含敌人动画。
- `scenes/art/showcase.tscn`：独立评审场景，每三秒切换动作；无 combat/UI/autoload 依赖。明亮俯视镜头、3×3 地块、两种敌人和细线橙色预警试样。没有完成正式 VFX。

Godot 不需要 Blender 才能运行：正式运行资源为 GLB；源目录 `.gdignore` 避免 Godot 自动转换 `.blend`。

## Visual 子节点合同

- 单位：1 Blender 米 = 1 Godot 单位；模型实例 scale=(1,1,1)。身高约 1.95 米，剑刃长约 1.25 米。
- Godot 上轴 +Y，正前 -Z；Blender 上轴 +Z，正前 +Y。原点为脚底中心，地面 Y=0。
- 将 GLB 实例作为角色的 `Visual` 子节点；外层角色控制器承担位移与朝向。九动作均为原地动画，没有 root motion，dash/thrust 不替代战斗位移。
- 导入场景中递归查找 `AnimationPlayer` 和 `Skeleton3D`，不要依赖根节点显示名称。
- 骨骼 `hand1` 为右手，`hand-1` 为左手；`weapon` 为随右手动作的剑根；`socket_blade_tip` 为剑尖；`socket_back` 为背部挂点。运行期用 `BoneAttachment3D.bone_name` 附着，不是按普通 Node3D 路径查找挂点。
- 当前剑已包含于 skinned mesh。替换武器时应先隐藏／移除现有剑网格，避免双剑重叠。
- `idle` / `run` 建议适配层设循环，其他动作单次播放；导入原始 clip 的循环设置不可假定。死亡末帧保持，复活时播放 idle 恢复。

## 动作时序

30 fps。以下为动画设计的姿态关键时刻，供战斗任务适配；不是已验收的伤害判定，不覆盖战斗规格。

| 名称 | 时长（秒） | 前摇 / 打击或主姿态 / 收势（帧） |
|---|---:|---|
| idle | 2.0 | 0→30→60 呼吸；循环 |
| run | 0.8 | 0/6/12/18/24 交替腿、膝、摆臂；循环 |
| attack | 0.8 | 0–7 蓄剑，10 横斩，16–24 归位 |
| dash | 0.6 | 0–4 下压，8 前倾蹬地，13–18 归位 |
| thrust | 0.9 | 0–8 收臂，11 弓步刺击，17–27 收剑 |
| overload | 1.5 | 0–14 举剑，23 高位蓄力，28 释放，45 归位 |
| ultimate | 2.0 | 0–17 蓄势，23 横斩，30 举剑，35 下劈，45–60 收势 |
| hit | 0.6 | 3 后仰响应，8–18 恢复；受击动作无主动打击帧 |
| death | 1.6 | 9 失衡，20 屈腿，32 倒地，48 保持；无主动打击帧 |

每个动作都写入局部骨骼旋转，包含胸、臂或腿的不同姿态，不是整个角色物体旋转。剑锋方向单独做局部骨骼校正，刺击主帧保持向前。当前是动作 blockout；仍需优化握剑角度、运动弧线、足底接触和布料穿插，未承诺最终 ACT 动画质量。

## 复现方式

依照 `docs/MCP_CLIENT.md` 安装，使用仓库原有 `scripts/mcp/check.py`。没有修改工具目录、project.godot、combat 或 UI。所有应用内制作均通过官方 Python MCP SDK → stdio → 上游 MCP → GUI 插件。

1. `--workflow assets/fengli/source/build_workflow.json` 建立风厉并导出。
2. `--workflow assets/fengli/source/import_workflow.json` 制作地块和敌人，建立 Godot 场景。
3. 完全重启后执行 `--workflow assets/fengli/source/verify_workflow.json`，验证源文件重开、动作、Godot 播放和截图。

所有制作先发生在 `.local/mcp-fixture`，确认后仅复制本任务资源回正式仓库。源目录已排除 Godot 自动导入。旧失败证据保留，不以成功返回包装中的 `isError=false` 作为唯一依据。

## 已知工具诊断

Blender 上游 `get_addon_status` 仍报缺少 `blender_mcp.config`。GLB 导出器报告可选 Draco 库不可用，当前未启用压缩，普通 GLB 文件已输出。Godot 的 `reload_project` 发生编辑器任务队列诊断，第一轮新资源未被导入、运行查询超时；改为重启编辑器正常扫描后复测；交付的建模与导入工作流已移除有问题的即时刷新和过早播放步骤。XServer BadWindow、Vulkan 探测与 V-Sync/音频设备警告来自云端 llvmpipe 环境，不代表 GPU 性能验收。

## 验证记录

- 当前环境真实 initialize / tools/list / GUI 查询通过；固定版本与主线文档一致。
- Blender 源文件经 MCP 保存、独立重开，19 骨骼与九个 Action 断言通过；attack 第 7、10 帧上臂局部旋转不同。
- Godot 在编辑器重启后实际导入全部四个 GLB；运行期读到九个 AnimationPlayer clip，每个 13 条保留轨道，时长与上表一致。
- 运行期两次 MCP 查询 `run` 均为 playing=true；时间及上臂／腿骨四元数不同。此前第一次查询因短动画已结束没有证明连续播放，已修正为循环后复测。
- 九个动作均通过 MCP seek 后获取真实游戏截图；已检查概览、近景、攻击前摇与打击、冲刺、刺击、蓄力、大招、受击和死亡姿态。攻击短片由 17 张 MCP 游戏截图按 20 fps 组装，表示 0–0.8 秒定时采样，**不是屏幕实时录像或性能证据**。
- 独立评审场景不代表战斗整合通过；未测伤害帧同步、碰撞、实机性能、联机或平台导出。

最终截图：`assets/fengli/preview/arena.png`、`hero.png`、`actions.jpg`；短片 `attack.mp4`。原始 MCP 回执、运行日志及 SHA-256 清单在 `assets/fengli/preview/mcp/`。


## 第二轮：足底与穿插质量修正

已从 main `abb91cf` 只读审阅 `docs/CLOUD_REPRO.md` 和 `docs/INTEGRATION_VALIDATION.md`，没有合入其他功能代码。保留首版提交和参考 GLB，所有修改仍由真实 Blender/Godot MCP 工具制作和验证。

本轮检查以 60 Hz 抽样求值后的实际网格表面相交、足底最低顶点与支撑脚世界坐标为依据；它不是包围盒猜测，也不能替代所有服饰、自碰撞和战斗集成测试。肘膝新增小块柔性接缝，腿链使用烘焙双骨 IK，脚掌保持平放，剑与前臂动作路径置于胸前和体侧。

跑步合同新增：`run` 在 `speed_scale=1` 时对应 **2.0 米/秒**，控制器应使用 `speed_scale = 实际水平速度 / 2.0`，站定切 idle；仍没有 root motion。在角色不移动时循环播放 run 是原地展示，不是接地不滑脚的游戏效果。现有脚部原点、动画名、九动作时长和资源路径保持不变。

本轮通过标准：站立与战斗支撑足底相对地块顶面误差 ≤5 毫米；标定移速下跑步支撑脚漂移 ≤5 毫米；60 Hz 抽样中剑刃／前臂对躯干、头、头发、衣摆、围巾表面相交为零；Godot 导入后复查，并检查 50% 缩图可读性。表面相交测试不保证闭合网格的完全包容检测，也不代表任意混合过渡没有穿插。

| 问题 | 改前实测 | 修正与当前状态 |
|---|---|---|
| idle 脚随呼吸上浮 | 足底 10–22 mm | 腿链 IK 固定脚掌，足底维持 10 mm（地块顶面） |
| run 支撑脚滑移 | 2 m/s 虚拟世界位移漂移 407.3 mm | 30 fps 烘焙双骨 IK；60 Hz 复测源动画最大约 3.1 mm |
| dash 穿地 | 最低足底 −112.1 mm | 双脚支撑位置固定，躯干下压／手臂回收，最低约 9.95 mm |
| attack 衣摆／前臂相交 | 60 Hz 下 3 个样本 | 前臂曲线向外，围巾收回肩后；当前 0 |
| overload 穿插 | 剑 13、前臂 30 个样本 | 外展举剑，控制剑的局部姿态；当前 0 |
| ultimate 穿插 | 剑 14、前臂 38 个样本 | 降低过量躯干扭转，重新布置手腕路径和举剑过渡；当前 0 |
| hit 四肢缺少响应 | 原前臂／腿局部姿态变化为 0 | 新增独立手臂外展与肘部屈曲，不靠根物体平移 |
| 肘膝硬断口 | 原分段刚性网格缺少过渡 | 增加小型双骨权重布料接缝，维持轻甲剪影 |

保留的失败迭代：第一次细化后大招仍在 27/32 帧有剑刃交叉、22–25 帧有前臂交叉，未推送该版本；失败测量文件随证据保留。首次修改脚本在同一 MCP 调用内重开 .blend 后访问旧 Context 失败，分离打开与制作后通过。默认 Godot 动画优化曾使导入后的单点支撑误差增至约 8 mm，单独重导入复测并保留导入设置。

剩余边界：战斗任务尚需按标定速度同步动画；任意动画交叉淡入、坡地／台阶 IK、死亡翻倒的全身服饰自碰撞、脚步音效和接触特效不在本轮已通过项中。当前做了可用的动作质量修正，仍不是最终角色雕刻或所有场景下的动作验收。

复现增量：先从 `9fea8df` 提取 `assets/fengli/source/fengli.blend` 到 `.local/fengli-quality/before.blend`；把 `assets/fengli/reference/fengli_v1.glb` 放到隔离副本的同路径。顺序运行 `refine_workflow.json`、`precision_workflow.json` 和 `quality_workflow.json`，均由原有 `scripts/mcp/check.py --workflow ...` 执行。`precision_workflow.json` 使用独立临时场景设置导入精度。不得并发占用 GUI/MCP。


导入精度：正式资源同时携带 `assets/fengli/fengli.glb.import`，其中 AnimationPlayer 的 `optimizer/enabled=false`。请随 GLB 一起集成，不能只复制 GLB 后丢掉该设置。Godot [官方导入说明](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/advanced_import_settings.html#optimizer)解释了默认优化器会精简动画；本资源通过实际前后采样选择禁用。五个 Godot 支撑期采样点（0/0.1/0.2/0.3/0.4 秒）关闭优化后的脚部世界坐标差异约 0.01 mm，源动画在 60 Hz 的最大残差仍按 3.1 mm 报告，不混淆两种采样密度。

本轮新增 4 个双骨权重接缝网格；骨骼仍为 19，九个动画时长未变，Godot 各动画保留 19 条轨道。俯视截图在 1228×690 下获取，另输出 614×345 的真实半尺寸图作人工检查；拼图没有用放大剪裁冒充半屏可读性。对照短片由 25 张 MCP 游戏截图按 30 fps 合成，不能用它证明实时帧率。

当前预览与记录在 `assets/fengli/preview/quality/`：`arena_v2.png`、`hero_v2.png`、`actions_before_after.jpg`、`attack_before_after.mp4`、半尺寸图、改前/改后指标和失败迭代。原 `preview/mcp` 仍是首轮历史证据，其清单不能当作本轮资产哈希。当前以 `preview/quality/manifest.json` 为准。


接地追加检查：Godot `bake_mesh_from_current_skeleton_pose()` 实测两只鞋底最低点均为 `0.010000634 m`，与地块顶面吻合。地块不再投射自身阴影，降低了阴影偏移，但软件渲染软阴影仍可能产生轻微悬浮观感；保留为视觉精修项，不声称阴影风格已经最终验收。

Library：本轮按当前 Library 技能的多文件上传流程尝试三份预览，但在准备上传前的工具发现阶段发生网络失败，未获得 library_file_id；没有改用另一条写入流程重复上传。三份可转交文件均保留在仓库，可通过 GitHub 分支文件链接访问。
