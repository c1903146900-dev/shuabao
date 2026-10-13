extends "res://tests/ink_shop_ui_host_20261004/style26/parsefix01/host.gd"
## Thin diagnostic recording/funded-fixture overlay; source stepping and style26
## presentation clock, F8/F9, normal and natural earning paths remain inherited.
const JournalObserver=preload("res://tests/ink_shop_ui_host_20261004/journal01/observer.gd")
const FundedSession=preload("res://tests/ink_shop_ui_host_20261004/journal01/funded_session.gd")
var journal_observer=JournalObserver.new()
var journal_enabled: bool=false
var funded_diagnostic: bool=false
func _ready() -> void:
 funded_diagnostic="--ink-shop-funded-diagnostic" in OS.get_cmdline_user_args()
 var natural: bool="--ink-shop-real-diagnostic" in OS.get_cmdline_user_args()
 if funded_diagnostic and natural:
  push_error("Choose exactly one explicitly labeled shop diagnostic flag")
  get_tree().quit(2);return
 journal_enabled=funded_diagnostic or natural
 super._ready()
 _journal_open()
 if journal_enabled:journal_observer.lifecycle({"type":"startup_ready","scope":_session_scope(),"ledger":_journal_ledger(),"funding":shop_session.funding_receipt if funded_diagnostic else {"initial_gold":0,"natural_earning_branch":true}})
func _session_scope() -> String:
 return FundedSession.FUNDING_LABEL+"；每房1只原始AI小兵；真实胜利/商店/下一房接线夹具" if funded_diagnostic else super._session_scope()
func _start_encounter() -> void:
 if not funded_diagnostic:
  super._start_encounter();return
 if shop_session!=null:
  startup_session_error="fresh_restart_requires_exit_and_new_session";return
 session_diagnostic=true
 # Same original fresh actor/router/view/ledger startup, specialized only by
 # the explicit funded Session initializer. No battle starts during construction.
 sim=HealthSim.new();add_child(sim)
 sim.hero.position=Vector3(0,0,4)
 sim.arena_half_extent=Stage.EXTENT;sim.obstacles=Stage.OBSTACLES.duplicate(true)
 sim.ai_enabled=true;sim.auto_finish=false
 input_router=InputRouter.new();input_router.bind(sim)
 hero_view=HeroView.new();add_child(hero_view)
 enemy_view=MinionView.new();add_child(enemy_view);enemy_view.visible=false
 audio_output.restart_scope()
 shop_session=FundedSession.new()
 var initialized: Dictionary=shop_session.initialize_funded_session(sim,"shop-funded-%d"%Time.get_ticks_usec(),true)
 if not initialized.accepted:startup_session_error=str(initialized.reason)
 else:shop_session.bind_input_suspender(input_router.suspend_input)
 sim.combat_event.connect(_combat_event)
 sim.encounter_finished.connect(_session_terminal)
 seen_receipts.clear();q1_view.reset_visuals();audio_output.clear()
 _refresh(0.0)
func _refresh(delta: float) -> void:
 if not journal_enabled:
  super._refresh(delta);return
 # Every ancestor _refresh is synchronous. Suppress only its diagnostic write;
 # last_presented_full/ink, actors, HUD, camera, source and F8/F9 stay intact.
 var original_stream: FileAccess=recording
 recording=null
 super._refresh(delta)
 recording=original_stream
 _journal_open()
 if sim!=null and not last_presented_full.is_empty():
  journal_observer.observe_frame(recording,Time.get_ticks_usec()-start_ticks,draw_count,last_presented_full,last_presented_ink,hero_view.sample_report,_journal_ledger(),_journal_scope())
 journal_observer.drain_inputs(inputs,pauses)
func _combat_event(event: Dictionary) -> void:
 super._combat_event(event)
 if journal_enabled:
  _journal_open()
  journal_observer.combat(event,Time.get_ticks_usec()-start_ticks,_journal_ledger())
func _journal_open() -> void:
 if journal_enabled and not evidence_dir.is_empty():journal_observer.open_streams(evidence_dir,_session_scope())
func _journal_scope() -> Dictionary:
 return {"phase":sim.phase,"room":sim.room_id,"generation":sim.encounter_generation,"paused":sim.paused,"panel_open":shop_session!=null and shop_session.panel_open,"session_status":shop_session.status if shop_session!=null else "unbound","branch":"funded" if funded_diagnostic else "natural"}
func _journal_ledger() -> Dictionary:
 if shop_session==null or shop_session.ledger==null:return {}
 var s: Dictionary=shop_session.ledger.model.state
 return {"run_id":shop_session.run_id,"revision":s.revision,"level":s.level,"gold":s.gold,"xp":s.xp,"points":s.points,"phase":s.phase,"reward_ids":s.reward_ids.duplicate(),"inventory":s.inventory.duplicate(true),"room_id":s.shop_visit.room_id,"epoch":s.shop_visit.epoch,"undo_count":s.shop_visit.undo.size(),"test_initial_funding":1000 if funded_diagnostic else 0,"natural_gold_acceptance":false,"source":"same authoritative live ledger after original event/transaction consumer"}
func _record_session_action(action: String,result: Dictionary) -> void:
 super._record_session_action(action,result)
 if journal_enabled:
  _journal_open()
  journal_observer.lifecycle({"type":"shop_UI_action","action":action,"receipt":result.duplicate(true),"ledger":_journal_ledger(),"wall_usec":Time.get_ticks_usec()-start_ticks})
  journal_observer.drain_inputs(inputs,pauses)
func _refresh_session_controls(force: bool) -> void:
 super._refresh_session_controls(force)
 if not funded_diagnostic or not is_instance_valid(session_header) or shop_session==null or shop_session.ledger==null:return
 session_header.text=FundedSession.FUNDING_LABEL+"\nLv.%d  当前金币%d  B安全商店 · 正常AI · F10退出"%[shop_session.ledger.model.state.level,shop_session.ledger.model.state.gold]
 session_next.text="开始真实测试首战（1只小兵）" if shop_session.node_index==0 else "进入下一战（提交本次交易）"
 session_hint.text="测试初始资金1000。每房1只原始AI小兵，真实击杀仍仅20金币。先真实胜利，再B购买/撤回、离店进下一房。非自然赚金或平衡通过。\n\n"+ShopPanel.receipt_text(shop_session.last_receipt)
func _write_json(filename: String,contents: Dictionary) -> void:
 var output: Dictionary=contents
 if funded_diagnostic:
  output=contents.duplicate(true)
  if filename in ["shop_session_start.json","shop_session_result.json","session_start.json","session_result.json"]:
   output["scope"]=_session_scope();output["funding"]=FundedSession.FUNDING_LABEL
   output["test_initial_gold"]=1000;output["natural_gold_acceptance"]=false;output["normal_entry_ready"]=false;output["final_balance"]=false
   output["funding_receipt"]=shop_session.funding_receipt if shop_session!=null else {}
 super._write_json(filename,output)
func save_evidence(reason: String) -> void:
 if journal_enabled:
  _journal_open();journal_observer.drain_inputs(inputs,pauses)
  journal_observer.lifecycle({"type":"final_source_boundary","reason":reason,"source":sim.snapshot() if sim!=null else {},"ink":sim.ink_presenter_snapshot() if sim!=null else {},"actor_sample":hero_view.sample_report if is_instance_valid(hero_view) else {},"ledger":_journal_ledger()})
 super.save_evidence(reason)
 if journal_enabled:journal_observer.finish(reason)
