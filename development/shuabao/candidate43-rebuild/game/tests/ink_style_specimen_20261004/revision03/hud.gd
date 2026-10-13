extends Control
## One common quiet/chamfered treatment for HUD, skill cards and empty shop.
signal shop_requested(open: bool)
signal exit_requested
signal restart_requested
signal diagnostics_requested
const Style=preload("res://tests/ink_style_specimen_20261004/style.gd")
var hero_state: Dictionary={}
var shop_open:=false
var diagnostics_visible:=false
var status: Label
var health: Label
var buffs: Label
var q_label: Label
var dash_label: Label
var q_cooldown: Label
var dash_cooldown: Label
var diag: Label
var shop_group: Control
var footer: Label
func _ready() -> void:
	theme=Style.ui_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	_label("诊断样板 · Q1已学 · 镜头18m / 40°",Vector2(22,16),Vector2(680,26),17)
	status=_label("整体美术修订03 · 未通过评审",Vector2(22,42),Vector2(670,23),14)
	_button("商店  B",Rect2(920,18,105,32),func():shop_requested.emit(not shop_open))
	_button("诊断 F1",Rect2(1035,18,105,32),func():diagnostics_requested.emit())
	_button("退出 F10",Rect2(1150,18,108,32),func():exit_requested.emit())
	var blocker:=Control.new()
	blocker.position=Vector2(174,632);blocker.size=Vector2(930,74)
	blocker.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(blocker)
	buffs=_label("状态：无",Vector2(186,611),Vector2(190,19),13)
	_label("晏归舟",Vector2(190,641),Vector2(175,23),18)
	health=_label("生命",Vector2(190,667),Vector2(175,20),13)
	_label("普攻",Vector2(387,672),Vector2(80,21),15)
	_label("LMB",Vector2(425,646),Vector2(38,19),11)
	for item: Array in [["P",476],["E",664],["R",736]]:
		var x:=float(item[1])
		var key_label:=_label(str(item[0]),Vector2(x+8,646),Vector2(20,22),17)
		key_label.modulate=Color("84938D")
		var name_label:=_label("未开放",Vector2(x+7,673),Vector2(54,19),12)
		name_label.modulate=Color("84938D")
		var plus:=_label("+",Vector2(x+43,644),Vector2(15,20),15)
		plus.modulate=Color("687C77")
	q_label=_label("飞流三千",Vector2(557,672),Vector2(93,22),15)
	_label("Q",Vector2(588,645),Vector2(20,21),14)
	q_cooldown=_label("1级",Vector2(608,645),Vector2(34,21),12)
	var q_plus:=_label("+",Vector2(640,644),Vector2(15,20),15);q_plus.modulate=Color("687C77")
	dash_label=_label("闪避",Vector2(820,672),Vector2(83,21),15)
	_label("Shift",Vector2(843,645),Vector2(43,21),12)
	dash_cooldown=_label("",Vector2(883,645),Vector2(33,21),11)
	_label("装备",Vector2(940,643),Vector2(110,22),15)
	_label("物品表待提供",Vector2(940,674),Vector2(142,19),12)
	footer=_label("WASD移动  ·  Q按拖松开  ·  空格暂停  ·  F9留图 / F6重开",Vector2(385,607),Vector2(710,21),13)
	diag=_label("",Vector2(22,84),Vector2(510,275),14)
	diag.visible=false
	shop_group=Control.new();shop_group.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shop_group.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(shop_group);shop_group.visible=false
	_label("商店",Vector2(373,170),Vector2(420,34),27,shop_group)
	_label("物品表待提供",Vector2(373,213),Vector2(490,28),20,shop_group)
	_label("当前仅评审边框、间距、文字与全局风格\n\n本样板没有可购买商品，也不执行购买交易",Vector2(373,292),Vector2(528,140),19,shop_group)
	_label("浏览时真实暂停 · 关闭后重新按下输入恢复",Vector2(373,486),Vector2(525,24),15,shop_group)
	_button("关闭商店  B / Esc",Rect2(373,532,244,40),func():shop_requested.emit(false),shop_group)
	_button("退出",Rect2(790,532,117,40),func():exit_requested.emit(),shop_group)
func _label(text: String, at: Vector2, dimensions: Vector2, font_size: int, owner: Control=null) -> Label:
	var label:=Label.new();label.position=at;label.size=dimensions;label.text=text
	label.add_theme_font_size_override("font_size",font_size)
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	(owner if owner!=null else self).add_child(label)
	return label
func _button(text: String, rect: Rect2, callback: Callable, owner: Control=null) -> void:
	var button:=Button.new();button.text=text;button.position=rect.position;button.size=rect.size
	button.focus_mode=Control.FOCUS_NONE;button.pressed.connect(callback)
	(owner if owner!=null else self).add_child(button)
func set_shop(open: bool) -> void:
	shop_open=open;shop_group.visible=open;queue_redraw()
