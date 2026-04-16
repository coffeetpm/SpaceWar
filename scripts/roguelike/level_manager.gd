extends Node
class_name LevelManager
## 小關卡（mini stage）= 一輪「多波敵機 → 強化」的單位。
## 規則：每 `waves_per_upgrade` 波一般戰鬥後進入強化；每 `boss_every_n_mini_stages` 個小關卡為 Boss 層。

@export var waves_per_upgrade: int = 3:
	set(v):
		waves_per_upgrade = maxi(1, v)

@export var boss_every_n_mini_stages: int = 5:
	set(v):
		boss_every_n_mini_stages = maxi(1, v)


func is_boss_mini_stage(mini_stage_index: int) -> bool:
	return mini_stage_index > 0 and mini_stage_index % boss_every_n_mini_stages == 0


func should_offer_upgrade_after_wave(wave_index_in_stage: int) -> bool:
	return wave_index_in_stage >= waves_per_upgrade
