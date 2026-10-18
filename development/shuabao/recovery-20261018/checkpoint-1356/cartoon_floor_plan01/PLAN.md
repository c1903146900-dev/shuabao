# 第一层场景与敌人卡通转换方案

日期：2026-10-18。状态：静态核查及实施方案，尚未实施或运行。正式工程基线为 `p3_integrated_source01/source/game` 的 3044 个文件。本文中的 `res://` 均相对此工程；配套 `SOURCE_AUDIT.json` 保存实际文件哈希、完整继承链、七类资源与原始 mesh 节点清单。

## 1. 范围与执行次序

先完成晏归舟英雄的独立接入，再实施本方案。只处理当前第一层已使用的共享房间与七类敌人；不启动其他英雄、沙盒、额外敌人或新玩法。此次仅新增方案文件，未启动引擎或浏览器，未修改正式源。

当前真实路线为 `res://tests/ink_first_floor_user_route_20261005/runtime01/first_floor.json`，版本 `user-route-runtime01`，12 行、30 个路线节点；不是旧 `first_floor_v0.json`。各节点复用一个前庭视觉场景，不是十二套独立房间。

- ordinary_a：4 minion
- ordinary_b：2 armored、2 minion
- ordinary_c：2 ranged、1 pouncer、3 minion
- elite_a：1 elite、3 minion
- elite_b / elite_c：各 1 elite、1 ranged、1 support
- boss：1 boss
- rest / training：服务节点，无敌人 roster

实际使用的七类为 minion、armored、ranged、pouncer、elite、support、boss。pitcher 虽有旧资产，但未被本层当前路线引用，排除本次制作。

## 2. 已查看证据与风格差距

实际查看了 `worldfx_ui_native03/evidence01/00_growth_expanded.png`、`01_q1_flow_early.png`、`02_q1_flow_later.png`，以及已合法取回参考视频的 15、55、100 秒帧。参考仅用于比较正常游戏尺度的剪影、分色、轮廓和动静对比；参考视频和帧不属于本方案或后续美术发布包。

当前画面仍明显是低模体积表现：大面积米黄地面，硬边石台和柱子，八边形水缸，青灰外背景，极小且细腿细节多的虫骨敌人。敌人与背景明度接近；原有哑光处理保留了 Lambert 光照、磨损贴图与多面体轮廓，不能等同于卡通转换。

目标是原创卡通风格：角色轮廓强、头身与装备大形清楚、两至三级主要分色；环境对比低于战斗对象，边界清楚，地面纹理克制。保留自己的前庭题材，不复制参考中的屋顶、青蛙、枪械或其他身份元素。仅统一 toon 材质、添加描边、调灯或放大模型，都不能单独算完成。

## 3. 实际生产入口、工厂与继承关系

### 3.1 入口

正式主场景 `res://scenes/hero_entry.tscn` 使用 `res://scripts/integration/hero_entry.gd`。晏归舟普通视觉 Host 为 `res://tests/ink_ordinary_visuals_20261007/candidate01/host.gd`，继承 `res://scripts/integration/yanguizhou_first_floor.gd`，再进入既有普通首层链。

完整 Host 与 Session 继承链已从文件逐层解析，见 `SOURCE_AUDIT.json`。不要因路径含 `tests` 就将其误当作未使用样板。当前运行链确实使用这些文件。

世界 FX / UI 候选的共享入口为 `worldfx_ui_candidate02/payload/yan_visual_attach_20261018/entry.gd`，继承原 HeroEntry，保留原开局、返回和销毁事务。最终接入必须重新绑定届时已验证的最新共享入口，不能以本方案冻结的旧入口覆盖之后的英雄、UI 或 FX 变化。

### 3.2 房间工厂

- `res://tests/ink_first_floor_room_art_20261004/stage.gd`：创建环境、灯、房间 mesh、静态投影、接地影和相机。
- 同目录 `room_geometry.json`：一个 opaque mesh，4572 三角形；包含 groups、material_family、collision_id，适合仅绘制分区。
- 同目录 `room_layout.json`：场地半径 13 米、六个障碍块、南北门边界及原通道范围。
- 同目录 `room_layout.gd`：向 Sim 写入 arena_half_extent、obstacles，是物理布局适配器，不能更改。
- `res://tests/ink_style_specimen_20261004/style.gd`：现有哑光材质，roughness=1、metallic=0、无 specular、Lambert diffuse。

