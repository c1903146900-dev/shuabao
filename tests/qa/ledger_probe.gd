extends SceneTree
func _initialize():
 var model = load('/workspace/shuabao-progression/scripts/progression/model.gd').new(JSON.parse_string(FileAccess.get_file_as_string('/workspace/shuabao-progression/data/progression/fixture.json')))
 var steps = [
  ['seed','reward_minion',{'event_id':'fixture-gold','gold':100,'xp':0}],
  ['training','context',{'phase':'safe','training':true}],
  ['buy','buy',{'item':'component'}],
  ['sell','sell',{'uid':1}],
  ['body','buy_body',{}],
  ['undo','undo_shop',{}]]
 for s in steps:
  var receipt = model.command(s[0],s[1],s[2])
  print(JSON.stringify({'action':s[1],'receipt':receipt,'gold':model.snapshot().gold,'inventory':model.snapshot().inventory,'body':model.snapshot().body}))
 print('NEGATIVE_WALLET_REPRO=',model.snapshot().gold < 0)
 quit()
