extends Node
## Run state machine: single authority for state transitions, overlay visibility, and spawner.
## Rules: Timer 0 + player alive → BURST_END → UPGRADE_PICK → RUNNING (next burst). Player HP 0 → GAME_OVER only.
## Only one overlay visible at a time. Run Over UI only in GAME_OVER; burst cleared never shows Run Over.

enum State {
	INTRO,          # Pre-run: intro playing (Main controls; StageManager not yet active)
	LAB,            # Pre-run: weapon select / System Lab (Main controls)
	RUNNING,        # Gameplay: timer ticking, spawner active
	BURST_END,      # Timer reached 0, player alive: burst cleared, about to show upgrade
	UPGRADE_PICK,   # Player choosing upgrade (mid-run or end-of-burst); one overlay only
	BOSS,           # Boss active (logical sub-phase of RUNNING; spawner may be stopped)
	GAME_OVER       # Player died — only state that shows Run Over overlay
}

## Run duration (30–40s). Single segment per run.
@export var run_duration: float = 38.0
## When to trigger mid-run upgrade so ignition can happen in 18–28s window.
@export var mid_run_upgrade_at: float = 12.0
## When to spawn boss (release phase start).
@export var boss_spawn_at: float = 35.0

## Legacy: burst_duration used as run_duration for spawner; boss_every_n no longer used for multi-burst.
@export var burst_duration: float = 30.0
@export var boss_burst_duration: float = 60.0
@export var boss_every_n_bursts: int = 5
## Roguelike：以「波次清敵」為主循環（每 N 波強化）；關閉則使用下方計時 burst。
@export var use_wave_loop: bool = true
@export var level_manager_path: NodePath = NodePath("LevelManager")

## Time scale during upgrade choice: world slows, does not stop. Beat and atmosphere keep running.
const UPGRADE_CHOICE_TIME_SCALE := 0.22

@export var hud_path: NodePath
@export var upgrade_choice_path: NodePath
@export var game_over_path: NodePath
@export var system_lab_path: NodePath = NodePath("../../UI/SystemLab")
@export var wave_spawner_path: NodePath
## Optional: spawn Refraction Core (or other boss) during boss burst. Leave empty to skip boss spawn.
@export var boss_scene: PackedScene = null
@export var boss_container_path: NodePath = NodePath("../Enemies")
## Stage→Boss mapping：依 mini-stage boss 關序號（index 0 = 第一個 boss 關）。循環使用。
## 建議填入：[neon_tank, cyber_warship, humanoid_ace, neon_titan, refraction_core]
@export var stage_boss_map: Array[PackedScene] = []
## Stage 主題名（對應 boss 序號；顯示於 BossWarning 字幕）。
@export var stage_theme_names: Array[String] = ["CYBER CITY", "DEEP SPACE", "NEON CORE"]
## Boss 警報 UI 顯示時長（秒），會延遲 boss 實體生成。
@export var boss_warning_duration: float = 2.2
## BossWarning UI 場景（可選；若設置則實例化該場景，否則程序化創建 BossWarning）
@export var boss_warning_scene: PackedScene = null

var burst_index: int = 1
var _boss_instance: Node2D = null
var _boss_spawn_epoch_s: float = 0.0
var burst_timer: float = 0.0
var stage_state: State = State.GAME_OVER
var bursts_cleared: int = 0
var run_currency: int = 0
var _upgrades_taken_this_run: Array[String] = []
var run_weapon_id: String = "spread"
var _mid_run_upgrade_done: bool = false
var _awaiting_burst_end_upgrade: bool = false  # true when upgrade pick is for end-of-burst (then advance to next burst)
var _is_level_up_choice: bool = false  # true when upgrade UI was shown due to level-up (freeze world, no timer change)
## 在 level-up 升級期間若波次清空事件觸發，延遲至升級完成後處理。避免 wave_cleared 被丟棄而卡關。
var _pending_wave_cleared_number: int = -1
## 當 boss 死亡同 level-up 同幀觸發時，延遲 boss 清理流程直到玩家揀完升級。
var _pending_boss_defeated: bool = false

var _hud: Control
var _upgrade_choice: Control
var _game_over: Control
var _system_lab: Control
var _wave_spawner: Node
var _hud_wave_label: Label
var _hud_run_status_label: Label
var _hud_timer_label: Label
var _hud_exp_label: Label
var _hud_total_currency_label: Label
var _save_manager: Node  # SaveManager autoload from /root/SaveManager
var _level_manager: LevelManager
## 目前小關卡內波次（僅 wave loop 顯示／節奏用）。
var _current_wave_in_stage: int = 1