正交相机保持 size=18、elevation=40°、ground_distance=24、原跟随平滑与 clamp。保留原 `ground_point()`，不改瞄准投影。

关键约束：`res://tests/ink_first_floor_user_route_20261005/native_host01/flow_bridge.gd` 每次刷新检查 `stage.get_script() != RoomView`，不匹配便删除并重建。其祖先 runtime01/host.gd 也有同类检查。因此不得将 stage 换成新子类或另一个 stage 实例。保留 stage，只在它下面挂视觉附件。

### 3.3 敌人工厂

- `res://tests/ink_normal_floor_host_20261004/enemy_layer.gd`：Reader、Roster、敌方特效与 preflight。
- `res://tests/ink_first_floor_enemy_views_20261004/fix01/roster_presenter.gd`：拥有每个敌人的 view/cursor，负责 epoch、销毁与映射。
- `res://tests/ink_first_floor_enemy_views_20261004/enemy_view.gd`：加载原角色，应用哑光材质，按 sample 采样原动作。
- 同目录 `asset_catalog.gd`：原资产、时长、动作名、步态速度。
- 同目录 `fix01/pose_cursor.gd`：由现有源时间、位移和 phase 产生绝对 pose sample。
- `res://scripts/integration/enemy_actor_view.gd` → `xuanlei_actor_view.gd`：原导入节点、骨架、血条和 cast socket。

Roster 的 `view_factory` 标为有限契约测试注入，不能借此绕过正式接入或预检。

七类资产：六类普通/精英资源位于 `res://assets/enemies/siege_brood/{kind}/{kind}.glb`；Boss 为 `res://assets/arena/enemies/boss.glb`。六类骨骼数分别为 minion 8、armored 10、ranged 10、pouncer 11、elite 12、support 13；Boss 19。完整原始 mesh 名称见 `SOURCE_AUDIT.json`，不猜测 Godot 导入后的动态节点路径。

## 4. 原有后处理顺序与保留项

当前普通视觉 Host 的 `_refresh()` 顺序是：

1. `ordinary_attack_feedback.clear_enemy_feedback()` 撤销上一帧的表现偏移。
2. `super._refresh(delta)` 执行原首层刷新。
3. 祖先 flow_bridge 内执行 `enemy_layer.present()`，内部 Reader → Roster/Cursor → `view.apply_sample()`，随后敌方特效接收事件并同步 socket。
4. 原 stage 跟随相机、接地影和 UI 刷新。
5. 普通视觉 Host 应用新的 attack feedback：原 `view.visual` 反冲位移、倾斜，以及原 mesh 闪白。
6. 原 E 等表现恢复最终投影。
7. `_ordinary_present_boss()` 调用 Boss manager；art02 在普通 pose 后覆盖 Boss A/B/C 与转阶段动作。
8. 新卡通附件应在以上原刷新完成后更新显示；还要覆盖原 modal 引发的 deferred 刷新，不能只假设某个 process_priority 永远足够。

新附件只读取现成 `view.sample_report`、Roster 报告和 Boss manager 的最终报告；不再触发一次 Reader.capture、Cursor.sample、Director.snapshot、Sim.snapshot 或 step。冻结/暂停时不使用墙钟补动。不得创建第二个玩法时钟。

必须保留：

- 原 actor view、`visual`、Skeleton3D、AnimationPlayer、全部动作与原 socket。
- `assets/enemies/siege_brood/vfx/enemy_combat_vfx.gd` 的 cast_socket_world 调用与敌方弹体、预警、范围。
- `tests/ink_attack_feedback_20261007/candidate02/attack_view.gd` 的源驱动反冲与闪白；新 skin 在最后显示阶段同步同一表现，不能丢失反馈。
- `tests/ink_first_floor_boss_20261008/presentation01/manager.gd` 与 `art02/boss_art_consumer.gd`。后者要求原 19 骨 skeleton/player，使用脚骨接地与原 Boss cast.geometry。
- Boss 警告边界、A/B/C 时序、转阶段与原岩石落点。完整 Boss 卡通化时可替换岩石的外观，但不能隐藏整套 Boss 特效消费者或改变这些源几何。

