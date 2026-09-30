# 俯视敌人美术测试资产

本资源来自 `feature/fengli-art`，只读对照战斗分支 `07dd35e96c9a9ebb36a82ca09a1dc6de3b8a1df3` 的 `data/combat/tuning.gd`、`scripts/combat/combat_sim.gd`、`scripts/actors/actor_view.gd` 和 `docs/COMBAT_PROGRESS.md`。不是最终怪物种族／设定，没有修改战斗、UI、project.godot 或工具目录。旧 `assets/arena/enemy_regular.glb` / `enemy_elite.glb` 留作原占位，不被悄悄替换。

## 三种轮廓

| kind / 文件 | 测试造型 | 名义身高 | 当前模拟半径 |
|---|---|---:|---:|
| minion / `minion.glb` | 窄兜帽、单侧肩片、前端钩刃、短衣摆 | 1.68 m | 0.50 m |
| elite / `elite.glb` | 横脊头盔、双层肩甲、独立塔盾与战镐 | 2.12 m | 0.75 m |
| boss / `boss.glb` | 宽石甲、开放式背架、双手重锤，慢举快落 | 2.78 m | 1.15 m |

三者分别有独立网格与轮廓结构，不是只缩放或换色。身高为建模目标值，姿态会改变外包围盒；模拟半径来自战斗测试表，不应由网格自动反推碰撞。普通、精英各 7 个动画，Boss 另有 `heavy_attack`，它与 `attack` 为同一测试重击时序。

## 时序合同

60 fps；1 单位＝1 米；Godot +Y 向上、−Z 向前；脚底中心原点，实例 scale=(1,1,1)。全部原地动作，无 root motion。机器可读参数在 `animation_contract.json`。

| kind | warning 前摇 | attack 打击帧 | recover 收势 | attack 总长 |
|---|---:|---:|---:|---:|
| minion | 0.85 s | 51 | 1.10 s | 1.95 s |
| elite | 1.00 s | 60 | 1.10 s | 2.10 s |
| boss | 1.35 s | 81 | 1.60 s | 2.95 s |

- `idle` 2.0 s、`walk` 0.8 s 建议循环；其他单次。`hit` 0.55 s；`death` 普通／精英 1.7 s、Boss 2.1 s，末帧保持。
- `attack` 包含前摇、打击、收势。前摇大部分时间为抬武器蓄势，最后 0.13 s 快速出手，打击帧对齐测试模拟的 warning 到期。
- 同时提供 `windup` 和 `release`，长度分别为前摇与收势。可在 `enemy_warning` 播放 windup，用 `原前摇长度 / 当前配置前摇长度` 设置播放倍率；收到 `enemy_impact` 时从 release 的 0 秒开始。release 第 0 帧已经是打击姿态。
- **伤害、目标点、圆／扇形预警依旧由模拟控制**，不读取动画轨道触发伤害，不把模型武器长度当攻击范围。Boss 的圆与扇形暂共用慢重击；地面目标点固定及朝向锁定沿用原逻辑。
- `damage.target` 可请求 hit 表现，`kill.target` 请求 death。受击表现不能取消模拟的 warning/timer；如果单 AnimationPlayer 被 hit 打断，适配层需在恢复时根据模拟状态重新采样，不能擅自改攻击规则。
- walk 是约 1.15 m/s 标定的原地测试循环；实际追击 2.35/1.95/1.50 m/s 时，建议倍率为实际速度 / 1.15。位移、减速、暂停、世界时间由模拟驱动。本轮没有替战斗任务实现接入或性能验收。
- 挂点均为 Skeleton3D 骨骼：`hand1`、`hand-1`、`weapon`、`socket_weapon_tip`、`socket_warning`。通过 BoneAttachment3D 附着；`socket_warning` 仅提供根部参考，目标锁定圆仍应放在模拟 target_point。

## 制作与验证

`.blend` 源文件位于 `source/`，运行使用同目录上一级 GLB。源与预览目录 `.gdignore` 避免证据被 Godot 当游戏资源导入。建模、动作、导出、Godot 脚本创建、导入、播放和截图均走仓库标准 MCP 客户端。没有新增软件或第三方资产。

依次运行原有 `scripts/mcp/check.py --workflow assets/arena/enemies/source/build_workflow.json`、`readability_workflow.json`（只修改已存在风厉材质）以及 `review_workflow.json`，在 `.local/mcp-fixture` 内验证，重启编辑器后导入新 GLB。所有工作流按顺序运行，不并发占用显示和 MCP 端口。风厉材质步骤之前须已有经验证的风厉 blend；不重新创建其动作。

`scenes/art/enemy_review.tscn` 展示三类剪影、圆／扇形测试预警、受击和死亡，以及 Boss 前后两侧的风厉遮挡检查。额外镜头使用战斗分支原值：正交 size=27、位置(0,27,20)，避免只在特写里判断可读性。

