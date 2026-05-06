extends Node
## 子彈工廠 (Autoload singleton — 不可加 class_name，會與 autoload 名稱衝突)
## 支援三種視覺風格：Plasma / Needle / Heavy。
## 統一入口：EventBus.bullet_spawn_styled(pos, dir, speed, damage, is_player, weapon_id, style_id)
##
## 使用範例（GDScript）：
##   EventBus.bullet_spawn_styled.emit(
##       global_position, Vector2.UP, 600.0, 12, true, "heavy_cannon",
##       BulletFactory.STYLE_HEAVY
##   )
##
## 也可直接呼叫：
##   BulletFactory.spawn_styled(pos, dir, speed, damage, true, "plasma", BulletFactory.STYLE_PLASMA)

## ── 樣式常數（對應 Bullet 常數，外部可用本名稱引用）────────
const STYLE_DEFAULT := 0
const STYLE_PLASMA  := 1   ## 電漿：圓形、中心極亮、外圍電弧
const STYLE_NEEDLE  := 2   ## 針式：極細長、超長拖尾
const STYLE_HEAVY   := 3   ## 重型：體積大、命中衝擊波 + Hit Stop

## ── 樣式預設參數表（速度 / 傷害 / 拖尾倍率等）─────────────
## 各欄位在 spawn_styled() 中作為 fallback，呼叫者可自行覆蓋。
const STYLE_DEFAULTS: Dictionary = {
	STYLE_PLASMA: {
		"speed_mul":   0.95,   ## 電漿稍慢（視覺上較大）
		"light_energy": 3.2,
		"trail_mul":   0.7,    ## 較短拖尾（由 apply_style 處理）
	},
	STYLE_NEEDLE: {
		"speed_mul":   1.35,   ## 針式極快
		"light_energy": 1.6,
		"trail_mul":   2.6,
	},
	STYLE_HEAVY: {
		"speed_mul":   0.60,   ## 重型緩慢
		"light_energy": 5.0,
		"trail_mul":   0.45,
	},
}

## ── Pool 快取 ──────────────────────────────────────────────
var _bullet_pool: BulletPool = null


func _ready() -> void:
	EventBus.bullet_spawn_styled.connect(_on_bullet_spawn_styled)


## ─────────────────────────────────────────────────────────────
## 公開 API：直接呼叫（無需 EventBus）
## ─────────────────────────────────────────────────────────────

## 生成一顆樣式子彈。speed_override <= 0 時使用樣式預設倍率。
func spawn_styled(
		pos: Vector2,
		direction: Vector2,
		speed: float,
		damage: int,
		is_player: bool,
		weapon_id: String,
		style_id: int,
		speed_override: float = -1.0
) -> void:
	var pool := _get_pool()
	if pool == null:
		push_warning("BulletFactory: BulletPool not found (group 'bullet_pool').")
		return
	var bullet: Bullet = pool.get_next()
	if bullet == null:
		return  ## Pool 耗盡，靜默放棄

	## 速度應用樣式倍率（可被 speed_override 覆蓋）
	var final_speed: float = speed
	if speed_override > 0.0:
		final_speed = speed_override
	elif STYLE_DEFAULTS.has(style_id):
		final_speed = speed * float(STYLE_DEFAULTS[style_id].get("speed_mul", 1.0))

	bullet.setup(pos, direction, final_speed, damage, is_player, false, weapon_id, false)
	bullet.apply_style(style_id, damage, is_player)

	## 若 EventBus 有 refraction 系統，亦觸發 echo（標準 plasma/needle，heavy 不複製）
	if is_player and style_id != STYLE_HEAVY and SaveManager and SaveManager.is_refraction_unlocked():
		var echo: Bullet = pool.get_next()
		if echo:
			const ECHO_ANGLE := 0.2
			var echo_dir := direction.normalized().rotated(ECHO_ANGLE)
			echo.setup(pos, echo_dir, final_speed, maxi(1, damage / 2), true, false, weapon_id, true)
			echo.apply_style(style_id, damage / 2, true)


## ─────────────────────────────────────────────────────────────
## EventBus 監聽
## ─────────────────────────────────────────────────────────────

func _on_bullet_spawn_styled(
		pos: Vector2,
		direction: Vector2,
		speed: float,
		damage: int,
		is_player: bool,
		weapon_id: String,
		style_id: int
) -> void:
	spawn_styled(pos, direction, speed, damage, is_player, weapon_id, style_id)


## ─────────────────────────────────────────────────────────────
## 內部：取得 BulletPool 引用（每次驗證有效）
## ─────────────────────────────────────────────────────────────

func _get_pool() -> BulletPool:
	if _bullet_pool != null and is_instance_valid(_bullet_pool):
		return _bullet_pool
	var tree := get_tree()
	if tree:
		_bullet_pool = tree.get_first_node_in_group("bullet_pool") as BulletPool
	return _bullet_pool


## ─────────────────────────────────────────────────────────────
## 便利靜態方法（從任何腳本呼叫，無需 $BulletFactory 引用）
## ─────────────────────────────────────────────────────────────

## 從玩家武器快速發射：根據 style_id 帶預設速度
static func fire_player(
		pos: Vector2,
		damage: int,
		style_id: int,
		base_speed: float = 600.0,
		direction: Vector2 = Vector2.UP
) -> void:
	EventBus.bullet_spawn_styled.emit(pos, direction, base_speed, damage, true, _style_weapon_id(style_id), style_id)


## 從敵人發射樣式子彈
static func fire_enemy(
		pos: Vector2,
		direction: Vector2,
		damage: int,
		style_id: int,
		base_speed: float = 320.0
) -> void:
	EventBus.bullet_spawn_styled.emit(pos, direction, base_speed, damage, false, _style_weapon_id(style_id), style_id)


static func _style_weapon_id(style_id: int) -> String:
	match style_id:
		STYLE_PLASMA: return "plasma"
		STYLE_NEEDLE: return "needle"
		STYLE_HEAVY:  return "heavy"
		_:            return "default"