## 5. 只隐藏 mesh 的精确选择规则

### 5.1 房间

允许在完整新房间 skin 就绪后隐藏：

- `stage.get_node("PaintedForecourtOpaque")`，类型 MeshInstance3D，旧房间不透明绘制。
- `stage.get_node("StaticSoftShadowLayer/BakedVolumeCastAndContact")`，类型 MeshInstance3D，旧建筑投影绘制。

不能隐藏或删除：stage 本体、WorldEnvironment、`SharedWarmKey`、`Forecourt_18m_40degCamera`、`StaticSoftShadowLayer` 整层、`stage.hero_grounding`。`stage.enemy_grounding` 仍由原 Host 保持隐藏，因为它只代表一个敌人，不能伪装为完整 roster 阴影。

切换前记录两个旧 mesh 的原 visibility；回退时恢复原值，不一律设 true。新 skin 失效时不得留下“旧地面已隐藏、新地面没加载”的空场景。

### 5.2 敌人

精确运行时白名单是：在创建新 skin 之前，从该原 `view.meshes` 缓存复制的全部 MeshInstance3D 引用。此数组由原 `_scan(visual)` 收集导入模型，不含随后单独创建的血条/标签。

- minion、armored、ranged、pouncer、elite 各 4 个原模型 mesh；support 5 个；Boss 72 个。
- 原始 GLB 中每个 mesh 的节点名及祖先路径已完整列入 `SOURCE_AUDIT.json/enemies`。
- 运行时检查：对象仍有效、属于该 view.visual 子树、身份与角色资源对应。对数量/归属不符明确报错，不能模糊隐藏整个子树。
- 只将白名单里的旧 mesh visibility 设 false。不要隐藏 `view` 或 `view.visual`，不要移除骨架或 player，不改 mesh/skin/animation 资源。
- 新 skin 不加入旧 `view.meshes` 数组，避免受旧材质替换及 Boss 铜片处理误作用。受击闪白由新显示层读取/同步原表现结果。
- 保留 `health`、`hp_back`、`hp_fill`、`_shield`，以及 warning、warning_edge、warning_back、attack_alert、role_status 的原显示策略。现有英文技术标签可另做显示文本改进，但不属于首个样板的必要接入变化。
- 换房、actor-token 替换、死亡清理、选英雄和退出时，按原 owner 生命周期销毁新附件；恢复旧 mesh 时校验原对象身份，不能写入已经复用的新敌人。

## 6. 最小首房 + minion 样板

先制作一个独立可撤销包，不先造七类全部资产。

拟新增文件（以下是计划名，不是已存在实现）：

- `attach.gd`：识别当前已接入的晏归舟房间，绑定源节点，安排最终显示更新，切换/回退。
- `room_skin.gd`：绘画房间层；复用原 layout 分区和几何坐标，不写 Sim。
- `enemy_skin.gd`：只读现有 sample 的方向、动作和姿态时间；正常世界深度显示。
- `catalog.json`：资源、动作区间、方向、脚底锚点、图集边界及哈希。
- `assets/room/`：原创地面、六个障碍区域、墙柱、水缸与植物的源图、可编辑源、运行纹理。
- `assets/enemies/minion/`：原创身份设计、方向、idle/run/attack/hurt/death 可编辑源与运行图集。
- 导入配置、独立核查工具、候选 MANIFEST、基线哈希、撤销清单。

房间要求：

