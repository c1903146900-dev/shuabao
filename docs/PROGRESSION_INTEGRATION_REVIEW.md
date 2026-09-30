# 成长模型独立集成审阅

源提交：`607bf6385f5f668155aa76f5df6eb184e5685cea`。仅新增 data/progression、scripts/progression、scenes/progression、tests/progression 与 docs/PROGRESSION_PROGRESS.md，未越权修改战斗/UI/默认入口。集成修复：`1fcdb28f63a5e1de30f95da821bfa038e096162e`；合并：`6a4e63a781fa9cb2108f3decc349c098228b9e88`。未修改或推送源任务分支。

## 找到并修复的问题

独立复跑原始 274 项测试通过，但不足以证明所有交错事务安全。新增复现：起始100金币→买100组件→卖出得90→买50锻体→撤销卖出。原版接受最后一步，恢复组件、保留锻体，金币由40变成−50。缺陷是撤销直接应用负金币差额，没有检查卖出所得是否已用于不可逆购买。

修复先读取撤销栈顶并检查 `gold + gold_delta >= 0`，余额不足返回 insufficient_gold，不弹栈、不改库存或锻体；实际余额后来足够时，可用新命令正常撤销。保持原 LIFO 及失败回执幂等语义，不通过退掉锻体支出来“修复”余额。模型修复经真实 Godot MCP create_script/validate_script 写入并校验后复制回源码；原工具返回保存在证据目录。

新增 `tests/progression/integration_regression.gd` 与入口 integration_run.gd。修复前17项检查中6项失败；修复后17项全通过，原274项仍全通过。关键新增断言是拒绝后的完整状态不变、失败重放无副作用、后续资金到账可撤销、再撤销原购买仍恰好保留50锻体支出，以及洗点不影响该账本。测试修复的是跨操作组合，未修改经济夹具数值来规避错误。

## 重点审阅结论

| 项目 | 结论与证据边界 |
| --- | --- |
| 18点守恒 | 首级1点、XP跨级授点、封顶18；P/Q/E/R最大阶数3/5/5/3，R成本1/2/2。独立重算满配已花18，洗点返实际成本。confirmed_rules 的R后两阶仍null，fixture的6/6/6不是正式门槛 |
| 买卖合成撤销 | 组件先消耗、实际投入抵价、失败回滚；原有20轮完整逆操作无套利通过。新增不可逆消费交错缺陷已修复。90%卖价及经济内容按当前模型/测试定义核验，不由此宣称完整正式商店已完成 |
| 药品策略 | 堆叠与互斥范围位于显式 potion_policy；夹具标 experimental_not_final，正式 confirmed_rules 不含默认策略。缺政策原子拒绝，普通≤5、特殊每稳定关ID≤2；不可把每波/每房默认成新关 |
| 恢复效果 | use_item 消耗后返回 recovery_requested，不直接修改HP；正式协调层必须在提交前检查治疗定义/合法时机。未实现跨模块原子治疗，不能把消费测试当治疗验收 |
| 锻体 | 独立不可逆账本，重复同价购买，交易撤销/洗点不退支出、不抹属性；负余额漏洞已阻断 |
| 海克斯刷新 | 右槽英雄专属、已选/同轮排除/其它未决offer展示去重；每槽一次刷新，重复同ID不推进RNG，新ID重复刷新被拒。耗尽失败还原 seen、RNG、offers |
| 随机状态 | JSON checkpoint后继续刷新返回及完整快照一致；LCG和见过降权公式是测试抽样方案，不宣称公平性、安全随机或正式概率定稿 |
| 休眠与其它未定策略 | 当前模型有按requires激活/休眠的投影；正式适配须以最新获批合同核对，不能从测试成功推定全部玩法策略已获用户确认 |
| 模型隔离 | 模型无HP/CD引用，但这不证明战斗端换技能、洗点后不刷新CD；正式接入仍按可玩矩阵验收 |
| 存档与权限 | restore仅可信同版本本地checkpoint；未做外部存档校验/迁移或联机权限。reward_minion/context/enter_level必须由权威协调层持有，不能直接暴露给UI。回执重放会返回原events，消费方仍需按命令ID去重，不能再次执行治疗等外部副作用 |

## 独立复现命令

```sh
mkdir -p .local/cache .local/config .local/data
export XDG_CACHE_HOME="$PWD/.local/cache"
export XDG_CONFIG_HOME="$PWD/.local/config"
export XDG_DATA_HOME="$PWD/.local/data"
godot --headless --path . --script tests/progression/run.gd
godot --headless --path . --script tests/progression/integration_run.gd
bash scripts/check.sh
```

项目导入和最小启动实际通过、SHUABAO_BOOT_OK。仅证明合并没有破坏骨架，不是可玩战斗通过；本轮没有更新导出包，没有接入未交付战斗/UI。原任务历史manifest对应修复前模型哈希，不能冒充当前源码证据；本轮单独保存结果于 docs/validation/progression-integration。

## 独立 MCP 场景复核

修复后运行源码副本，经 MCP 验证并保存重开成长场景：最终20步工作流通过，运行场景内原274项检查通过，实际买组件/合成、Q学习、海克斯刷新/重复拒绝/选择和安全/战斗阶段演示查询通过，截图已打开检查。它是英文诊断面板，不是正式UI或真实键盘战斗。新增17项回归在合并后的main无头运行通过。

曾尝试在额外 MCP 表达式中直接 load 测试脚本，上游返回 On call to 'load' 错误；该额外调用失败已保留，没有把17项无头回归冒称MCP执行。随后使用受支持的既有场景方法，完整20步复核通过。GUI已结束，默认main场景保持不变。
