extends SceneTree
const Model=preload('res://scripts/progression/catalog_model.gd')
const Legacy=preload('res://scripts/progression/model.gd')
var cfg=JSON.parse_string(FileAccess.get_file_as_string('res://data/progression/prototype/catalog.json'))
var results=[]
var serial=0
func check(ok,label,data={}):results.append({'check':label,'passed':ok,'data':data.duplicate(true)})
func send(m,action,args={}):
 serial+=1
 return m.command('independent-'+str(serial),action,args)
func reject(m,action,args,reason,label):
 var before=m.snapshot();var r=send(m,action,args)
 check(not r.accepted and r.reason==reason and m.snapshot()==before,label,{'receipt':r})
func _initialize():
 var m=Model.new(cfg)
 check(m.catalog_errors.is_empty(),'unchanged prototype catalog validates')
 send(m,'reward_minion',{'event_id':'seed','gold':50000,'xp':100000})
 for id in cfg.items:reject(m,'buy',{'item':id},'unsupported_effect','default hooks closed '+id)
 reject(m,'buy_body',{},'unsupported_effect','default body closed')
 reject(m,'hex_open',{'milestone':1},'pool_exhausted','default numeric hex pool closed')
 var all_hooks=[]
 for family in [cfg.items,cfg.hexes,cfg.passives,cfg.body.outcomes]:
  for defn in family.values():
   for hook in defn.required_hooks:
    if not hook in all_hooks:all_hooks.append(hook)
 for hook in cfg.body.required_hooks:
  if not hook in all_hooks:all_hooks.append(hook)
 m.set_supported_hooks(['stats.v1'])
 reject(m,'buy',{'item':'iron_blade'},'unsupported_effect','generic stats flag alone cannot enable AD purchase')
 var without_ap=all_hooks.duplicate();without_ap.erase('stat.AP.v1');without_ap.erase('recovery.v1')
 m.set_supported_hooks(without_ap)
 for id in cfg.items:
  if cfg.items[id].stats.has('AP') or cfg.items[id].kind in ['normal','special']:
   reject(m,'buy',{'item':id},'unsupported_effect','missing specific consumer '+id)
 var drafts=[]
 m.set_supported_hooks(all_hooks)
 for id in cfg.hexes:
  if cfg.hexes[id].status=='unsupported':
   drafts.append(id);check(not m.support(cfg.hexes[id]).supported,'draft cannot unlock even with all declared hooks '+id)
 check(drafts.size()==19,'all nineteen mechanism drafts covered')
 # Capability declarations enable data transactions, not any actual battle consumer.
 var purchase=send(m,'buy',{'item':'iron_blade'})
 check(purchase.accepted and m.equipment_effects().stats.AD>0,'declared AD supports data projection ONLY')
 var checkpoint=m.save();var clone=Model.new(cfg);check(clone.restore(checkpoint),'restore compatible checkpoint')
 check(clone.supported_hooks.is_empty() and clone.equipment_effects().stats.is_empty(),'checkpoint cannot restore capabilities or activate owned effects')
 reject(clone,'buy',{'item':'iron_blade'},'unsupported_effect','restore still fails closed')
 m.set_supported_hooks([])
 check(m.equipment_effects().stats.is_empty() and not m.snapshot().content_warnings.is_empty(),'lost capabilities disable owned effects with warning')
 reject(Legacy.new(cfg),'buy',{'item':'iron_blade'},'catalog_adapter_required','legacy model cannot bypass catalog gate')
 # New catalog body transaction preserves the P1 fix and pending random choice.
 m=Model.new(cfg);m.set_supported_hooks(all_hooks)
 send(m,'reward_minion',{'event_id':'body-seed','gold':950,'xp':0})
 send(m,'buy',{'item':'iron_blade'});send(m,'sell',{'uid':m.state.inventory[0].uid});send(m,'buy_body')
 var before=m.snapshot()
 reject(m,'undo_shop',{},'insufficient_gold','catalog body pending choice + unaffordable undo atomically refuses')
 check(m.state.gold==5 and m.snapshot().body_pending==before.body_pending and m.state.rng==before.rng,'catalog rejection preserves paid reveal, RNG and balance')
 # Every legal offer generated under all declared hooks still excludes mechanism drafts.
 m=Model.new(cfg);m.set_supported_hooks(all_hooks);send(m,'reward_minion',{'event_id':'hex-seed','gold':0,'xp':100000})
 for milestone in [1,4,7,10,13]:
  check(send(m,'hex_open',{'milestone':milestone}).accepted,'numeric offer opens '+str(milestone))
  for id in m.state.offers[str(milestone)].slots:check(not id in drafts,'mechanism draft absent from offer '+id)
  check(send(m,'hex_select',{'milestone':milestone,'slot':3}).accepted,'select numeric offer '+str(milestone))
 var f=FileAccess.open('/workspace/shuabao-qa/tests/qa/round3_catalog.json',FileAccess.WRITE);f.store_string(JSON.stringify(results,'  '));f.close()
 print(JSON.stringify({'failures':results.filter(func(r):return not r.passed),'scope':'data capability gates, not battle implementation'}))
 quit(1 if results.any(func(r):return not r.passed) else 0)
