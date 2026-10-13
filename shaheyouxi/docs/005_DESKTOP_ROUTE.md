# 005 自有终端验证入口

首次尝试已保存为005_guard_desktop_attempt_20261004T1847.json：工具明确拒绝同标题同尺寸窗口输入，未执行任何守卫或引擎命令。自有新窗口已关闭，旧窗口不操作。

下一次明确CUA窗口中，先用系统“Run Program...”启动器（清楚单独窗口身份），执行：

```
xfce4-terminal --disable-server --title=SHAHEYOUXI-GUARD-005-20261004 --command="bash /workspace/shared/shaheyouxi_project/tools/desktop_guard_only.sh"
```

Xfce官方命令行说明核对了disable-server、title与command参数：
https://docs.xfce.org/apps/xfce4-terminal/command-line

独立新进程、唯一标题，不修改共享设置。通过新窗口ID和唯一标题核身份后仅观察退出结果；脚本固定guard-only，零引擎。完成按Enter关闭；即使无法输入，20秒自动退出。再从窗口清单确认自有窗口消失，回读本项目证据核cgroup字段，不用屏幕数字替代文件记录。

支持的cgroup路线严格要求namespace根0::/、cgroup2 root /及匹配挂载点；不满足即失败关闭，不临时改为宽松放行或绕过窗口身份检查。
