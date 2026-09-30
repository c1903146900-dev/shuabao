# 风厉美术试样（2026-09-30）

分支 `feature/fengli-art`，基线 `d7d1161235de1431140456596c29f1828dab1549`。这是可迭代的第一轮美术与动画管线试样，不是最终人物精度或战斗验收。

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