func _ready() -> void:
	_save_manager = get_node_or_null("/root/SaveManager")
	_resolve_refs()
	_cache_hud_nodes()
	_resolve_level_manager()
	EventBus.wave_cleared.connect(_on_event_bus_wave_cleared)
	EventBus.player_died.connect(_on_player_died)
	EventBus.exp_collected.connect(_on_exp_collected)
	EventBus.level_up.connect(_on_level_up)
	_connect_upgrade_chosen()
	if EventBus.has_signal("boss_defeated"):
		EventBus.boss_defeated.connect(_on_boss_defeated)


func _get_starting_energy_bonus() -> int:
	if _save_manager and _save_manager.has_method("get_starting_energy_bonus"):
		return _save_manager.get_starting_energy_bonus()
	return 0


func _resolve_level_manager() -> void:
	if not level_manager_path.is_empty():
		_level_manager = get_node_or_null(level_manager_path) as LevelManager
	if _level_manager == null:
		var lm := LevelManager.new()
		lm.name = "LevelManager"
		add_child(lm)
		_level_manager = lm


func _resolve_refs() -> void:
	if hud_path.is_empty() == false:
		_hud = get_node_or_null(hud_path) as Control
	if upgrade_choice_path.is_empty() == false:
		_upgrade_choice = get_node_or_null(upgrade_choice_path) as Control
	if game_over_path.is_empty() == false:
		_game_over = get_node_or_null(game_over_path) as Control
	if system_lab_path.is_empty() == false:
		_system_lab = get_node_or_null(system_lab_path) as Control
	if wave_spawner_path.is_empty() == false:
		_wave_spawner = get_node_or_null(wave_spawner_path)
	_cache_hud_nodes()

func _cache_hud_nodes() -> void:
	if not _hud or not is_instance_valid(_hud):
		return
	_hud_wave_label = _hud.get_node_or_null("HUDPanel/WaveLabel") as Label
	_hud_run_status_label = _hud.get_node_or_null("TopBar/RunStatusLabel") as Label
	_hud_timer_label = _hud.get_node_or_null("HUDPanel/TimerLabel") as Label
	_hud_exp_label = _hud.get_node_or_null("HUDPanel/EarnedLabel") as Label
	_hud_total_currency_label = _hud.get_node_or_null("HUDPanel/TotalCurrencyLabel") as Label

func _resolve_stage_boss_scene() -> PackedScene:
	## 依目前 burst_index 解析今次 boss 關對應嘅 PackedScene。
	if stage_boss_map.is_empty():
		return boss_scene
	var lm_div: int = 1
	if _level_manager and _level_manager.boss_every_n_mini_stages > 0:
		lm_div = _level_manager.boss_every_n_mini_stages
	## boss_index：第幾個 boss 關（0-based）
	var boss_index: int = maxi(0, (burst_index / lm_div) - 1)
	var idx: int = boss_index % stage_boss_map.size()
	var s: PackedScene = stage_boss_map[idx]
	if s == null:
		return boss_scene
	return s


func _resolve_stage_theme_name() -> String:
	if stage_theme_names.is_empty():
		return ""
	var lm_div: int = 1
	if _level_manager and _level_manager.boss_every_n_mini_stages > 0:
		lm_div = _level_manager.boss_every_n_mini_stages
	var boss_index: int = maxi(0, (burst_index / lm_div) - 1)
	return stage_theme_names[boss_index % stage_theme_names.size()]


func _spawn_boss() -> void:
	var scene_to_use: PackedScene = _resolve_stage_boss_scene()
	if not scene_to_use:
		return
	## 先顯示警報：BOSS WARNING + 紅光閃爍 + glow pulse + bass boost。
	var boss_name_for_warning: String = _peek_boss_display_name(scene_to_use)
	_trigger_boss_warning(boss_name_for_warning)
	## 延後生成實體，等警報播放到一半（視覺節奏）。
	await get_tree().create_timer(maxf(0.15, boss_warning_duration * 0.55)).timeout
	if _death_recovery_aborted():
		return
	var container: Node = get_parent().get_node_or_null(boss_container_path) if not boss_container_path.is_empty() else get_parent()
	if not container:
		container = get_parent()
	var inst: Node2D = scene_to_use.instantiate() as Node2D
	if not inst:
		push_warning("StageManager: failed to instantiate boss scene")
		return
	container.add_child(inst)
	var viewport_center := Vector2(576, 324)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player and is_instance_valid(player):
		inst.global_position = player.global_position + Vector2(0, -160)
	else:
		inst.global_position = viewport_center + Vector2(0, -100)
	_boss_instance = inst
	_boss_spawn_epoch_s = Time.get_ticks_msec() * 0.001
	if EventBus and EventBus.has_signal("boss_spawned"):
		EventBus.boss_spawned.emit(inst)


