# 有限sink门fix01：按真实普攻节拍等待，失败关闭

只修测试夹具，不改Sim、selector、Model/Bridge、source数值、旧c997、原stage或原失败。原main selector25,349/288轮和HP185均0失败；sink467断言、137失败保持原样。

原helper每次固定等1.1秒，原ATK-2为0.85次/秒，即1.176470588秒。前次basic附带推进.02秒后，下次实际只等1.12秒，仍差.056470588秒。原日志未记录拒绝reason，因此这份source结论只是有明确数字支持的定位。新门先原样复现这一间隔，必须由main实际执行确认reason=cooldown、拒绝不产生damage/kill事件；再自然推进剩余CD并让同一目标实际死亡。这个probe不过则不许宣告定位成立。

修正helper读取当前CD和实际attack_speed，普通fixed-step推进至少一个实际攻击间隔，不清CD、不伪造死亡、不写金币/SP。每次匹配唯一当前目标kill，核对source=attack及cast_id>0，再用原verify→observe_live_event→同账本奖励。无kill不再调用空数组back，相关用例失败关闭。

每个用例必须运行到自己末尾写完成标记。遗漏、提前返回、GDScript运行中止会触发总门的case未完成失败。hooks_tested只列完成且无失败的用例。G05/G24/G30旧observations中的期望常量不能当实测；新结果从实际变量记录cooldown、wallet、HP、防御、damage，另带逐命令返回和逐kill来源回执。

main：先verify_source.py（仅读取hash和写本目录清单），用prepare_stage.py --dest全新目录，再串行跑fix01/sink_gate.gd。可重跑原selector_gate.gd与hp_regression_gate.gd，但它们的运行源码与c997完全相同。普通ready仍未改；此门通过后再做normal HexUI。
