# 010 权限与单快照保存审阅请求

2026-10-05 05:36 UTC。实现者自查，尚未独审、尚未运行Godot；197项纯Python检查通过（含3项新runner模拟）。请求root独立读取下列关键源。010限定真实联机技术世界生命周期，formal_world_allowed始终false，人物操作011后置。

## 最小审阅路径
- game/scripts/world_session/world_network_main.gd：服务端/Host强制保存目录；prepare来源校验；create只在新档分支调用；restore先全状态校验再恢复；_public_snapshot只合并公开玩家字段和组件；显式握手合同+bundlehash过滤后才进Authority.join；客户端快照拒绝私有字段且校验世界组件；F10与预期断服仅退出
- game/scripts/world_session/world_component.gd：layout和实际展开Prefab必须绑定同world/body/origin/确定实例ID；未知schema/来源返回recoverable_corruption=false；保存组件绝不含profiles。restore不调用生成器/实例化器/Seed随机源；技术clear仅服务端本地入口，无RPC
- game/scripts/network/network_main.gd与server_authority.gd的diff：复用原RPC authority/any_peer限制；新增服务器内部composition hooks与trusted_public_snapshot参数，客户端命令仍严格登记意图/字段，不能传这个可信参数；普通003/004入口默认行为保留
- game/scripts/save/save_store.gd的diff：额外可选内部validator/schema/sizecap；010选择schema2与组合validator；004默认schema1。只在通过整份组合验证后进入既有main单文件temp/flush/rename；新组件不建另一个保存文件。未知组件兼容错误透传，不标CORRUPT自动回退

## 原子性边界
主档中同一个payload同时含world_id/时钟/revision/自动保存期限/私有profiles及world_component（Seed/完整已生成布局/已展开Prefab）。每次主档成功后写自动备份，备份失败会返回main_committed，沿用原实现显式失败关闭。不是跨多文件事务；没有断电/fsync目录耐久性证明。第一次初始快照在ENet监听前完成。恢复档存在时不调用创建分支，缺主档但有world marker仍按旧保存策略拒绝新建。

## 数据权限与不兼容
- 协议3继续来自权威表。010附加技术会话合同sandbox010-technical-v1与精确bundlehash；旧不支持此合同拒绝
- 客户端无世界Seed/生成/清除修改RPC。模型统计分别记录世界生成/Prefab展开/世界Seed随机，恢复三者应为0；不声称连接epoch和身份secret的系统熵也为0
- private resume文件仅runtime隔离，证据不包含secret；持久快照只存secret_hash，公開快照绝不发profiles/secret_hash/resume_secret
- schema1旧档与未知新组件/source拒绝不回退；迁移属于011.5政策

## 已准备但尚未运行
- 14个组件/视图/私有字段用例，8个组合保存/兼容/回退/公开请求用例
- 第一个单headless窗口：上述22 + 旧保存25 + 权限10，共3串行命令；192 MiB own /900 MiB effective /192 MiB raw，110秒总守卫，首失败停，无editor
- 后续另申请两阶段真实ENet：Host+两客户端→正常关服→新独立服务器+原两身份客户端，共6个PID，峰3；同世界/Seed/全部Prefab/clearrecord/档案ID，恢复不重新生成；客户端真实消费三层Node2D与19对象，另证端口释放
- 网络窗口拟384 MiB自有PGID（包括Python）/900 effective/192 raw，90秒命令/110秒总。既有内部Godot总RSS300 MiB上限仍保留，不自动开跑
- 只读技术视图源码已实现，但真实GUI未运行，不借headless验证冒称实看；呈现布局点/入口代理和房间局部，不等价完整地形、碰撞、生态和可推进玩法

## root独立源审阅 · 05:38
root实读上述关键路径/diff，最小技术范围未发现客户端可传trusted参数、RPC写世界或profiles泄露的明显阻挡；组合快照与未知兼容分类合理，仅属源级审阅。提示先world后authority的部分赋值风险与JSON严格相等：现有组件真实JSON往返用例覆盖后者；8项保存用例之一补坏authority revision使restore在任何赋值/监听/保存前拒绝，校验世界组件仍空、原authority world_id不变且peer/store皆空。方法计数仍22。运行窗口继续等待root明确许可。

## PCK运行目录补审 · 06:08
root独立实读runtime_paths.gd：唯一明确--main-pack、固定文件名/规范绝对路径与source fallback限制适用于当前本机技术包。该检查是词法范围，不提供针对恶意symlink的强隔离，不在报告中称绝对安全。现有7个路径方法内补root目录自身拒绝、runtime2近似前缀拒绝、../留在本runtime内规范化合法/逃出拒绝与重复参数拒绝；不扩运行矩阵。GUI/包运行仍待独立窗口。

## 显式包参数修订（取代引擎参数读取） · 06:12
官方4.6 OS说明get_cmdline_args排除已由引擎处理的参数；main.cpp的--main-pack分支不保留它。所以不再从该API猜运行根。来源： https://docs.godotengine.org/en/4.6/classes/class_os.html#class-os-method-get-cmdline-args 与 https://raw.githubusercontent.com/godotengine/godot/4.6/main/main.cpp 。

打包配置独有sandbox/technical_pack=true，正常源工程无此标志。启动器把相同包路径另显式放在--之后的--package_pck=用户参数，由get_cmdline_user_args获取。只有pack标志true且唯一合法参数才允许包自己的runtime；源模式收到包参数拒绝重定向。缺参/多参/虚拟URI/相对路径/错误文件名/非game目录/非规范物理绝对路径拒绝，不回退cwd或源目录。参数是本机启动器配置，不是RPC授权，不构成抗symlink强隔离。7项路径测试已相应替换，并保留全部root要求负例；Python206通过，真实运行仍待窗口。