func _peek_boss_display_name(scene: PackedScene) -> String:
	## 以 scene path 猜 boss 名；若無對映就顯示 stage 主題名。
	var path: String = scene.resource_path.to_lower() if scene else ""
	if path.contains("neon_tank"):
		return "NEON TANK"
	if path.contains("cyber_warship") or path.contains("warship"):
		return "CYBER WARSHIP"
	if path.contains("humanoid_ace") or path.contains("ace"):
		return "HUMANOID ACE"
	if path.contains("neon_titan") or path.contains("titan"):
		return "NEON TITAN"
	if path.contains("refraction"):
		return "REFRACTION EXAMINER"
	var theme: String = _resolve_stage_theme_name()
	return theme if theme != "" else "BOSS"


func _trigger_boss_warning(display_name: String) -> void:
	if EventBus and EventBus.has_signal("boss_warning_requested"):
		EventBus.boss_warning_requested.emit(display_name, boss_warning_duration)
	var root: Node = get_tree().current_scene
	if not root:
		return
	if boss_warning_scene:
		var inst: Node = boss_warning_scene.instantiate()
		if inst is BossWarning:
			(inst as BossWarning).duration = boss_warning_duration
		root.add_child(inst)
		if inst.has_method("_play"):
			inst.call_deferred("_play", display_name)
		return
	## 程序化生成
	var warn: BossWarning = BossWarning.spawn(root, display_name, boss_warning_duration)
	if warn == null:
		push_warning("StageManager: failed to spawn BossWarning")


func _death_recovery_aborted() -> bool:
	## Boss 警報期間玩家陣亡時要中止生成。
	return stage_state == State.GAME_OVER


func _on_boss_defeated() -> void:
	if not _boss_instance:
		return
	## 允許 RUNNING / UPGRADE_PICK 狀態：level-up UI 同 boss 死亡可能同幀，UPGRADE_PICK 期間延後處理。
	if stage_state != State.RUNNING and stage_state != State.UPGRADE_PICK:
		return
	if _is_level_up_choice:
		## 玩家 level-up 中，先記錄；level-up 完成後由 _on_upgrade_chosen 補發。
		_pending_boss_defeated = true
		return
	burst_timer = 0.0
	_stop_spawner()
	_run_boss_defeated_flow()


func _connect_upgrade_chosen() -> void:
	if _upgrade_choice and _upgrade_choice.has_signal("upgrade_chosen"):
		if not _upgrade_choice.upgrade_chosen.is_connected(_on_upgrade_chosen):
			_upgrade_choice.upgrade_chosen.connect(_on_upgrade_chosen)
	elif _upgrade_choice and _upgrade_choice.has_signal("upgrade_selected"):
		if not _upgrade_choice.upgrade_selected.is_connected(_on_upgrade_chosen):
			_upgrade_choice.upgrade_selected.connect(_on_upgrade_chosen)


## Single authority: only one overlay visible. Call before showing any overlay.
func _hide_all_overlays() -> void:
	if _game_over:
		_game_over.hide()
	if _upgrade_choice:
		_upgrade_choice.hide()
	if _system_lab and is_instance_valid(_system_lab):
		_system_lab.hide()


## Apply UI for current state. Run Over only when state == GAME_OVER.
func _apply_ui_for_state() -> void:
	_hide_all_overlays()
	match stage_state:
		State.GAME_OVER:
			# _show_game_over is called separately with run summary (cleared, earned)
			pass
		State.UPGRADE_PICK:
			# Upgrade UI shows itself when upgrade_choice_requested is emitted
			pass
		_, State.RUNNING, State.BURST_END, State.BOSS, State.INTRO, State.LAB:
			pass


func start_game() -> void:
	if run_weapon_id.is_empty():
		run_weapon_id = "spread"
	if SynergyManager and SynergyManager.has_method("clear_run"):
		SynergyManager.clear_run()
	if UpgradeManager and UpgradeManager.has_method("clear_run"):
		UpgradeManager.clear_run()
	if RunState:
		RunState.run_active = true
		RunState.set_opening(4.0, 8.0)  # 0–8s: player stabilizes weapon rhythm
		RunState.reset_ignition()
	EventBus.run_started.emit(run_weapon_id)
	stage_state = State.RUNNING
	burst_index = 1
	bursts_cleared = 0
	run_currency = _get_starting_energy_bonus()
	_upgrades_taken_this_run.clear()
	_mid_run_upgrade_done = false
	_awaiting_burst_end_upgrade = false
	_is_level_up_choice = false
	_pending_wave_cleared_number = -1
	_pending_boss_defeated = false
	burst_timer = run_duration
	_current_wave_in_stage = 1
	Engine.time_scale = 1.0
	_start_spawner()


