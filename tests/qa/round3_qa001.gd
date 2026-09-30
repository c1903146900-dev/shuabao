extends SceneTree
var results=[]
func check(ok,label,details={}):
 results.append({'check':label,'passed':ok,'details':details.duplicate(true)})
func _initialize():
 for source_root in ['/workspace/shuabao-progression-fix','/workspace/shuabao-catalog']:
  var m=load(source_root+'/scripts/progression/model.gd').new(JSON.parse_string(FileAccess.get_file_as_string(source_root+'/data/progression/fixture.json')))
  m.command('seed','reward_minion',{'event_id':'seed','gold':100,'xp':0})
  m.command('context','context',{'phase':'safe','training':true})
  m.command('buy','buy',{'item':'component'});m.command('sell','sell',{'uid':1});m.command('body','buy_body')
  var before=m.snapshot();var r=m.command('unauthorized-undo','undo_shop')
  check(not r.accepted and r.reason=='insufficient_gold' and m.snapshot()==before,source_root+': unaffordable undo atomically rejects',{'receipt':r,'gold':m.state.gold,'body':m.state.body,'undo':m.state.shop_undo})
  m.command('topup','reward_minion',{'event_id':'topup','gold':50,'xp':0});before=m.snapshot()
  check(m.command('unauthorized-undo','undo_shop')==r and m.snapshot()==before,source_root+': failed receipt replay cannot later mutate')
  r=m.command('new-undo','undo_shop')
  check(r.accepted and m.state.gold==0 and m.state.inventory.size()==1 and m.state.body.size()==1 and m.state.shop_undo.size()==1,source_root+': new request exact funds restores sale and keeps body')
  before=m.snapshot();check(m.command('new-undo','undo_shop')==r and m.snapshot()==before,source_root+': successful replay no double undo')
  r=m.command('undo-purchase','undo_shop');check(r.accepted and m.state.gold==100 and m.state.inventory.is_empty() and m.state.body.size()==1,source_root+': remaining original purchase undo preserves irreversible body')
 var f=FileAccess.open('res://tests/qa/round3_qa001.json',FileAccess.WRITE);f.store_string(JSON.stringify(results,'  '));f.close()
 print(JSON.stringify(results))
 quit(1 if results.any(func(r):return not r.passed) else 0)
