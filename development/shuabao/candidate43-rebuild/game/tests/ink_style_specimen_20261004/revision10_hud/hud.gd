extends "res://tests/ink_style_specimen_20261004/revision03/hud.gd"
## Read-only HUD candidate: same signals/present contract, same 930 x 74 footprint.
## No skill learning/casting, fabricated rank, inventory or transaction state.
const Icons = preload("res://tests/ink_style_specimen_20261004/revision10_hud/icons.gd")
const BAR_RECT := Rect2(174,632,930,74)
const CARDS := {
	"basic":Rect2(366,640,104,58), "P":Rect2(478,640,46,58),
	"q1":Rect2(532,640,152,58), "E":Rect2(692,640,46,58),
	"R":Rect2(746,640,46,58), "shift":Rect2(800,640,128,58),
	"equipment":Rect2(936,640,156,58)
}
const INPUT_HELP := "WASD移动 · Q预备→左键拖线/松开释放 · 空格暂停 · F9留图 / F6重开"
const SHOP_STATUS := "装备接入中，示意框"
var identity_level: Label
var q_rank_label: Label
var basic_cooldown: Label
var q_plus: Label
var q_plus_backplate: Control
var source_model: Dictionary = {}

func _ready() -> void:
	theme=Style.ui_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	_label("诊断样板 · 非普通开局 · 镜头18m / 40°",Vector2(22,16),Vector2(680,26),17)
	status=_label("HUD细化候选 · 实机美术待验",Vector2(22,42),Vector2(670,23),14)
	_button("商店  B",Rect2(920,18,105,32),func():shop_requested.emit(not shop_open))
	_button("诊断 F1",Rect2(1035,18,105,32),func():diagnostics_requested.emit())
	_button("退出 F10",Rect2(1150,18,108,32),func():exit_requested.emit())
	var blocker:=Control.new()
	blocker.position=BAR_RECT.position;blocker.size=BAR_RECT.size
	blocker.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(blocker)
	buffs=_label("状态：待同步",Vector2(186,611),Vector2(190,19),13)
	_label("晏归舟",Vector2(190,641),Vector2(96,24),18)
	identity_level=_label("Lv.—",Vector2(290,646),Vector2(58,19),12)
	identity_level.modulate=Style.QUIET
	health=_label("生命待同步",Vector2(190,669),Vector2(162,20),13)
	_label("普攻",Vector2(408,644),Vector2(56,23),15)
	_key("LMB",Rect2(407,671,28,18),10)
	basic_cooldown=_label("—",Vector2(438,671),Vector2(29,18),11)
	basic_cooldown.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	for key: String in ["P","E","R"]:
		var rect: Rect2=CARDS[key]
		var key_text:=_label(key,rect.position+Vector2(7,5),Vector2(32,23),16)
		key_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;key_text.modulate=Style.QUIET
		var locked:=_label("未开放",rect.position+Vector2(4,34),Vector2(38,19),11)
		locked.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;locked.modulate=Style.QUIET
	q_label=_label("飞流三千",Vector2(578,644),Vector2(68,23),15)
	q_rank_label=_label("—级",Vector2(649,647),Vector2(29,19),11)
	q_rank_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;q_rank_label.modulate=Style.ACCENT
	_key("Q",Rect2(578,671,18,18),11)
	q_cooldown=_label("CD —",Vector2(602,670),Vector2(51,20),12)
	q_plus_backplate=Control.new();q_plus_backplate.position=Vector2(659,671);q_plus_backplate.size=Vector2(18,18)
	q_plus_backplate.mouse_filter=Control.MOUSE_FILTER_STOP
	q_plus_backplate.tooltip_text="学习未接入 · 此诊断样板只显示真实技能等级"
	add_child(q_plus_backplate)
	q_plus=_label("+",Vector2(0,-1),Vector2(18,18),15,q_plus_backplate)
	q_plus.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;q_plus.modulate=Style.QUIET
	dash_label=_label("闪避",Vector2(846,644),Vector2(72,23),15)
	_key("Shift",Rect2(846,671,38,18),10)
	dash_cooldown=_label("—",Vector2(889,670),Vector2(32,20),12)
	dash_cooldown.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	_label("装备",Vector2(946,644),Vector2(46,24),15)
	var example:=_label("示意框",Vector2(1039,648),Vector2(43,18),11);example.modulate=Style.QUIET
	var equipment_status:=_label("装备接入中",Vector2(946,673),Vector2(135,18),12);equipment_status.modulate=Style.QUIET
	footer=_label(INPUT_HELP,Vector2(385,607),Vector2(710,21),13)
	diag=_label("",Vector2(22,84),Vector2(510,275),14);diag.visible=false
	shop_group=Control.new();shop_group.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shop_group.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(shop_group);shop_group.visible=false
	_label("商店",Vector2(373,170),Vector2(420,34),27,shop_group)
	_label(SHOP_STATUS,Vector2(373,213),Vector2(510,28),20,shop_group)
	_label("72件商品资料已收到\n\n当前只评审边框、间距与文字\n装备与交易接入中；本样板不能购买",Vector2(373,292),Vector2(528,140),18,shop_group)
	_label("浏览时真实暂停 · 关闭后重新按下输入恢复",Vector2(373,486),Vector2(525,24),15,shop_group)
	_button("关闭商店  B / Esc",Rect2(373,532,244,40),func():shop_requested.emit(false),shop_group)
	_button("退出",Rect2(790,532,117,40),func():exit_requested.emit(),shop_group)