func _process(delta: float) -> void:
	if RunState and RunState.gameplay_frozen:
		_update_hud()
		return
	if stage_state != State.RUNNING:
		_update_hud()
		return
	if RunState:
		RunState.tick_opening(delta)
	if use_wave_loop:
		_update_hud()
		return
	var run_elapsed: float = run_duration - burst_timer
	if run_elapsed >= mid_run_upgrade_at and not _mid_run_upgrade_done:
		_trigger_mid_run_upgrade()
		return
	burst_timer -= delta
	_update_hud()
	_set_spawner_burst_time()
	if burst_timer <= 0.0:
		_on_burst_timer_expired()


func _is_boss_burst(idx: int) -> bool:
	return idx > 0 and (idx % boss_every_n_bursts) == 0


func _get_burst_duration(idx: int) -> float:
	return run_duration


func get_run_elapsed() -> float:
	return run_duration - burst_timer


## Run rhythm phase: 0 = stabilize (0–8s), 1 = density up (8–18s), 2 = ignition window (18–28s), 3 = peak (28–35s), 4 = release (35–40s).
func get_run_phase() -> int:
	if use_wave_loop:
		return clampi(_current_wave_in_stage - 1, 0, 4)
	var e := get_run_elapsed()
	if e < 8.0: return 0
	if e < 18.0: return 1
	if e < 28.0: return 2
	if e < 35.0: return 3
	return 4


## For boss design: 0 = not boss, 1 = pattern learning, 2 = pressure, 3 = peak chaos.
## 優先讀取 boss 自身 current_phase（血量驅動）；否則 fallback 到時間驅動（舊行為）。
func get_boss_phase() -> int:
	if not _boss_instance or not is_instance_valid(_boss_instance):
		return 0
	if "current_phase" in _boss_instance:
		var p: int = int(_boss_instance.current_phase)
		if p >= 1:
			return clampi(p, 1, 3)
	var boss_elapsed: float = 0.0
	if use_wave_loop:
		boss_elapsed = Time.get_ticks_msec() * 0.001 - _boss_spawn_epoch_s
	else:
		boss_elapsed = get_run_elapsed() - boss_spawn_at
	## HP-based fallback：若 boss 有 current_hp/max_hp 使用血量推算
	if "current_hp" in _boss_instance and "max_hp" in _boss_instance:
		var hp_pct: float = float(_boss_instance.current_hp) / float(maxi(1, int(_boss_instance.max_hp)))
		if hp_pct <= 0.33: return 3
		if hp_pct <= 0.66: return 2
		return 1
	## Legacy：時間閾值
	if boss_elapsed < 12.0: return 1
	if boss_elapsed < 24.0: return 2
	return 3


func _update_hud() -> void:
	if _hud:
		if not is_instance_valid(_hud_wave_label):
			_cache_hud_nodes()
		if _hud_wave_label:
			if use_wave_loop and _level_manager:
				_hud_wave_label.text = "小關卡 %d · 波 %d/%d" % [burst_index, _current_wave_in_stage, _level_manager.waves_per_upgrade]
			else:
				_hud_wave_label.text = "Stage %d / Burst %d" % [burst_index, burst_index]
		if _hud_run_status_label:
			if stage_state == State.BURST_END:
				_hud_run_status_label.text = "Stage cleared"
			elif _boss_instance and is_instance_valid(_boss_instance):
				_hud_run_status_label.text = "Boss!"
			elif use_wave_loop:
				_hud_run_status_label.text = "小關卡 %d" % burst_index
			else:
				_hud_run_status_label.text = "Stage %d" % burst_index
		if _hud_timer_label:
			if use_wave_loop and _level_manager:
				_hud_timer_label.text = "波次 %d/%d" % [_current_wave_in_stage, _level_manager.waves_per_upgrade]
			else:
				_hud_timer_label.text = "%ds" % maxi(0, int(ceilf(burst_timer)))
	if _hud:
		if _hud_exp_label:
			_hud_exp_label.text = "EXP: %d" % run_currency
		if _hud_total_currency_label and _save_manager and _save_manager.has_method("get_total_currency"):
			var name_key: String = SaveManager.CURRENCY_DISPLAY_NAME if SaveManager else "Energy Fragments"
			_hud_total_currency_label.text = "%s: %d" % [name_key, _save_manager.get_total_currency()]


