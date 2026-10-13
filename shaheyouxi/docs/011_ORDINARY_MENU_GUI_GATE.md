# 普通菜单真实流程的有限验证候选

本次目标是 Linux 上实际点击新建、两轴 WASD、完整释放、F10 返回菜单、点击继续同槽、再次移动保存，最后点击退出。生产菜单、Coordinator、Client、server 与 30 秒启动/20 秒关闭值不变。仅测试 observer 继承菜单读取信号及公开快照，不调用产品操作。完整 Windows 导出与真实 Windows 运行仍未验证。

## 来源与观察范围

- 新 observer 只输出字段白名单；实际槽位路径单独写 private-location.json，留在私有 runtime
- 初始/完成时只作有界原档字节快照；退出并确认整个自有谱系清空后，外部验证器再解码、核两次保存及静态根/身份/位置
- private identity、resume_secret、secret_hash 和完整 state 不进入公开回执或累计包
- 640 MiB 为受控候选：GUI 原组及已证辅助后代384，独立已证 server 及后代192，controller64；旧 GUI 全任务峰436.043 MiB 和另一次 headless152.137 MiB 不相加
- 初始 effective1540/raw832 MiB；每次完整 owned RSS 采样后保留未用预算 extra=max(0,640MiB-totalOwnedRSS)，要求 effective>=900MiB+extra、raw>=192MiB+extra。这是采样启发式，不是内核内存预留或同步逐spawn准入
- 外层 GUI90秒、总110秒。操作目标每次首次可见有效快照后15秒内完成按键释放与F10；不预称两局一定能在该窗完成

## 进程归属

Godot Unix create_process 会 setsid。仅使用已pin授权基础设施的 OwnedTree、pidfd、进程内 subreaper；source manifest列来源hash、原文段及仅导入改写。普通parent真实回收的server与controller收养回收分开记录，不以命令行替代归属证明。

资源/遥测失败采用立即TERM→KILL，实际grace为0，最大允许间隔0.1秒；OOM/raw急线直接KILL。6秒只用于回收与全谱系空的确认。若仍不确定则保留句柄/subreaper进入HOLD，禁止新软件，不自动循环kill；协调者的新取消信号只请求一次有界重试。正常完成恢复进程内设置并关闭fd。

已知严格限制：子进程在inventory之后、pidfd_open之前消失，目前仍红。尚未纳入另一个待验vanished-child候选；不能借此忽略未知短进程或假称其峰值已测。

## 当前证据

- Ordinary8、Slots8、Windows generation8 已分别通过；早期发现期错误、NUL夹具错误及raw JSON日志错误全部保留
- 完整 Store+terrain 的 Linux Windows-layout 单例实际10.993秒、29次回调、恢复零生成；这不是 Windows OS 证明
- 本次normal-only tiny已实际通过：Python parent→独立setsid child，父真实wait，held parent pidfd lineage，完整清理/终端消失/reset
- failure/adoption/TERM-ignore tiny、observer 的 Godot 编译及普通菜单真实GUI均待独立窗口
