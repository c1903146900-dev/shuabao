extends SceneTree
const Sim=preload('res://scripts/combat/combat_sim.gd')
func _initialize():
 var s=Sim.new();s.configure_test_loadout({'q':'q2','e':'e1','r':'r2','passive':'p3'});s.ai_enabled=false;s.hero.position=Vector3.ZERO
 var enemy=s.spawn_enemy('minion',Vector3(0,0,-1))
 var attack=s.request_action('attack',enemy.position);s.step(.11)
 var first=s.request_action('e',enemy.position);var second=s.request_action('q',enemy.position)
 s.step(.2);var ended=s.snapshot()
 var next=s.begin_encounter('next-room',[{'kind':'minion','position':Vector3(0,0,-2),'hp':1000}]);s.step(.25)
 var report={'sha':'c1b20bc8da414452c113936b26ce9a4874bb733d','input':'simulation fixture, no OS','casts':[attack,first,second],'ended':ended,'next_receipt':next,'after':s.snapshot(),'events':s.event_log}
 var f=FileAccess.open('/workspace/shuabao-qa/tests/qa/round8_probe.json',FileAccess.WRITE);f.store_string(JSON.stringify(report,'  '));f.close();print(JSON.stringify({'ended':ended.phase,'end_cast':ended.hero.cast_state,'new_hp':s.enemies[0].hp}));s.free();quit()
