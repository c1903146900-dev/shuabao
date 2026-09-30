extends SceneTree
var Model=load('/workspace/shuabao-progression/scripts/progression/model.gd')
var base=JSON.parse_string(FileAccess.get_file_as_string('/workspace/shuabao-progression/data/progression/fixture.json'))
var total=0
var coverage={}
var violations=[]
func asset_value(st,cfg):
 var value=0
 for item in st.inventory:value+=int(cfg.items[item.id].price)*int(item.count)
 for body in st.body:value+=int(body.cost)
 return int(st.gold)+value
func run_case(seed_value,policy,stacking):
 var cfg=base.duplicate(true);cfg.potion_policy.mutex=policy;cfg.potion_policy.normal_stack=stacking
 var m=Model.new(cfg);m.command('seed','reward_minion',{'event_id':'seed-death','gold':400,'xp':0});m.command('context','context',{'phase':'safe','training':true});m.command('level','enter_level',{'combat_level_id':'start'})
 var rng=RandomNumberGenerator.new();rng.seed=seed_value
 var journal=[];var sunk=0;var trace=[];var saved_requests=[]
 for n in range(160):
  var before=m.snapshot();var selection=rng.randi_range(0,15);var action='';var args={};var id='random-'+str(n);var is_replay=false;var old_receipt={}
  var uid=-1
  if not before.inventory.is_empty():uid=before.inventory[rng.randi_range(0,before.inventory.size()-1)].uid
  match selection:
   0,1,2,3:action='buy';args={'item':['component','blade','normal','special'][selection]}
   4,5:action='sell';args={'uid':uid}
   6,7:action='undo_shop'
   8,9:action='buy_body'
   10:action='use_item';args={'uid':uid}
   11:action='context';args={'phase':'safe','training':true}
   12:action='context';args={'phase':'combat'}
   13:action='enter_level';args={'combat_level_id':'room-'+str(rng.randi_range(0,3))}
   14:action='reward_minion';args={'event_id':'seed-death','gold':400,'xp':0}
   15:
    if saved_requests.is_empty():continue
    var saved=saved_requests[rng.randi_range(0,saved_requests.size()-1)]
    action=saved.action;args=saved.args;id=saved.id;old_receipt=saved.receipt;is_replay=true
  var receipt=m.command(id,action,args);var after=m.snapshot();total+=1
  var label=action+(':'+str(args.get('item','')) if action=='buy' else '')+(' replay' if is_replay else '')+(' accepted' if receipt.accepted else ' rejected')
  coverage[label]=coverage.get(label,0)+1
  trace.append({'id':id,'action':action,'args':args,'accepted':receipt.accepted,'reason':receipt.reason})
  var error=''
  if is_replay:
   if after!=before or receipt!=old_receipt:error='replay_mutated_or_changed_receipt'
  elif not receipt.accepted:
   if after!=before:error='failed_transaction_mutated_state'
  else:
   if action in ['buy','sell']:
    var loss=0
    if action=='sell':
     for item in before.inventory:
      if item.uid==uid:loss=int(cfg.items[item.id].price)*int(item.count)-int(floor(int(cfg.items[item.id].price)*int(item.count)*.9))
    sunk+=loss;journal.append(loss)
   elif action=='undo_shop':
    if journal.is_empty():error='undo_without_external_transaction'
    else:sunk-=int(journal.pop_back())
   elif action=='use_item':
    for item in before.inventory:
     if item.uid==uid:sunk+=int(cfg.items[item.id].price)
    journal.clear()
   elif action=='context' and after.phase=='combat' and before.phase!='combat':journal.clear()
   elif action=='enter_level' and after.combat_level_id!=before.combat_level_id:journal.clear()
  if not is_replay:saved_requests.append({'id':id,'action':action,'args':args.duplicate(true),'receipt':receipt.duplicate(true)})
  if asset_value(after,cfg)+sunk!=400:error='asset_conservation'
  var ids=[];var normal=0
  for item in after.inventory:
   if item.uid in ids or item.count<=0 or item.invested!=int(cfg.items[item.id].price)*int(item.count):error='inventory_identity_or_cost'
   ids.append(item.uid)
   if item.id=='normal':normal+=int(item.count)
  if normal>5 or after.inventory.size()>6 or after.special_uses>2:error='inventory_or_usage_limit'
  if after.gold<0 and error=='':error='KNOWN_QA001_negative_gold'
  if error!='':
   violations.append({'kind':error,'seed':seed_value,'policy':policy,'stacking':stacking,'step':n,'trace':trace,'after':after,'sunk':sunk});return
func _initialize():
 for policy in ['holding','per_level_use']:
  for stacking in [false,true]:
   for seed_value in range(1,25):run_case(seed_value,policy,stacking)
 var counts={}
 for v in violations:counts[v.kind]=counts.get(v.kind,0)+1
 var report={'baseline':'607bf6385f5f668155aa76f5df6eb184e5685cea','attempted_commands':total,'cases':96,'coverage':coverage,'violations_by_kind':counts,'violations':violations}
 var f=FileAccess.open('res://tests/qa/round2_economy.json',FileAccess.WRITE);f.store_string(JSON.stringify(report,'  '));f.close()
 print(JSON.stringify({'attempted_commands':total,'cases':96,'coverage':coverage,'violations_by_kind':counts}))
 quit()