func _key(text: String, rect: Rect2, font_size: int) -> void:
	var key_label:=_label(text,rect.position,rect.size,font_size)
	key_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;key_label.modulate=Style.QUIET

static func cooldown_text(cooldowns: Dictionary, key: String, prefix: String = "") -> String:
	if not cooldowns.has(key):return prefix+"—"
	return prefix+"%.1fs"%maxf(0.0,float(cooldowns[key]))

static func model_from(snapshot: Dictionary) -> Dictionary:
	var hero: Dictionary=snapshot.get("hero",{})
	var cooldowns: Dictionary=hero.get("cooldowns",{})
	var ranks: Dictionary=hero.get("ranks",{})
	var loadout: Dictionary=hero.get("loadout",{})
	var progression: Dictionary=snapshot.get("progression",{})
	var known_q:=ranks.has("q") and loadout.has("q")
	var learned_q:=known_q and str(loadout.q)=="q1" and int(ranks.q)>0
	var rank_text:="—级"
	if known_q:
		if learned_q:rank_text="%d级"%int(ranks.q)
		elif str(loadout.q) not in ["","q1"]:rank_text="未接"
		elif int(ranks.q)==0:rank_text="未学"
		else:rank_text="待核"
	return {
		"q_rank":rank_text,"q_learned":learned_q,
		"q_cooldown":cooldown_text(cooldowns,"q","CD "),
		"basic_cooldown":cooldown_text(cooldowns,"attack"),
		"shift_cooldown":cooldown_text(cooldowns,"shift"),
		"level":("Lv.%d"%int(progression.level)) if progression.has("level") else "Lv.—",
		"learning_connected":false,"rank_source":"hero.ranks.q + hero.loadout.q",
		"cooldown_source":"hero.cooldowns","level_source":"progression.level"
	}

func present(snapshot: Dictionary, ink: Dictionary, report: Dictionary) -> void:
	# The frozen parent owns established health/status/diagnostics formatting only.
	# Its old combined Q-rank/CD text is overwritten below in two separate labels.
	super.present(snapshot,ink,report)
	source_model=model_from(snapshot)
	identity_level.text=source_model.level
	q_rank_label.text=source_model.q_rank
	q_cooldown.text=source_model.q_cooldown
	basic_cooldown.text=source_model.basic_cooldown
	dash_cooldown.text=source_model.shift_cooldown
	q_rank_label.modulate=Style.ACCENT if source_model.q_learned else Style.QUIET
	queue_redraw()

func _draw() -> void:
	_panel(BAR_RECT,Color("23333BF2"))
	for key: String in CARDS:
		var muted:=key in ["P","E","R"]
		_panel(CARDS[key],Color("293C42") if muted else Color("31474E"))
		var rect: Rect2=CARDS[key]
		# One restrained top plane supplies depth, without grain or ink panels.
		draw_line(rect.position+Vector2(6,2),Vector2(rect.end.x-6,rect.position.y+2),Color("3C555A"),1.0,true)
	for rect: Rect2 in [Rect2(372,646,32,42),Rect2(538,646,34,42),Rect2(806,646,34,42)]:
		draw_rect(rect,Color("22363D"))
	Icons.draw_icon(self,"basic",Vector2(373,650),30.0)
	Icons.draw_icon(self,"q1",Vector2(539,650),32.0)
	Icons.draw_icon(self,"shift",Vector2(807,650),32.0)
	for rect: Rect2 in [Rect2(407,671,28,18),Rect2(578,671,18,18),Rect2(846,671,38,18)]:
		draw_rect(rect,Color("22363D"))
		draw_line(rect.position+Vector2(1,17),rect.end-Vector2(1,1),Color("617C7E"),1.0)
	# Visible + is a disabled, struck-through learning affordance, never a button.
	draw_rect(Rect2(659,671,18,18),Color("24363B"))
	draw_line(Vector2(660,688),Vector2(676,672),Color("617677"),1.0,true)
	draw_rect(Rect2(190,692,160,5),Color("142A2D"))
	var fraction:=clampf(float(hero_state.get("hp",0))/maxf(.001,float(hero_state.get("max_hp",1))),0,1)
	draw_rect(Rect2(190,692,160*fraction,5),Style.ACCENT)
	if diagnostics_visible:_panel(Rect2(12,77,538,245),Color("23333BEB"))
	if shop_open:
		draw_rect(Rect2(Vector2.ZERO,Vector2(1280,720)),Color(0.06,.10,.11,.43))
		_panel(Rect2(341,143,598,461))
		_panel(Rect2(364,277,552,171),Color("2C4247"))
