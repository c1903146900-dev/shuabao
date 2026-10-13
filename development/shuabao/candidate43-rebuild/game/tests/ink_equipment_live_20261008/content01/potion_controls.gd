extends HBoxContainer
## Mount once in the existing HUD with its already-bound shop session.
## Press is a normal UI input. This control never grants items, HP, gold or focus.
const STRIP_RECT=Rect2(450,570,372,32)
const BUTTON_SIZE=Vector2(120,32)
const TIER_LABELS={"potion:1":"药I","potion:2":"药II","potion:3":"药III"}
func _ready() -> void:
 position=STRIP_RECT.position
 size=STRIP_RECT.size
 custom_minimum_size=STRIP_RECT.size
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 add_theme_constant_override("separation",6)

var _session: RefCounted
var _signature: String=""
func bind_session(session: RefCounted) -> void:
 assert(_session==null)
 _session=session
func _process(_delta: float) -> void:
 if _session==null or _session.ledger==null: return
 var held: Array=[]
 for entry in _session.ledger.model.state.inventory:
  if str(entry.id) in ["potion:1","potion:2","potion:3"]: held.append(entry.duplicate(true))
 var unavailable: bool=_session.panel_open or _session.sim.paused or _session.sim.hero.dead or _session.sim.transaction_active
 var signature: String=JSON.stringify([held,unavailable])
 if signature==_signature: return
 _signature=signature
 for child in get_children(): remove_child(child);child.queue_free()
 for entry in held:
  var button=Button.new()
  button.text="%s ×%d"%[TIER_LABELS[entry.id],int(entry.count)]
  button.custom_minimum_size=BUTTON_SIZE
  button.size=BUTTON_SIZE
  button.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
  button.size_flags_vertical=Control.SIZE_SHRINK_BEGIN
  button.clip_text=true
  button.add_theme_font_size_override("font_size",14)
  var definition: Dictionary=_session.ledger.model.commerce_definitions.items[entry.id]
  button.tooltip_text="%s：4秒角色战斗时间内均匀恢复%s%%最大生命，受伤不中断。每次消耗1瓶；同档共一槽、三档合计最多5瓶。关闭商店后饮用。"%[definition.name,str(definition.recovery.heal_max_health_pct)]
  button.disabled=unavailable
  button.pressed.connect(_use.bind(int(entry.uid)))
  add_child(button)
func _use(uid: int) -> void:
 if _session==null or _session.panel_open or _session.sim.paused or _session.sim.transaction_active: return
 _session.serial+=1
 var result: Dictionary=_session.ledger.model.use_potion(_session,"potion-ui:%d"%_session.serial,uid)
 if result.accepted: _session.growth_dirty=true
 _session._record(result)
 _signature=""