## 风厉和贴地观感增量

按主集成后续反馈，风厉仅将剑刃改成深色刃面＋浅色棱面，保留玉色剑脊；资源路径、骨骼、动画名和时长不变。另提供可选表现脚本 `scenes/art/foot_contact.gd`：在已知平地上给两个脚掌投射小型软接触印记，脚抬起时衰减；不改变角色高度、移动、伤害、碰撞或预警。印记位于地板上方、预警下方，不投射阴影。它是平地表现方案，不是坡地 IK 或实时环境遮蔽。

集成时可把该脚本的实例作为表现节点，调用 `setup(model, ankle_height, radius, floor_y)`。本组普通／精英／Boss 参数分别为(.15,.12,.01)、(.18,.15,.01)、(.22,.20,.01)，风厉默认(.17,.18,.01)。可通过减少不透明度或禁用节点关闭。无需修改战斗模拟。

## 失败与边界

首轮截图发现普通敌人死亡落地偏低、武器随手臂翻入地面，已调整死亡支撑高度并烘焙武器水平收落。第一次遮挡测试还因预警可见性代码显示了隐藏敌人的圆，已修正为跟随对应模型可见性。

穿插检查只覆盖 30 Hz 抽样的武器与躯干／头部表面，不能保证所有混合过渡、布料自碰撞或任意地形。没有正式敌人 AI、VFX、音效、联机或性能结论。遮挡应以真实截图为准；没有通过修改深度测试把人物强行穿透 Boss 显示。

## 本轮实际结果与可转交证据

- 最终 Blender MCP 导出与 30 Hz 几何抽样：三类武器／躯干、头部交叉均未检出；攻击脚底最低约 0.010 m。死亡全网格最低 minion=0.0144、elite=0.0162、boss=0.0214 m。原始结果为 `preview/*_metrics.json`，不是任意动画混合安全保证。
- Godot GUI 真实导入后核对 22 个动画（7+7+8）的名称与长度；连续两次运行查询证明 idle 播放时间及骨骼姿态变化。另通过 Godot AnimationPlayer 逐帧采样攻击、行走、受击、死亡，并保存 MCP 图片。未在真实战斗分支运行敌人适配层。
- [最终场景／前摇](preview/windup.png)、[动作拼图](preview/enemy_action_sheet.jpg)、[Boss 重击采样短片](preview/boss_heavy_sampled.mp4)、[战斗镜头](preview/combat_camera_27.png)、[半尺寸战斗镜头](preview/combat_camera_half.png)。短片来自 Godot MCP 的 25 张实际采样画面，时间间隔 0.084375 s，覆盖 Boss attack 的 0–2.025 s；不是实时帧率录像，也没有覆盖完整 2.95 s 收势。短片／动作拼图先于最后一次灯光收紧，模型和动作与最终资源一致。
- [风厉材质与贴地观感前后对比](preview/fengli_readability_comparison.jpg)、[最终攻击剑刃](preview/fengli_blade_attack.png)。新剑刃在浅地板上更清楚。接触印记增强、预览太阳 shadow_bias=.005、normal_bias=.01、shadow_blur=.2；脚掌附近贴地线索改善，但软件渲染器的身体投影仍偏软，**保留为未完全解决的视觉问题**，不声称主战斗场景已修好。旧展示场景两个占位敌人没有追加接触印记，不属于新敌人验收对象。
- 风厉九个动画全部 channel、插值模式、输入／输出浮点 accessor 的 SHA-256 比对一致，见 `preview/fengli_animation_preservation.json`。没有更改风厉骨架或动作。材质更新只需新 GLB；接触阴影与灯光效果需要接入相应表现节点／设置。
- 战斗 size=27 镜头下，钩刃伸展、塔盾、双肩背架与重锤方向可分辨；降到 640×360 后，小装甲和普通敌人面部不可读，不能把特写质量视为远景细节达标。Boss 后方人物下半身会自然遮挡，头和上身可见，没有实现穿墙轮廓或动态镜头避让。
- 最终复查第一次编辑器启动 signal 11 崩溃，原日志保留 `preview/mcp/enemies-final-review/godot-editor.log`；重启通过 97 步完整复查，再通过 23 步最终灯光／接触复拍。接触诊断首次漏传 overwrite，被 MCP 拒绝，修正后成功，没有覆盖失败为通过。上游保存场景 message-queue、Vulkan 探测、XServer／V-Sync 诊断仍可见；没有脚本解析或着色器编译错误，运行查询和截图独立核实。此环境不是性能验收。
- Library 按主任务要求没有重试。上述链接均为仓库资源，不依赖作者本地路径。`preview/mcp/` 保存成功调用回执及原始截图，`preview/manifest.json` 记录证据校验和。