func _start_spawner() -> void:
	if use_wave_loop and _level_manager:
		var is_boss: bool = _level_manager.is_boss_mini_stage(burst_index)
		if is_boss:
			_stop_spawner()
			var resolved_boss: PackedScene = _resolve_stage_boss_scene()
			if resolved_boss and not _boss_instance:
				_spawn_boss()
				return
			if _boss_instance and is_instance_valid(_boss_instance):
				return
			## Fallback：boss_scene 未設定但應為 boss 關卡 → 改為普通 wave，避免卡關冇內容。
			push_warning("StageManager: boss_scene missing for boss mini-stage %d; falling back to normal wave." % burst_index)
		_remove_boss()
		_current_wave_in_stage = 1
		if _wave_spawner and _wave_spawner.has_method("start_rogu_wave"):
			_wave_spawner.start_rogu_wave(burst_index, _current_wave_in_stage)
		return
	var is_boss: bool = _is_boss_burst(burst_index)
	if _wave_spawner and _wave_spawner.has_method("start_burst"):
		_wave_spawner.start_burst(burst_index, run_duration, is_boss)
		_set_spawner_burst_time()
	elif _wave_spawner and _wave_spawner.has_method("start_stage"):
		_wave_spawner.start_stage(burst_index, run_duration)
		_set_spawner_burst_time()
	if is_boss and _resolve_stage_boss_scene() and not _boss_instance:
		_spawn_boss()


func _on_event_bus_wave_cleared(wave_number: int) -> void:
	if not use_wave_loop or not _level_manager:
		return
	## 允許 RUNNING / UPGRADE_PICK 狀態：後者表示 level-up 升級中，需延遲處理。
	if stage_state != State.RUNNING and stage_state != State.UPGRADE_PICK:
		return
	if _is_level_up_choice:
		## 記錄最近一次（多隻敵機同幀死亡亦只保留最大 wave 編號即可）
		_pending_wave_cleared_number = maxi(_pending_wave_cleared_number, wave_number)
		return
	_process_wave_cleared(wave_number)


## 將 wave_cleared 核心流程抽出，便於升級完成後補發。
func _process_wave_cleared(wave_number: int) -> void:
	_current_wave_in_stage = wave_number
	if _level_manager.should_offer_upgrade_after_wave(wave_number):
		bursts_cleared = burst_index
		_stop_spawner()
		stage_state = State.BURST_END
		_awaiting_burst_end_upgrade = true
		_transition_to_upgrade_pick()
		return
	var next_wave: int = wave_number + 1
	_current_wave_in_stage = next_wave
	if _wave_spawner and _wave_spawner.has_method("start_rogu_wave"):
		_wave_spawner.start_rogu_wave(burst_index, next_wave)


func _set_spawner_burst_time() -> void:
	if _wave_spawner and _wave_spawner.has_method("set_burst_time_remaining"):
		_wave_spawner.set_burst_time_remaining(burst_timer)
	elif _wave_spawner and _wave_spawner.has_method("set_stage_time_remaining"):
		_wave_spawner.set_stage_time_remaining(burst_timer)


func _stop_spawner() -> void:
	if _wave_spawner and _wave_spawner.has_method("stop"):
		_wave_spawner.stop()


func _trigger_mid_run_upgrade() -> void:
	_mid_run_upgrade_done = true
	_awaiting_burst_end_upgrade = false
	_transition_to_upgrade_pick()


## Timer reached 0 with player alive: RUNNING → BURST_END → UPGRADE_PICK. Never Game Over.
func _on_burst_timer_expired() -> void:
	bursts_cleared = burst_index
	_stop_spawner()
	_remove_boss()
	stage_state = State.BURST_END
	_awaiting_burst_end_upgrade = true
	_transition_to_upgrade_pick()


## Centralized transition to UPGRADE_PICK: hide all overlays, stop spawner, show upgrade choices only.
func _transition_to_upgrade_pick() -> void:
	_hide_all_overlays()
	stage_state = State.UPGRADE_PICK
	_stop_spawner()
	Engine.time_scale = UPGRADE_CHOICE_TIME_SCALE
	if BeatConductor:
		BeatConductor.stage_clear_pulse()
	await get_tree().create_timer(0.04).timeout
	var choices: Array = _get_upgrade_choices()
	EventBus.upgrade_choice_requested.emit(choices)


func _run_boss_defeated_flow() -> void:
	if _boss_instance:
		await _run_boss_clear_sequence()
	_on_burst_timer_expired()


