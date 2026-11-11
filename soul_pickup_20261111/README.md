# G10 战魂拾取可见性隔离候选

状态：源代码已完成，静态合同检查 49/49 通过。没有启动引擎，没有 GDScript 解析/类型检查或实机画面通过。不得合入通过版。

## 具体缺口与范围

原始 G10 已能在真实击杀后生成战魂，并通过原有距离判断拾取、重置已学习 Q/E；当前风厉表现链不消费 live souls，玩家看不到拾取物。本候选接通这一可操作性缺口，不声称新增 G10 规则。

- 小型青色漂浮光体、很淡的真实半径地面环，最后四分之一寿命渐隐。
- 所有地面实体直接读取当帧原始 souls 的位置和 left。没有事件伪造的实体、镜像列表或额外倒计时。
- 拾取火花只接收原 common bridge drain 中的真实 soul_pickup，保留 event_id/位置，不猜测 entity_id。
- 暂停沿用世界时间；战后、死亡、源数组清空、房间/代际/实例变化即停止显示。0.35 秒仅为拾取火花的表现时长。
- 无新文字、按钮、输入、资源、价格、伤害、生成条件、范围或奖励变更。原图形、音频素材均未复制或修改。

当前数值来自未改变的 __clean_fengli/hex.bin 的 hexes.common_g10.values：24 次普通击杀、战魂持续 8 世界秒、生成间隔至少 8 角色秒、拾取半径 1.2 米；拾取后 25% 移速持续 3 角色秒。公开证据仅含现有运行源码和参数字段，私有文档及引用未包含。详见 RULE_EVIDENCE.json。

首层可达性是静态推导，不是试玩通过：r01a → r02a → r03a → r04a → r05a 为合法路径，前四房共有 20 名普通敌人。此前选择 G10 后，第五房先击败精英并留下普通敌人，原精英分支即可生成可拾取战魂。所有第五行节点都有精英及普通敌人。若击败房间最后一敌，原 end_room 会清空战魂，本候选没有延长到战外。

## 交付

- changes/fengli_route_20261024/：仅两个实际变动源文件。presentation.gd 接线；soul_pickup_view.gd 只读消费。
- soul_pickup.patch：精确基线上的完整最小差异，包括新 helper。
- SOURCE_HASHES.json：基线及 overlay 摘要。
- tests/check_static.py 与 STATIC_QA.json：49 条源合同/哈希/补丁检查，通过原 runtime 的全部 257 项 manifest 绑定。测试不执行 GDScript，不能替代引擎验收。
- tests/observe_souls.gd：仅编写，未运行。无 SceneTree 自动入口；在已有认证 Boot 和原守卫允许的 fixture 流程中加载后显式调用 run()。会使用明确 G10/技能选择、致死伤害和生命周期 fixtures，不是自然首层通关证据。observe_frame(host) 是只读实机记录接口。

应用位置为原 4112ebb636b77732788de4ed57d3d75f4dae67b488c9e76c063b8061a2e37c93 包所对应的独立 runtime 副本。保留通过版不动。manifest/generation/PCK 的正常封包由父任务负责；本目录没有改守卫或生成新发布包。

静态检查复现：

    python tests/check_static.py --runtime /path/to/exact/baseline/runtime --output STATIC_QA.json

## 后续必须通过的原守卫实机 QA

1. 自然选到 G10，沿正常地图进入第五行精英房；先击败精英，留一名普通敌人，确认只有真实掉落处出现光体。
2. 对照 observe_frame 的 source_souls 与 rendered.souls，检查位置、剩余寿命和原拾取范围。截图/录像检查光体可见、不会遮挡敌人或误读成攻击范围。
3. 范围外不拾取；实际踏入原范围后实体消失、短闪一次、原 Q/E 重置。重复读取或重播事件不额外闪烁。
4. 暂停冻结、8 秒原寿命到期、战后清理、死亡、换房、退出重开均不留下光体或火花。
5. fixture 与 UI 结果分开记录，所有运行遵循原进程/资源守卫。没有运行批准或守卫拒绝时停止，不更换引擎、模式或守卫规避。

## 封包状态

纯Python封包完成，258项绑定校验通过。PCK SHA256 为 a57845528297edb361c211f9df2d8bae9586a80a041da57aee3780dd780a85a1。只新增/修改两份表现源码及manifest/generation，所有玩法源码逐字不变。未启动引擎，不是运行通过版本；4112ebb6仍为通过基线。
