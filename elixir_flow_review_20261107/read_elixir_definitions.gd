extends SceneTree
var elapsed:float=0.0
var done:bool=false
func _initialize()->void:
 root.add_child(load("res://boot.tscn").instantiate())
func _process(dt:float)->bool:
 elapsed+=dt
 if done:return false
 if elapsed>20.0:quit(9);return false
 if root.get_node_or_null("Boot/FengliEntry")==null:return false
 done=true;_read_definitions();return false
func _read_definitions()->void:
 var machine=load("res://__clean_fengli/machine_template_reader.gd")
 var commerce:Dictionary=machine.open_commerce()
 if not commerce.get("accepted",false):
  print("ELIXIR_SOURCE_REJECT ",commerce);quit(9);return
 var items:Dictionary={}
 for id in commerce.definitions.items:
  if commerce.definitions.items[id].get("kind","")=="elixir":items[id]=commerce.definitions.items[id]
 var stats:Dictionary=machine.runtime_stats()
 var selected:Dictionary={}
 for id in items:
  if stats.has(id):selected[id]=stats[id]
 print("ELIXIR_VERIFIED_ITEMS ",JSON.stringify(items))
 print("ELIXIR_VERIFIED_STATS ",JSON.stringify(selected))
 for phase in ["constructor","commerce_bound","floor_bound"]:
  var config:Dictionary=machine.phase_config(phase)
  print("ELIXIR_STAT_UNITS ",phase," ",JSON.stringify(config.get("stat_units",{})))
 quit(0)
