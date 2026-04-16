# REFRACT: LOOP — 架構與規範

## 資料夾結構

```
res://
├── scenes/
│   ├── main/          # 主場景、遊戲流程
│   ├── player/        # 玩家場景
│   ├── enemies/       # 敵人場景
│   ├── weapons/       # 武器、子彈場景
│   ├── upgrades/      # 升級 UI 場景（可選）
│   └── vfx/           # 攝影機、粒子等 VFX 場景
├── scripts/
│   ├── autoload/      # EventBus, GameManager, UpgradeApplier
│   ├── player/
│   ├── enemies/
│   ├── weapons/
│   │   └── patterns/  # 可重用彈幕腳本
│   ├── upgrades/
│   ├── vfx/
│   └── main/
└── resources/
    └── upgrades/      # UpgradeData .tres、腳本
```

## 場景樹建議 (Main)

```
Main (Node2D)
├── World (Node2D)
│   ├── BulletPool (Node2D)   # 子彈池，子節點為預生成 Bullet
│   ├── Player (CharacterBody2D)
│   │   └── WeaponMount → WeaponBase
│   └── Enemies (Node2D)
│       └── WaveSpawner       # 生成的敵人在 Enemies 下
├── Camera2D (GameCamera + CameraShake)
├── VFX (ExplosionVFX 等)
├── HitFlash (Node)
└── UI (CanvasLayer)
    ├── UpgradeChoice (UpgradeChoiceUI + ChoiceContainer)
    └── GameOver
```

## 命名規範

- **場景 (.tscn)**：`snake_case`，例：`player.tscn`, `weapon_base.tscn`, `enemy_basic.tscn`
- **腳本 (.gd)**：`snake_case`，與場景或功能對應，例：`player_controller.gd`, `bullet_pool.gd`
- **Class 名稱**：`PascalCase`，例：`PlayerController`, `WeaponBase`, `Bullet`, `EnemyBase`
- **節點名稱**：`PascalCase`（Godot 慣例），例：`BulletPool`, `WeaponMount`
- **訊號 / 函式**：`snake_case`，例：`wave_cleared`, `take_damage`
- **常數**：`SCREAMING_SNAKE` 或 `PascalCase`（依專案慣例）

## 溝通方式：EventBus

- 系統間**只用 EventBus 訊號**溝通，不直接持有其他系統的節點引用（除必要父子關係）。
- 好處：解耦、易測試、易擴充（新系統只訂閱訊號即可）。

## 效能：物件池

- **子彈**：一律經 `BulletPool` 取得/歸還，禁止在遊戲循環中 `instantiate`/`queue_free` 子彈。
- 池大小在 `BulletPool` 的 `pool_size` 調整；不足時可選擇擴池或丟棄本次發射。

## 遊戲流程 (第一版可玩迴圈)

1. **Main._ready** → `GameManager.start_game()` → 發送 `wave_started(1)`
2. **WaveSpawner** 收到 `wave_started` → 依波次生成敵人到 `Enemies`
3. **Player** 移動 + **WeaponBase** 自動開火 → 子彈經 **BulletPool** 發出
4. 敵人全滅 → **WaveSpawner** 發送 `wave_cleared` → **GameManager** 發送 `upgrade_choice_requested(choices)`
5. **UpgradeChoiceUI** 顯示 3 個選項 → 玩家選一個 → `GameManager.choose_upgrade()` → **UpgradeApplier** 套用 → 下一波 `wave_started(n+1)`
6. 玩家死亡 → `player_died` → `game_over` → 顯示 GameOver / 重開

## 輸入設定

在 Godot 編輯器 **Project → Project Settings → Input Map** 中新增：

- `move_left` → A (Key)
- `move_right` → D (Key)
- `move_up` → W (Key)
- `move_down` → S (Key)

## 擴充建議

- **新敵人**：繼承 `EnemyBase`，另做場景並在 WaveSpawner 的 pool 中替換或並存。
- **新彈幕**：使用 `patterns/` 下 Pattern（Spiral / Ring / TargetBurst）或新增 Pattern 腳本，只發送 `bullet_spawn_requested`。
- **新升級**：新增 `UpgradeData` .tres，在 `GameManager._get_upgrade_pool()` 加入；在 **UpgradeApplier** 的 `effect_type` 增加對應處理，並在 Player/Weapon 訂閱對應的 `upgrade_effect_*` 訊號。