func _remove_boss() -> void:
	if _boss_instance:
		if EventBus and EventBus.has_signal("boss_despawned"):
			EventBus.boss_despawned.emit()
		_boss_instance.queue_free()
		_boss_instance = null
	_boss_spawn_epoch_s = 0.0


## Boss reward: one gameplay unlock (weapon / synergy / force). No stat boost. "I unlocked a new way to play."
func _grant_boss_reward() -> void:
	if not _save_manager:
		return
	var locked_weapons: Array[String] = []
	for id in SaveManager.ALL_WEAPON_IDS:
		if not _save_manager.is_weapon_unlocked(id):
			locked_weapons.append(id)
	var locked_synergies: Array[String] = []
	for id in SaveManager.ALL_SYNERGY_EFFECT_IDS:
		if not _save_manager.is_synergy_effect_unlocked(id):
			locked_synergies.append(id)
	var locked_forces: Array[String] = []
	for id in SaveManager.ALL_FORCE_PAIR_EFFECT_IDS:
		if not _save_manager.is_force_pair_effect_unlocked(id):
			locked_forces.append(id)
	var options: Array[Dictionary] = []
	if locked_weapons.size() > 0:
		options.append({"type": "weapon", "ids": locked_weapons})
	if locked_synergies.size() > 0:
		options.append({"type": "synergy", "ids": locked_synergies})
	if locked_forces.size() > 0:
		options.append({"type": "force", "ids": locked_forces})
	if options.is_empty():
		return
	var entry: Dictionary = options[burst_index % options.size()]
	var ids: Array = entry.ids
	var unlock_id: String = ids[randi() % ids.size()]
	var unlock_type: String = entry.type
	var display_name: String = ""
	match unlock_type:
		"weapon":
			display_name = _boss_reward_display_name_weapon(unlock_id)
			if _save_manager.has_method("grant_unlock_weapon"):
				_save_manager.grant_unlock_weapon(unlock_id)
		"synergy":
			display_name = _boss_reward_display_name_synergy(unlock_id)
			if _save_manager.has_method("grant_unlock_synergy_effect"):
				_save_manager.grant_unlock_synergy_effect(unlock_id)
		"force":
			display_name = _boss_reward_display_name_force(unlock_id)
			if _save_manager.has_method("grant_unlock_force_pair_effect"):
				_save_manager.grant_unlock_force_pair_effect(unlock_id)
	if EventBus.has_signal("boss_reward_unlocked"):
		EventBus.boss_reward_unlocked.emit(unlock_type, unlock_id, display_name)


func _boss_reward_display_name_weapon(weapon_id: String) -> String:
	match weapon_id:
		"beam": return "Beam"
		"spread": return "Spread"
		"drones": return "Drones"
		"burst": return "Pulse"
		"homing": return "Homing"
	return weapon_id.capitalize()


func _boss_reward_display_name_synergy(effect_id: String) -> String:
	match effect_id:
		"afterimage": return "Afterimage"
		"shockwave_split": return "Shockwave Split"
		"electric_burst": return "Chain Shock"
		"spreading_fire": return "Spreading Fire"
	return effect_id.replace("_", " ").capitalize()


func _boss_reward_display_name_force(effect_id: String) -> String:
	match effect_id:
		"afterimage": return "LIGHT + TIME"
		"bending_beams": return "LIGHT + SPACE"
		"gravity_slow": return "SPACE + TIME"
	return effect_id.replace("_", " ")


func _on_burst_end() -> void:
	_on_burst_timer_expired()


func _run_boss_clear_sequence() -> void:
	# Technical accomplishment: mastery, not spectacle. Minimal, precise, clean.
	var boss := _boss_instance
	if not boss:
		_remove_boss()
		return
	var bullet_pool: Node = get_parent().get_node_or_null("BulletPool")
	if bullet_pool and bullet_pool.has_method("clear_all"):
		bullet_pool.clear_all()
	if boss.has_method("stop_all_attacks"):
		boss.stop_all_attacks()
	await get_tree().create_timer(0.25).timeout
	if not is_instance_valid(boss):
		_remove_boss()
		return
	if boss.has_method("play_collapse_inward"):
		await boss.play_collapse_inward(0.4)
	if EventBus.has_signal("boss_clear_radial_pulse"):
		EventBus.boss_clear_radial_pulse.emit()
	if EventBus.has_signal("boss_clear_show_cleared"):
		EventBus.boss_clear_show_cleared.emit()
	if EventBus.has_signal("boss_clear_player_glow"):
		EventBus.boss_clear_player_glow.emit()
	await get_tree().create_timer(0.6).timeout
	_grant_boss_reward()
	if ThemeManager:
		ThemeManager.advance_theme_after_boss()
	_remove_boss()


