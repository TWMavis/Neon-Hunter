# 依 Godot 技能檢視：可以改進的地方

對照 `.claude/skills/godot-*` 的建議檢查目前的程式碼。先跑了技能附的專案檢查腳本（`godot-nodes-scenes/scripts/check_godot_project.py`）：**475 個檔案，0 錯誤、0 警告**，場景與資源引用都沒問題。

下面是建議，依「效果 ÷ 工作量」排序。

## 優先（效果大、工作量小）

| # | 項目 | 目前的做法 | 技能的建議 | 工作量 |
|---|---|---|---|---|
| 1 | **音量匯流排與音量設定**（godot-audio） | 每個播放器直接設音量，沒有 Music／SFX 分開，玩家不能調音量 | 建 Master／Music／SFX 三條 bus，播放器指定 bus；加一個設定畫面調音量並存檔 | 小 |
| 2 | **GitHub 上自動跑測試**（godot-gdscript-headless-testing） | 冒煙測試只能在你電腦上手動跑 | 用 GitHub Actions 每次推送自動用無頭 Godot 跑 `tests/smoke_test.tscn`，失敗就標紅；加逾時避免卡住 | 小 |
| 3 | **按鍵設定放進專案、支援手把**（godot-gdscript、godot-2d-movement） | 輸入動作在程式裡註冊，編輯器的 Input Map 看不到，也不能改鍵；沒有手把 | 輸入動作寫進 project.godot，加上手把對應（企劃寫的右搖桿瞄準、RT／LT） | 小～中 |

## 值得做（讓你在編輯器裡直接調整）

| # | 項目 | 目前的做法 | 技能的建議 | 工作量 |
|---|---|---|---|---|
| 4 | **晶片、武器、獵物數值改成 .tres 資源**（godot-resources） | 寫在 `catalog.gd` 和 `prey.gd` 的程式碼裡 | 每枚晶片、每種獵物一個 `.tres`，在檢查器裡改數值不用碰程式 | 中 |
| 5 | **地圖改用 TileMapLayer**（godot-tilemap） | 地圖是程式裡的矩形清單 | 用 TileSet＋TileMapLayer 在編輯器裡直接畫關卡，碰撞跟著圖塊走；導航圖改從圖塊產生 | 中～大 |
| 6 | **存檔系統**（godot-resources、godot-export） | 沒有存檔，關掉遊戲什麼都不留 | 設定與局外成長（企劃的信用點永久強化、晶片圖鑑、共鳴紀錄）存到 `user://` | 中 |
| 7 | **霓虹發光與受擊效果的 Shader**（godot-shaders） | 受擊閃白用顏色相乘，沒有發光 | 受擊閃白 shader、霓虹 glow、可開關的 CRT 掃描線（企劃有寫） | 中 |

## 之後再說（大改，現在功能正常）

| # | 項目 | 目前的做法 | 技能的建議 | 工作量 |
|---|---|---|---|---|
| 8 | **玩家、獵物、子彈做成 .tscn 場景**（godot-nodes-scenes） | 全部用程式 `new()` 出來，在編輯器裡看不到也不能拖拉調整 | 每種實體一個場景，碰撞形狀、精靈、音效節點在編輯器裡擺 | 大 |
| 9 | **動畫改用 AnimatedSprite2D**（godot-animation） | 在 `_draw` 裡手動選影格 | SpriteFrames 管理動畫；配合 #8 一起做比較划算 | 中 |
| 10 | **HUD 改用 Control 節點**（godot-ui-control） | HUD 用 `_draw` 畫字和長條 | 用 Label、ProgressBar 等節點，排版和換字型比較容易 | 中 |
| 11 | **匯出設定**（godot-export） | 還沒有匯出預設 | 建 Windows 匯出預設，能打包成 exe 給別人玩；匯出後要實測一次 | 小（需要先下載匯出範本） |

## 小地方

- 掉落物、電梯每幀都用 `get_first_node_in_group("player")` 找玩家，可以快取起來（godot-signals-groups）
- 圖片和音效是程式產生的，Godot 編輯器開著時會自動匯入；之後如果改用 TileMapLayer／AnimatedSprite2D，匯入設定要確認是 Nearest 濾鏡
