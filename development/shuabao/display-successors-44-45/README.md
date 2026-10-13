# 展示后继44与45的精确恢复材料

基线是同仓库 `development/shuabao/candidate43-rebuild/game/` 的完整43（首个保存提交 `42e89c9e6dd470d619c596e5e471882a17b2dcbb`）。这里分别保留44的4份及45的5份原始变更文件和各自审查清单，不能只取最终6份独特路径而遗漏中间绑定字节。

## 恢复顺序

1. 在一个新的独立目录复制完整43非缓存工程；不要覆盖仓库根刷宝原型或冻结43。
2. 按 `candidate44_prepare/revision02/REVIEW_MANIFEST.json` 逐路径核现有SHA256与 `before` 一致；`before` 为null时必须不存在。将该目录 `production_draft/` 下4份文件按相对路径写入独立工程，再逐份核 `after`。
3. 按 `candidate45_prepare/revision01/REVIEW_MANIFEST.json` 同样核验44前像，再写入其5份精确字节并核后像。保留44新增的Q2展示transition。
4. 以恢复目录下 `project.godot` 为独立入口。源码包含历史路径与绑定.import描述；净克隆导入/启动尚未验证，不能自行导入重写后又还原绑定文件来冒充验证通过。

`candidate43_limited_validation/DISPLAY_SUCCESSOR_SELECTION.json` 的artifact相对路径在本目录中原样成立；`PUBLIC_MANIFEST.json`核所有保存文件的精确字节。原REVIEW_MANIFEST中的engine_run/copy_applied字段是制作该清单时的历史状态，后续实际验证以validation摘要为准。

## 有限验证

43：定义178联合通过；真实伤害343业务通过但退出采样资源门失败；GUI44与成长183分别在限定场景联合通过。44展示修正17、45 tooltip75分别联合通过并完成所列截图审查。不能把这些相加宣称整款游戏或完整战斗验收。

45只修成长提示的显示换行；原规则与按钮连接保留。测试使用程序输入，未验证native输入；900×600窗口仍缩放原1280×720逻辑画布。警告、技术夹具、资源采样局限和未净克隆边界均在原摘要内保留。这里不包含私有raw、身份、缓存或截图，也没有再次运行引擎。
