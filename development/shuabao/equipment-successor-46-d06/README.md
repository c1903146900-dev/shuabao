# 刷宝：D06破阵甲候选46精确增量

本目录只保存相对已保存候选45的8份修改、9份新增精确源码与有限验证文本。它不是完整独立工程，也没有再次保存缓存、原始进程日志或截图。

## 恢复顺序

1. 在新独立目录复制同仓库 `development/shuabao/candidate43-rebuild/game/` 完整非缓存工程。其首次保存提交为 `42e89c9e6dd470d619c596e5e471882a17b2dcbb`。
2. 按 `development/shuabao/display-successors-44-45/README.md`，依次应用44、45各自的精确manifest。该保存提交为 `419d1992d860867b7087a87d8aecf17d5504255f`。
3. 按本目录 `candidate46_prepare/revision02/REVIEW_MANIFEST.json` 核验全部before。新增项必须不存在。只把 `production_draft/` 内17份文件按工程相对路径写入，再核全部after。
4. `PARENT_PREIMAGE_REFERENCES.json` 指向8份已保存的45前像；`ANCESTOR_PREIMAGE_REFERENCES.json` 指向20份不变的canonical祖先前像。每项都附完整SHA256、Git blob身份、大小与持久提交路径，不必重复复制已保存字节。
5. 恢复后的入口仍为原 `project.godot`。source为 `bd7004e97cd0d35c6168201b507d06fd22e816a9734601c229cfb69a0fb99643`，visual为 `ab03df0afc573452879dd2b478bb1a627e79a5cde845d31ae689a1ad128bef81`；绑定范围1759 core/72 visual/8交集/20祖先。干净无缓存克隆导入尚未验证。

原REVIEW_MANIFEST的“未应用、未运行”状态是制作该清单时的历史记录，不应改写原字节。后续46已独立复制，实际有限验证以本目录validation两份冻结摘要为准。本包没有将46通过证据自动转给后继候选。

## 本次功能与有限验收

D06正式价格3150、生命400、防御30、韧性35%、移速8%；I08＋I16＋B07与400合成费。实际韧性眩晕自然结束后获得3秒的20%移速、15%最终伤害、30%韧性；刷新不叠层，售空及战后清除。当前只接已有真实眩晕来源，没有创造定身、硬直或击退触发。

伤害126、重入177、C02组合187、商店固定说明83分别联合通过；定义176和生命周期372仅业务通过，退出RSS观察失败仍保红。控制refresh/duplicates阶段通过，但原297整门因测试目标种类错误保持失败。早期失败及91条GUI警告均保留，禁止合并计数宣称全绿。完整范围见 `validation/D06_LIMITED_VALIDATION_ZH_FINAL.md`。

测试使用明确的钱包、技术伤害、部分关闭AI和程序驱动时钟等夹具；未宣称自然通关或native输入。没有重新跑全48件战斗回归。原商店战中禁交易，活跃Buff战中出售不可冒充端到端证据。

项目内规则确认片段与不透明来源ID保留原字节以维护绑定；清单中的机器路径只作历史构建出处，不是新机器的执行路径。公开源码不另行授予未声明的第三方素材再分发许可。

最终验收摘要CHECKPOINT06只追加独立审阅者已查看三张GUI图的确认；原CHECKPOINT05保持原哈希留存，资源红和旧失败没有改成通过。