func _is_synergy_unlocked(upgrade: UpgradeData) -> bool:
	if not upgrade or upgrade.effect_type != &"synergy" or upgrade.synergy_effect.is_empty():
		return true
	if not _save_manager or not _save_manager.has_method("is_synergy_effect_unlocked"):
		return true
	return _save_manager.is_synergy_effect_unlocked(upgrade.synergy_effect)


func _add_to_pool_if_unlocked(pool: Array, path: String) -> void:
	var res := load(path) as Resource
	if res is UpgradeData and not _is_synergy_unlocked(res as UpgradeData):
		return
	pool.append(res)


func _get_upgrade_choices() -> Array:
	var pool: Array = []
	if burst_index <= 1:
		_add_to_pool_if_unlocked(pool, "res://resources/upgrades/upgrade_pierce_echo.tres")
		_add_to_pool_if_unlocked(pool, "res://resources/upgrades/upgrade_orbit_shock.tres")
		_add_to_pool_if_unlocked(pool, "res://resources/upgrades/upgrade_pulse_split.tres")
		_add_to_pool_if_unlocked(pool, "res://resources/upgrades/upgrade_chain.tres")
		_add_to_pool_if_unlocked(pool, "res://resources/upgrades/upgrade_spreading_fire.tres")
		if run_weapon_id == "beam":
			_add_to_pool_if_unlocked(pool, "res://resources/upgrades/upgrade_pierce_echo.tres")
		elif run_weapon_id == "drones":
			_add_to_pool_if_unlocked(pool, "res://resources/upgrades/upgrade_orbit_shock.tres")
		elif run_weapon_id in ["spread", "burst", "homing", "rear"]:
			_add_to_pool_if_unlocked(pool, "res://resources/upgrades/upgrade_pulse_split.tres")
	else:
		pool.append(load("res://resources/upgrades/upgrade_fire_rate.tres") as Resource)
		pool.append(load("res://resources/upgrades/upgrade_damage.tres") as Resource)
		pool.append(load("res://resources/upgrades/upgrade_max_hp.tres") as Resource)
		pool.append(load("res://resources/upgrades/upgrade_vector_drive.tres") as Resource)
		pool.append(load("res://resources/upgrades/upgrade_rail_overclock.tres") as Resource)
		_add_to_pool_if_unlocked(pool, "res://resources/upgrades/upgrade_pierce_echo.tres")
		_add_to_pool_if_unlocked(pool, "res://resources/upgrades/upgrade_orbit_shock.tres")
		_add_to_pool_if_unlocked(pool, "res://resources/upgrades/upgrade_pulse_split.tres")
		_add_to_pool_if_unlocked(pool, "res://resources/upgrades/upgrade_chain.tres")
		_add_to_pool_if_unlocked(pool, "res://resources/upgrades/upgrade_spreading_fire.tres")
		if run_weapon_id == "beam":
			_add_to_pool_if_unlocked(pool, "res://resources/upgrades/upgrade_pierce_echo.tres")
		elif run_weapon_id == "drones":
			_add_to_pool_if_unlocked(pool, "res://resources/upgrades/upgrade_orbit_shock.tres")
		elif run_weapon_id in ["spread", "burst", "homing", "rear"]:
			_add_to_pool_if_unlocked(pool, "res://resources/upgrades/upgrade_pulse_split.tres")
		if run_currency >= 12:
			pool.append(load("res://resources/upgrades/upgrade_damage.tres") as Resource)
	if pool.is_empty():
		pool.append(load("res://resources/upgrades/upgrade_fire_rate.tres") as Resource)
	pool.shuffle()
	var choices: Array = []
	var n := mini(3, pool.size())
	for i in n:
		choices.append(pool[i])
	if choices.is_empty() and pool.size() > 0:
		choices.append(pool[0])
	return choices