func set_diagnostics(open: bool) -> void:
	diagnostics_visible=open;diag.visible=open;queue_redraw()
func present(snapshot: Dictionary, ink: Dictionary, report: Dictionary) -> void:
	hero_state=snapshot.get("hero",{})
	var cds: Dictionary=hero_state.get("cooldowns",{})
	health.text="生命  %d / %d"%[ceili(float(hero_state.get("hp",0))),ceili(float(hero_state.get("max_hp",1)))]
	q_label.text="飞流三千"
	q_cooldown.text="%.1fs"%float(cds.get("q",0)) if float(cds.get("q",0))>.01 else "1级"
	dash_label.text="闪避"
	dash_cooldown.text="%.1f"%float(cds.get("shift",0)) if float(cds.get("shift",0))>.01 else ""
	buffs.text="状态："+status_name(hero_state,str(snapshot.get("phase","")),bool(snapshot.get("paused",false)))
	var phase:=str(ink.get("input",{}).get("phase","idle"))
	if hero_state.get("dead",false):status.text="角色已倒下 · F6重新开始诊断样板"
	elif snapshot.get("paused",false):status.text="已暂停 · 关闭商店或按空格恢复"
	else:status.text={"armed":"Q1：已预备，请按住左键绘线","drawing":"Q1：绘线中，可继续移动","frozen":"Q1：线已冻结，松开左键释放"}.get(phase,"实机美术待验 · 音频 "+str(report.get("audio_status","待接线")))
	if diagnostics_visible:
		diag.text="仅诊断，不是普通Lv1 / Boss / 性能验收\n渲染器：%s\n源时间 %.2f s · 墙钟 %.2f s\n绘制帧 %d · 当前绘制调用 %d\n真实伤害回执 %d · 输入记录 %d\n阴影 %s · 辉光关闭\n音频：%s\n角色：%s"%[report.get("renderer","?"),float(ink.get("source_time",0)),float(report.get("wall_seconds",0)),int(report.get("draw_frames",0)),int(report.get("draw_calls",0)),int(report.get("receipt_count",0)),int(report.get("input_count",0)),str(report.get("shadows",false)),report.get("audio_status","pending"),report.get("hero_status","pending")]
	queue_redraw()
func _panel(rect: Rect2, color: Color=Style.SURFACE) -> void:
	var points:=Style.chamfer(rect)
	draw_colored_polygon(points,color)
	var border:=points.duplicate();border.append(points[0]);draw_polyline(border,Style.EDGE,1.0,true)
func _draw() -> void:
	_panel(Rect2(174,632,930,74),Color("23333BED"))
	for rect: Rect2 in [Rect2(374,641,94,54),Rect2(548,641,108,54),Rect2(808,641,110,54),Rect2(926,641,158,54)]:_panel(rect,Color("30464B"))
	for x: float in [476.0,664.0,736.0]:_panel(Rect2(x,641,64,54),Color("283B3F"))
	draw_rect(Rect2(190,692,167,5),Color("142A2D"))
	var fraction:=clampf(float(hero_state.get("hp",0))/maxf(.001,float(hero_state.get("max_hp",1))),0,1)
	draw_rect(Rect2(190,692,167*fraction,5),Style.ACCENT)
	# Small authored geometric icons occupy their own cell; names and disabled
	# upgrade-plus controls never get replaced by cooldown numbers.
	draw_line(Vector2(388,663),Vector2(407,647),Style.TEXT,3.0,true)
	draw_colored_polygon(PackedVector2Array([Vector2(386,663),Vector2(393,662),Vector2(388,668)]),Style.ACCENT)
	for row in range(3):
		var y: float=648+row*5
		draw_polyline(PackedVector2Array([Vector2(557,y+3),Vector2(563,y),Vector2(570,y+3),Vector2(577,y+1)]),Style.ACCENT,2.0,true)
	draw_polyline(PackedVector2Array([Vector2(819,651),Vector2(834,651),Vector2(829,647),Vector2(836,651),Vector2(829,656)]),Style.ACCENT,2.0,true)
	if diagnostics_visible:_panel(Rect2(12,77,538,245),Color("23333BEB"))
	if shop_open:
		draw_rect(Rect2(Vector2.ZERO,Vector2(1280,720)),Color(0.06,.10,.11,.43))
		_panel(Rect2(341,143,598,461))
		_panel(Rect2(364,277,552,171),Color("2C4247"))

static func status_name(hero: Dictionary, phase: String, paused: bool=false) -> String:
	if bool(hero.get("dead",false)):return "已倒下"
	if phase!="combat":return "遭遇结束"
	if paused:return "暂停"
	if float(hero.get("dash_left",0.0))>0.0 and bool(hero.get("invulnerable",false)):return "闪避免疫"
	if bool(hero.get("invulnerable",false)):return "免疫"
	return "无"
