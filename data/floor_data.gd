class_name FloorData
extends Resource
## 單層樓的基礎參數。實際每層會依樓層編號與樓層類型修改（見 Game._build_floor_data）。
## 調整節奏時優先改 quota（配額），計時器盡量不動。

@export var quota := 10                     ## 需要的權限碎片數量（每往上一層 +2）
@export var purge_warning_time := 240.0     ## 清除協議警報（秒）
@export var hunter_spawn_time := 300.0      ## 追獵者出現（秒）
@export var energy_max := 100.0
@export var energy_drain := 2.5             ## 每秒電量消耗
@export var rat_count := 9                  ## 同時存在的資料鼠數量
@export var drone_count := 4                ## 同時存在的偵查無人機數量
@export var jumper_count := 0               ## 跳躍者（第 2 層起）
@export var replicator_count := 0           ## 複製體（第 3 層起）
@export var kiter_count := 0                ## 風箏手（第 2 層起）
@export var minelayer_count := 0            ## 佈雷者（第 3 層起）
@export var respawn_delay := 1.5            ## 補充獵物的間隔（秒）
@export var golden_spawn_time := 75.0       ## 金色獵物出現時間（秒）
@export var golden_count := 1
@export var elite_spawn_time := 100.0       ## 精英「裝甲運輸車」出現時間（秒），負數代表不出現
@export var prey_speed_mult := 1.0
@export var xp_mult := 1.0
@export var floor_type := &"normal"         ## normal / danger / repair / black_market / vault / boss
