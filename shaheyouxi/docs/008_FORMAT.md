# Prefab v1技术格式

此格式输出technical_prefab_template / technical_prefab_instance。当前几何是explicit_technical_fixture，formal_world_allowed必须为false；不是正式世界状态schema。

## 模板
根保存schema_version=1、template_id、正整数revision、三来源hash、body_content_id、geometry_kind及五组记录：
- layers：local_id、map_kind、depth、bounds=[x,y,w,h]
- objects：local_id、content_id、content_scope、content_namespace、layer_id、plane、rect、blocking、is_liquid
- anchors：local_id、kind（entrance/spawn/container/boss）、layer_id、cell、object_local_id；入口/Spawn无对象引用，容器/Boss绑定有类型的同层对象
- connections：local_id、upper_anchor_id、lower_anchor_id、mode、body_side_cells、safety_side_cells；当前仅母星合法天然层对，明确同XY、3格本体及7格安全区
- protected_areas：local_id、layer_id、rect、reason；允许保护区重叠，不擅增原件未规定规则

local_id全模板唯一。所有坐标是有界整数格，相对origin；四高度面共用XY。字段严格检查，未知字段/版本失败关闭；无默认Seed或随机源。模板数组按local_id规范排序，编辑器数组顺序不会改变运行ID。

正式引用只在当前已支持的命名域解析：content、ground_resource、poi_container。fixture只接受有限technical_fixture清单，不能把fixture_*当正式内容。普通物品登记存在不等于可放置实体。

## 实例
根保存prefab_instance_id、world_id、body_instance_id、body_content_id、origin、template_id/revision/hash以及完整source_template。各记录保存实际展开坐标和地址；对象/锚点/连接实例ID由世界、天体实例、Prefab实例及local_id共同限定，与显示名/数组顺序无关。实例验证逐行核来源、身份、地址和变换，不调用Instantiator。模板后来编辑不会重绘已保存实例。

单模板bounds和几何合法，不代表多个Prefab互不冲突、天体在正式世界注册表中已存在、所有关键模板/材料数量保障完成。010需在正式装配中另验证。

## 技术保存API
PrefabStore.new(generation_document,prefab_document,directory='user://prefab_previews')
- save_template(template,expected_revision='')：空revision只新建；已有模板需当前SHA匹配。相同数据可幂等，修改需revision顺序加1
- load_template(template_id)：只恢复/校验，缺失或损坏不生成
- create_instance(instance)：只新建，不覆盖或重初始化现有实例
- load_instance(prefab_instance_id,expected_world_id)：恢复实际展开数据，拒绝跨world

内部templates/instances分子目录，标识只允许受限token，1MiB是技术单文件安全上限。envelope校验format/kind/id/payload hash；同目录临时文件flush+rename。不是并发写/断电耐久保证，也不是带秘密密钥的防篡改认证。运行私有身份和这些技术测试文件不进入恢复包。
