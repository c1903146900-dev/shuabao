extends SceneTree
const Sim=preload('res://scripts/combat/combat_sim.gd')
const Model=preload('res://scripts/progression/model.gd')
var results=[]
func check(ok,label,data={}):results.append({'check':label,'passed':ok,'data':data.duplicate(true)})
func _initialize():
 var m=Model.new(JSON.parse_string(FileAccess.get_file_as_string('res://data/progression/fixture.json')))
 m.command('fund','reward_minion',{'event_id':'seed','gold':100,'xp':0});m.command('training','context',{'phase':'safe','training':true});m.command('buy','buy',{'item':'component'});m.command('sell','sell',{'uid':1});m.command('body','buy_body')
 var before=m.snapshot();var r=m.command('undo','undo_shop');check(not r.accepted and r.reason=='insufficient_gold' and m.snapshot()==before,'QA001 actual main atomic refusal',{'gold':m.state.gold,'body':m.state.body,'undo':m.state.shop_undo})
 for offset in [0.0,.001,.025,.027,.028,.029,.055,.059,.06,.061,.135,.139,.14,.141,.145,.2]:
  var s=Sim.new();s.hero.position=Vector3.ZERO;s.ai_enabled=false;s.hero.stats.regen=0;s.configure_test_loadout({'e':'e1','r':'r1'})
  var enemy=s.spawn_enemy('minion',Vector3(0,0,-1),1)
  s.request_action('e',enemy.position);s.request_action('r',enemy.position)
  var stale=s.pending[0].duplicate(true)
  s.step(offset)
  if s.phase=='combat':s.end_encounter('victory')
  var ended=s.snapshot()
  s.begin_encounter('qa-next',[{'kind':'minion','position':Vector3(0,0,-2),'hp':1000}]);s._resolve_pending(stale);s.step(.1)
  check(s.enemies[0].hp==1000 and s.clock.scale_factor()==1 and s.active_r1_cast==-1,'QA002 next room offset '+str(offset),{'old_phase':ended.phase,'next_hp':s.enemies[0].hp,'pending':ended.pending})
  s.free()
 var s=Sim.new();s.hero.position=Vector3.ZERO;s.ai_enabled=false;s.auto_finish=false;s.spawn_enemy('minion',Vector3(0,0,-2),1000);s.request_action('r',Vector3(0,0,-2));var stale=s.pending[0].duplicate(true);s.step(.3);var hp=s.enemies[0].hp;s._resolve_pending(stale)
 check(hp==952 and s.enemies[0].hp==hp,'R1 actual impact once; duplicate same-room callback ignored');s.free()
 for boundary in [.295,.299,.3,.301,.305]:
  s=Sim.new();s.hero.position=Vector3.ZERO;s.ai_enabled=false;s.auto_finish=false;s.spawn_enemy('minion',Vector3(0,0,-2),1000);s.request_action('r',Vector3(0,0,-2));s.step(boundary)
  var old_hp=s.enemies[0].hp;s.end_encounter('victory');s.begin_encounter('boundary-next',[{'kind':'minion','position':Vector3(0,0,-2),'hp':1000}]);s.step(.1)
  check(s.enemies[0].hp==1000 and s.clock.scale_factor()==1,'R1 impact boundary real seconds '+str(boundary),{'previous_enemy_hp':old_hp,'next_hp':s.enemies[0].hp});s.free()
 var f=FileAccess.open(OS.get_environment('QA_MODEL_REPORT') if not OS.get_environment('QA_MODEL_REPORT').is_empty() else '/workspace/shuabao-qa/tests/qa/round4_models.json',FileAccess.WRITE);f.store_string(JSON.stringify(results,'  '));f.close();print(JSON.stringify(results));quit(1 if results.any(func(x):return not x.passed) else 0)
