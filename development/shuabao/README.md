# 刷宝开发候选快照

## 版本与入口

- 仓库根目录仍保留原有刷宝 Godot 工程，入口是根 `project.godot`，主场景为 `res://scenes/integration/room.tscn`。本次不替换或迁移它。
- `c02-revision06/` 是 candidate40 重建过程中 C02 第06版的公开、非运行文本快照，不是完整工程，不是恢复的 candidate39，不是正式发布版本。
- 实际测试使用完整 candidate40 重建工程。这里仅保存19份相关源码/绑定文件；其余依赖、资源和入口未复制。不要把这些文件覆盖到仓库根目录后直接运行。
- `development/.gdignore` 用作根工程的静态导入隔离边界。本次未执行根工程导入、导出或重复类名验证，不能据此声称运行隔离已实测。

## 阅读顺序

1. `c02-revision06/rules/confirmed_rules.json`：正式规则内容。
2. `c02-revision06/provenance/recovery_sources.json`：恢复版本与来源边界。
3. `c02-revision06/evidence/test_summary.json`：完整候选工程的限定验证结果及未覆盖范围。
4. `c02-revision06/source/`：第06版源码派生快照。
5. `c02-revision06/PUBLIC_MANIFEST.json`：实际公开文件哈希及净化记录。

源绑定和转换记录中的哈希是原始完整候选工程的技术来源记录，不代表该公开快照可运行或依赖齐全。公开版移除了私人会话标识和聊天引文，实际文件哈希以 PUBLIC_MANIFEST 为准。源码文件内旧的静态状态标签保留其封存时含义；后续测试结果以 evidence/test_summary.json 为准。

本次不包含个人聊天、私人文档链接、环境凭据、引擎、缓存、依赖包、二进制资源或发行包。沙盒另存仓库下 `shaheyouxi/`，当前仅为同步占位。