func _on_upgrade_chosen(upgrade_resource: Resource) -> void:
	if upgrade_resource is UpgradeData:
		var ud := upgrade_resource as UpgradeData
		UpgradeManager.apply(ud)
		_upgrades_taken_this_run.append(ud.display_name)
	EventBus.upgrade_picked.emit()
	if _is_level_up_choice:
		_is_level_up_choice = false
		if RunState:
			RunState.gameplay_frozen = false
		Engine.time_scale = 1.0
		EventBus.upgrade_resume_phase.emit()
		_hide_all_overlays()
		if _upgrade_choice:
			_upgrade_choice.hide()
		stage_state = State.RUNNING
		## 升級期間若波次已清空，補發流程避免卡關（否則 wave_cleared 信號被丟失）。
		if _pending_wave_cleared_number >= 0:
			var wn: int = _pending_wave_cleared_number
			_pending_wave_cleared_number = -1
			_process_wave_cleared(wn)
		## 升級期間若 boss 死亡，補發 boss 清理流程（否則 _awaiting_burst_end_upgrade 永不設置，下一關卡起）。
		if _pending_boss_defeated:
			_pending_boss_defeated = false
			if _boss_instance:
				burst_timer = 0.0
				_stop_spawner()
				_run_boss_defeated_flow()
		## 若升級期間 burst 已結束（boss 清理完成或 wave 清空），補發推進下一關流程。
		## 冇呢段，_awaiting_burst_end_upgrade=true 但 level-up 路徑直接 return，burst_index 唔會加一，下一關卡唔會 spawn。
		if _awaiting_burst_end_upgrade:
			_transition_to_running_after_upgrade()
		return
	_transition_to_running_after_upgrade()


## Transition UPGRADE_PICK → RUNNING: one overlay hidden, next burst starts (timer reset, spawner start).
func _transition_to_running_after_upgrade() -> void:
	_hide_all_overlays()
	if _upgrade_choice:
		_upgrade_choice.hide()
	stage_state = State.RUNNING
	Engine.time_scale = 1.0
	if _awaiting_burst_end_upgrade:
		_awaiting_burst_end_upgrade = false
		burst_index += 1
		burst_timer = run_duration
	_start_spawner()


func _on_exp_collected(amount: int) -> void:
	run_currency += amount


func _on_level_up(_level: int) -> void:
	_is_level_up_choice = true
	stage_state = State.UPGRADE_PICK
	if RunState:
		RunState.gameplay_frozen = true
	_hide_all_overlays()
	var choices: Array = _get_upgrade_choices()
	EventBus.upgrade_choice_requested.emit(choices)


## Only transition that shows Run Over overlay. Timer reaching 0 never triggers this.
func _on_player_died() -> void:
	stage_state = State.GAME_OVER
	Engine.time_scale = 1.0
	_stop_spawner()
	if RunState:
		RunState.run_active = false
		RunState.quick_restart = true
		RunState.last_weapon_id = run_weapon_id
	var currency: int = run_currency + bursts_cleared * 10
	var level_reached: int = 1
	var player_node := get_tree().get_first_node_in_group("player")
	if player_node and "level" in player_node:
		level_reached = int(player_node.level)
	if _save_manager:
		if _save_manager.has_method("add_currency"):
			_save_manager.add_currency(currency)
		if _save_manager.has_method("record_run"):
			_save_manager.record_run(bursts_cleared)
	_apply_ui_for_state()
	_show_game_over(bursts_cleared, currency, level_reached)
	EventBus.game_over.emit()


func _show_game_over(cleared: int, earned: int, level_reached: int = 1) -> void:
	if not _game_over:
		return
	var panel: Node = _game_over.get_node_or_null("Panel")
	if panel:
		var sl: Label = panel.get_node_or_null("StagesClearedLabel") as Label
		if sl:
			sl.text = "Stages cleared: %d" % cleared
		var level_lbl: Label = panel.get_node_or_null("LevelReachedLabel") as Label
		if level_lbl:
			level_lbl.text = "Level reached: %d" % level_reached
		var builds_lbl: Label = panel.get_node_or_null("BuildsLabel") as Label
		if builds_lbl:
			var top3: Array[String] = []
			for i in mini(3, _upgrades_taken_this_run.size()):
				top3.append(_upgrades_taken_this_run[i])
			builds_lbl.text = "Build: %s" % (", ".join(top3) if top3.size() > 0 else "—")
			builds_lbl.visible = true
		var el: Label = panel.get_node_or_null("CurrencyEarnedLabel") as Label
		if el:
			el.text = "Fragments this run: %d" % earned
		var tl: Label = panel.get_node_or_null("TotalCurrencyLabel") as Label
		if tl and _save_manager and _save_manager.has_method("get_total_currency"):
			var name_key: String = SaveManager.CURRENCY_DISPLAY_NAME if SaveManager else "Energy Fragments"
			tl.text = "Total %s: %d" % [name_key, _save_manager.get_total_currency()]
		# Hide long clutter
		var ul: Label = panel.get_node_or_null("UpgradesTakenLabel") as Label
		if ul:
			ul.visible = false
		var res_label: Label = panel.get_node_or_null("ResonanceLabel") as Label
		if res_label:
			res_label.visible = false
		var build_label: Label = panel.get_node_or_null("BuildLabel") as Label
		if build_label:
			build_label.visible = false
	_game_over.show()
