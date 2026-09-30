# 刷宝 · Shuabao

3D 俯视高速 PVE ACT。目标为 1–5 人独立镜头、中文键鼠、Windows 客户端和 Linux 无头专服。

当前为首个可操作的单房间整合 checkpoint：风厉骨骼角色、普通/精英/Boss、真实战斗 HUD 和1级1点修习。战前按 K 选技能，关闭面板进入试炼；WASD移动、左键攻击、Q/E/R技能、Shift冲刺。经验与金币奖励、完整成长循环、联机及存档尚未接入，不是可发布游戏。详见[操作、边界与验收](docs/INTEGRATION_CHECKPOINT_1.md)。

## 打开与检查

使用 Godot **4.6.3 stable** 标准版打开仓库根目录的 `project.godot`，按 F6/F5 运行。Blender **4.3.2** 用于已验证的 MCP 骨骼资产制作。引擎及工具不随仓库分发。

```sh
godot --editor --path .
# 在没有图形桌面的环境执行引擎检查：
bash scripts/check.sh
```

检查脚本仅验证编辑器导入与无头场景启动，不代表画面、MCP、动画往返或导出验证通过。整合链路已完成1280×720真实 MCP 运行与输入路由检查；独立窗口输入、分辨率/压力回归仍待完成。HUD 使用仓库内 Noto CJK 字体，许可随资产提供。

## 文档与模块边界

- [已批准设计](docs/DESIGN.md)：新规则与明确待确认项。
- [技术与制作计划](docs/PLAN.md)：按模块推进与下一步验收。
- [决策记录](docs/DECISIONS.md)：约束、变更优先级和技术暂定项。
- [状态与验证](docs/STATUS.md)：实际验证结果、阻塞和交接。
- [工具链](docs/TOOLCHAIN.md)：版本、来源、许可、接入要求。

只在 `c1903146900-dev/shuabao` 开发。不包含部署配置、云账号凭据或付费服务；不连接阿里云实机。`.local/`、`.godot/` 与构建产物不提交。项目代码的对外发行许可证尚未选定。
