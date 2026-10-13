extends RefCounted
const LABELS = {"AD":"攻击力", "AP":"法术强度", "attack_speed":"基础攻速", "crit_chance":"暴击率", "cooldown_reduction":"冷却缩减", "max_hp":"最大生命", "defense":"防御", "move_speed":"基础移速", "lifesteal":"吸血", "tenacity":"韧性", "penetration":"穿透", "hp_regen":"战斗生命恢复/秒"}
const FRACTIONS = ["attack_speed", "crit_chance", "cooldown_reduction", "move_speed", "lifesteal", "tenacity"]
static func stats(values: Dictionary) -> String:
	var lines: PackedStringArray = []
	for key in values:
		var amount: float = values[key]
		lines.append("%s +%s%s" % [LABELS.get(key,key), number(amount * 100.0 if key in FRACTIONS else amount), "%" if key in FRACTIONS else ""])
	return " · ".join(lines)
static func describe(entry: Dictionary, definitions: Dictionary) -> String:
	var lines: PackedStringArray = []
	if not entry.get("stats", {}).is_empty(): lines.append(stats(entry.stats))
	if not entry.get("description", "").is_empty(): lines.append(entry.description)
	var passive: String = entry.get("passive", "")
	if not passive.is_empty():
		var p: Dictionary = definitions.get("passives", {}).get(passive, {})
		lines.append("唯一被动 · %s：%s" % [p.get("name",passive),p.get("description",stats(p.get("stats",{})))])
	if entry.has("recovery"):
		lines.append("回复最大生命 %.0f%%；%s；满血不消耗，不刷新技能冷却" % [entry.recovery.amount*100.0,"战斗或战后可用" if "combat" in entry.recovery.get("allowed_phases",[]) else "仅安全补给期可用"])
	return "\n".join(lines)

static func number(value:float,decimals:=2) -> String:
	if is_equal_approx(value,roundf(value)):return str(int(roundf(value)))
	return String.num(value,decimals)

static func display_numbers(source:String) -> String:
	# Text-only normalization: trim redundant zeroes without rounding or parsing
	# through float, so meaningful precision and source/authority values stay intact.
	var text:=source
	var numbers:=RegEx.new()
	numbers.compile("[0-9]+[.][0-9]+")
	var matches:=numbers.search_all(text)
	for i in range(matches.size()-1,-1,-1):
		var token:RegExMatch=matches[i]
		var rendered:=token.get_string().rstrip("0").trim_suffix(".")
		text=text.left(token.get_start())+rendered+text.substr(token.get_end())
	return text

static func candidate_name(definitions:Dictionary,candidate:String) -> String:
	var skill:Dictionary=definitions.get("skill_definitions",{}).get(candidate,{})
	if not str(skill.get("name","")).is_empty():return str(skill.name)
	# Older projections carry parallel candidate IDs/names instead of definitions.
	for slot in definitions.get("candidates",{}):
		var candidates:Array=definitions.candidates[slot]
		var index:=candidates.find(candidate)
		var names:Array=definitions.get("candidate_names",{}).get(slot,[])
		if index>=0 and index<names.size():return str(names[index])
	return candidate

static func hex_dependencies(entry:Dictionary) -> Array:
	var dependencies:Array=entry.get("skill_dependencies",[]).duplicate()
	var required:=str(entry.get("requires",""))
	if dependencies.is_empty() and not required.is_empty():dependencies.append(required)
	return dependencies

static func dependency_label(dependencies:Array,definitions:Dictionary) -> String:
	var names:PackedStringArray=[]
	for candidate in dependencies:
		var name:=candidate_name(definitions,str(candidate))
		names.append(str(candidate) if name==str(candidate) else "%s · %s" % [candidate,name])
	return " + ".join(names)

static func skill_description(source:String) -> String:
	var text:=display_numbers(source.replace("[重排测试初值] ",""))
	text=text.replace("；","；\n").replace("。","。\n")
	for clause in ["基础冷却","冷却时间"]:
		text=text.replace(clause,"\n"+clause)
	while text.contains("\n\n"):text=text.replace("\n\n","\n")
	return text.strip_edges()