- 使用现有 `room_geometry.json/groups` 和 collision_id 分区，六个不可通行块的可见脚印与原 AABB 一致。
- 在原相机下重绘大形：两至三级石墙分色、手绘边缘、圆润水缸、成簇植物；不能只沿用八边体积加描边。
- 地面纹理低对比，不与英雄、敌人、墨色技能和预警争夺注意力。新贴图和描边不覆盖技能源边界。
- 不能画出事实上不可通行的台阶、裂口或走道。南北门和场地限制仍遵从原规则。
- 保留原世界灯设置，使用局部绘画材质表达；不改全局灯来影响英雄或世界 FX。

minion 要求：

- 设计头部、甲壳/骨面与武器的大形，使当前小尺度仍可辨识；独立原创，不能把参考敌人换色。
- 保留世界位置、朝向、原 source_radius 与 common_model_scale；新画幅的脚底锚点与原位置对齐。不能通过放大碰撞或缩放相机改善可读性。
- 每个启用方向具备真实 idle/run/attack/hurt/death 运动。静态立绘浮动、仅翻转不对称装备、刚性独立袖片摆动不算动画完成。
- attack 接触时刻映射既有 clip/time，不修改预警或恢复时间；重复同一 sample 必须生成同一帧。
- 使用世界深度测试，与墙体、地面和世界 FX 正确遮挡；不得 no_depth_test 把敌人永久盖在所有物体上。
- 本样板不得依赖尚未完成验证的英雄 renderer。若未来复用其已验证共享 mesh 接口，应以独立明确版本接入，不修改英雄实现。

## 7. 视觉与功能验收

样板在原 1280×720、原 18m/40°相机下验收；放大特写只能辅助，不能代替游戏尺度。

视觉检查：

- 首房地面、墙、柱、水缸、植物及 minion 同属绘画卡通语言，无旧低模轮廓或磨损质感残留。
- 静止时看清 minion 面部/头部、身体朝向和攻击用部位；移动中不变成细碎噪点。
- 脚底锚点稳定；走跑、转向、攻击、受击、死亡没有跳帧、滑脚、身体分离或跨方向身份漂移。
- 预警、伤害反馈、血盾与 Q1 墨效可读，场景纹理不掩盖危险范围。
- 正确经过前景墙体遮挡，原墙体碰撞与新可见边界没有“空墙”和误导通道。
- 首房四个 minion 同屏；包含远端、近端、侧面、攻击、受击与死亡运动段。

规则和生命周期检查：

- 同一输入路线下，Sim/Session/Director 身份、位置、碰撞、资源、伤害、技能事件与结算不变。
- 开启/关闭 skin 前后，不增减游戏事件或 combat_event 连接，不改变源 clock。
- 原 clip/time、cast socket、受击偏移和 Boss 最终 pose 可对照；重复时间与暂停保持冻结。
- 商店/成长面板、选英雄返回、换房、死亡、重新开局不残留旧图、阴影、附件或错误 owner。
- 资源缺失/导入失败有明确状态与可撤销回退，不把静态占位称为完成。
- 本方案未执行这些测试。既有 worldfx/UI 功能通过与英雄样板通过不能替代本项。

## 8. 推广七类与恢复交付

推广顺序：首房 + minion → armored/ranged/pouncer → elite/support → Boss。保持同一 skin 接口，不改原 Reader/Cursor/Host/Session。pouncer 增加 leap；Boss 增加 A/B/C 和转阶段，并在原 art02 完成 pose 后取样，单独检查脚底、武器、岩石与预警。

当前首层服务节点继续使用共享房间；如需区分休息/训练，只加没有碰撞和互动含义的显示变化，不生成新玩法。

每阶段都保存：可编辑原创源、运行图集、代码、动作/方向契约、导入配置、基线与新增文件哈希、原 visibility 恢复规则、核查结果和原生证据。每个阶段独立封存并验证字节，不能只留截图或一份已导入缓存。不得覆盖正式 3044 文件基线或以后已验证的英雄共享入口。

本次没有找到可验证可复用的已恢复卡通房间/敌人包。正式目录中的实际实现仍为上述 GLB 与房间几何。世界 FX/UI 恢复不能称作场景敌人卡通完成；没有字节或清单证据的旧成果不能继承通过结论。本方案及后续新资产应标为新候选。
