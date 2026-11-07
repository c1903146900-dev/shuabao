extends SceneTree
# Real UI buttons only; verify each displayed choice before refresh/select.
var elapsed:float=0
var tick:float=0
var entry:Node
var host:Node
var stage:int=0
func fail(why:String)->void:print("H08_DRAFT_FAIL ",why);quit(9)
func _initialize()->void:root.add_child(load("res://boot.tscn").instantiate())
func _process(dt:float)->bool:
 elapsed+=dt;tick+=dt
 if elapsed>45:fail("timeout");return false
 if tick<.25:return false
 tick=0
 if entry==null:
  var b=root.get_node_or_null("Boot")
  if b!=null:
   for c in b.get_children():
    if c.get("screen")!=null:entry=c
  return false
 if stage==0:entry._start.pressed.emit();stage=1;return false
 host=entry.active_room
 if host==null:return false
 var draft:Node=host.initial_hud.hex_draft
 if stage<=3:
  if not draft.visible:return false
  var ids:Array=[]
  for c in draft.last_view.get("choices",[]):ids.append(str(c.id))
  print("H08_DRAFT_CHOICES stage=",stage," ids=",ids)
  if ids.size()!=4:fail("choice_count");return false
  if stage==1:
   if ids!=["fengli_h12","common_g29","common_g30","fengli_h16"]:fail("unexpected_initial_offer");return false
   if draft.cards[0].refresh.disabled:fail("slot0_unavailable");return false
   draft.cards[0].refresh.pressed.emit();stage=2
  elif stage==2:
   if ids[0]!="common_g13":fail("unexpected_first_refresh");return false
   if draft.cards[1].refresh.disabled:fail("slot1_unavailable");return false
   draft.cards[1].refresh.pressed.emit();stage=3
  else:
   if ids[1]!="fengli_h08":fail("H08_not_offered");return false
   if draft.cards[1].select.disabled:fail("H08_disabled");return false
   draft.cards[1].select.pressed.emit();stage=4
  return false
 if stage==4:
  if host.shop_session.initial_modal_open:return false
  host.initial_hud.bottom_actions.E.pressed.emit();stage=5;return false
 if stage==5:
  if not host.initial_hud.bottom_popup.visible:return false
  if host.initial_hud.bottom_candidate_buttons.E1.disabled:fail("E1_unavailable");return false
  host.initial_hud.bottom_candidate_buttons.E1.pressed.emit();stage=6;return false
 if stage==6:
  var s:Dictionary=host.shop_session.ledger.model.state
  var good:bool="fengli_h08" in s.selected_hex and str(s.skills.E.candidate)=="E1" and int(s.skills.E.rank)==1
  print("H08_DRAFT_PASS ",good," selected=",s.selected_hex," E=",s.skills.E)
  host.frontdoor_close_run("h08_draft_verification");quit(0 if good else 9)
 return false
