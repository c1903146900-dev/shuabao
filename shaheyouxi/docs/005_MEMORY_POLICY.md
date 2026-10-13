# 005 当前资源准入政策

适用范围仅为已实证dot桌面启动器→本项目唯一标题终端→Python wrapper的cgroup v2 namespace根。exec环境没有该挂载，失败关闭；不将宿主MemAvailable用作替代。

root于2026-10-04 19:38提供环境级保守公式，现按原式实现：
- raw = memory.max − memory.current
- eligible = max(0, inactive_file − shmem − file_dirty − file_writeback − file_mapped)
- effective = raw + floor(eligible / 2) + min(floor(slab_reclaimable / 4), 128MiB)

重复扣除可能重叠是刻意保守；不计active_file、anon或不可回收内核。此信用是预算估算，不能声称缓存必然立即可回收；不删除数据、不执行全局drop_caches。

准入仍要求effective至少1200MiB（自有峰值预算300MiB＋运行余量900MiB）；raw独立要求启动至少492MiB（192MiB紧急底线＋300MiB预算）。运行effective不得低于900MiB，raw不得低于192MiB。

每次命令前、运行约100ms周期、命令结束和最终收口均核内存及初始OOM计数；oom/oom_kill/oom_group_kill任一变化失败关闭。runner新建专用进程组RSS采样（probe内Godot继承该组）超过300MiB也停止，失去活进程RSS不能默认为0。子进程45秒/整套110秒守卫；异常仅清理自己新建进程组，TERM有界后KILL，组未清空不能成功。

memory.stat及memory.events所需字段缺失或损坏失败关闭；memory.pressure当前不存在允许记null，不伪造压力读数。完整快照、raw/effective观测最低值、自有RSS采样峰值、命令/退出/预期失败、收尾都落本项目证据。

已有19:36原始快照按新式离线计算effective为1081966480B，仍低于准入。这是旧快照演算，不代表当前实时可用或已准入。新版仅纯Python115项与静态复核通过，须下一批准窗口guard-only实读，之后另取005窄引擎窗口。

20:05首轮实际窄矩阵准入后，在首进程刚启动时因task/children接口缺失失败关闭；仅自有import进程TERM退出且组空，没有进入测试或网络。20:10轻量自有Python进程证明本环境status与getpgid组枚举可用且children接口确实缺失；该路线替代不可用的树遍历，仍拒绝缺失活RSS。真实引擎验证尚待重试。
