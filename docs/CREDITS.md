# 素材來源與授權

本專案目前**沒有使用任何外部素材**。所有像素圖、音效、音樂都是由專案內的程式產生：

| 素材 | 位置 | 產生方式 |
|---|---|---|
| 像素圖（角色、獵物、地形、道具、電梯） | `art/*.png` | `tools/generate_assets.gd` 裡的字元圖 |
| 音效（26 個） | `audio/*.wav` | `tools/generate_assets.gd` 的波形合成 |
| 音樂（`music_hunt`、`music_calm`） | `audio/music_*.wav` | `tools/generate_assets.gd` 的合成波音序 |
| 介面字型 | 系統字型（微軟正黑體等） | 執行時讀取使用者電腦上的字型，沒有打包進專案 |

這些產生出來的素材和專案其他部分一樣歸專案擁有者所有，可以自由修改、商用。

## 重新產生素材

```
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/generate_assets.gd
```

改圖：編輯 `tools/generate_assets.gd` 裡的字元圖（一個字元一個像素，對應檔案開頭的 `PALETTE`）。
預覽所有精靈圖（放大 6 倍）：

```
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/contact_sheet.gd -- 預覽.png
```

## 之後加入外部素材時

在這個檔案記下：名稱、作者、來源網址、授權（例如 CC0、CC-BY 4.0）、放在專案的哪裡。
需要標註作者（CC-BY）或不能商用（CC-NC）的素材，加入前先確認。

## 外掛

| 名稱 | 版本 | 授權 | 來源 |
|---|---|---|---|
| Godot AI（`addons/godot_ai`） | 4.3.0 | MIT | https://github.com/hi-godot/godot-ai |
