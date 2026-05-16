# zh-TW (繁體中文,canonical) — i18n strings for WindowPatcher
# 修改 key 後請同步 en/zh-CN/ja/ko 對應檔 (Pester key parity test 會驗)
@{
    # === Tray ===
    tray_title            = '視窗修補器'
    tray_status_waiting   = '等待目標程式啟動...'

    # === Tray menu items ===
    tray_menu_scan_now        = '立即掃描修補'
    tray_menu_manage_targets  = '管理目標...'
    tray_menu_fps_wizard      = 'FPS 探查精靈 (HSR 解鎖到 120 FPS)...'
    tray_menu_guard_on        = '持續守護: 啟動'
    tray_menu_guard_off       = '持續守護: 停止'
    tray_menu_open_log        = '開啟 log'
    tray_menu_open_config_dir = '開啟設定資料夾'
    tray_menu_language        = '語言 / Language'
    tray_menu_exit            = '結束'

    # === Startup errors ===
    error_admin_required_title = '需要管理員權限'
    error_admin_required_body  = "需要管理員權限才能修補遊戲視窗。`n`n你剛剛在 UAC 對話框按了「否」。`n`n請重新雙擊圖示,並在 UAC 詢問時點「是」。"
    error_startup_failed_title = '錯誤'
    error_startup_failed_body  = '啟動失敗:{0}'
    error_already_running_title = '已啟動'
    error_already_running_body  = "視窗修補器已經在執行中。`n`n請從右下角托盤圖示開啟設定。"

    # === Wizard ===
    wizard_start_title     = 'FPS 探查精靈'
    wizard_start_body      = "FPS 探查精靈會比對「現在」跟「之後」HSR 寫到 registry 的內容。`n`n下一步:`n  1) 點「確定」建立基準快照`n  2) 在 HSR 進設定 -> 畫面 -> 隨便動一個選項 -> ESC 關設定面板`n  3) 偵測到 FPS 欄位變化後會自動彈窗問是否 patch 到 {0}`n`n不必關 HSR,過程約 5-30 秒。"
    wizard_reg_missing_title = '錯誤'
    wizard_reg_missing_body  = 'Registry 路徑不存在: {0}'
    wizard_running_title   = '進行中'
    wizard_running_body    = 'FPS Wizard 已在執行中,請先讓它完成或重啟工具'
    wizard_result_title    = 'FPS Wizard 結果'
    wizard_no_result_title = 'FPS Wizard 無結果'
    wizard_partial_fail_title = 'Wizard 部分失敗'
    wizard_partial_fail_body  = "沒成功 patch 任何 key (Apply-FpsCandidates 回傳 0)`n`n可能原因: registry binary 無法寫入,或 FPS pattern 未匹配"

    # === Wizard summary (動態組裝, {0} = added count, {1} = changed count, {2} = candidate count, {3} = target FPS) ===
    wizard_summary_header           = "本次掃描結果`n  新增 key: {0}`n  變更 key: {1}`n`n"
    wizard_summary_found_prefix     = "★ 找到 {0} 個 FPS 候選:`n"
    wizard_summary_apply_prompt     = "`n是否現在寫入 {0} FPS patch?"
    wizard_summary_no_candidate     = "沒找到明顯 FPS 候選。可能:`n  • 等 2-3 秒讓 HSR flush registry 後再試`n  • FPS 設定不在此 path`n`n變更 keys (前 5):`n"

    # === Guard ===
    guard_prompt_title = '啟動持續守護?'
    guard_prompt_body  = "已 patch FPS={0}。`n`n是否啟動「持續守護」?`n`n是 = 之後 HSR 動其他設定若把 FPS 寫回 30/60,工具會 2 秒內 re-patch 回 {0}`n否 = 只 patch 這一次,使用者後續手動調整 FPS 不被覆寫`n`n之後可從 tray 右鍵選單「持續守護: 啟動/停止」隨時切換。"
    guard_enabled_title = '守護已啟動'
    guard_enabled_body  = "持續守護已啟動。`n`n停止方法:右下角托盤右鍵 → 持續守護:停止"

    # === Settings dialog ===
    settings_no_target_title  = '沒有啟用目標'
    settings_no_target_body   = "目前沒有啟用的目標。`n`n請至少啟用一個 (左側勾選方塊)。"
    settings_unsaved_title    = '未儲存'
    settings_unsaved_discard_body = "你有未儲存的變更,確定要放棄?`n`n是 = 放棄並關閉`n否 = 繼續編輯"
    settings_unsaved_save_body    = "你有未儲存的變更,要儲存嗎?`n`n是 = 儲存並關閉`n否 = 不儲存關閉`n取消 = 繼續編輯"
    settings_status_format    = '{0} 個目標 · 已修補 {1} 個視窗'
    settings_activity_count_format = '({0} 筆)'

    # === Activity messages ===
    activity_window_patched     = '視窗已修補 — {0} (現可拖曳邊框)'
    activity_fps_waiting        = 'FPS 等待中 — {0}: 進遊戲設定 → 圖形 → 任意動一個選項按儲存,鍵生成後自動解鎖'
    activity_fps_unlocked       = 'FPS 已解鎖 — {0} {1} → {2}'
    activity_guard_enabled      = '★ 已啟動持續守護 (fpsTarget={0}) — 可從 tray menu 隨時停止'
    activity_guard_disabled_user = '★ 持續守護已停止 — 使用者手動調 HSR FPS 不再被覆寫'
    activity_guard_enabled_user  = '★ 持續守護已啟動 — fpsTarget=120,registry 寫回會被 2 秒內 re-patch'
    activity_guard_decline      = 'Wizard: 使用者選擇只 patch 一次,不啟動持續守護'
    activity_wizard_patched     = 'FPS Wizard: 已 patch {0} 個 key → {1}'
    activity_wizard_zero        = 'Wizard: Apply-FpsCandidates 回傳 0 patched, 不啟用守護'
    activity_wizard_no_candidate = 'FPS Wizard: 沒找到 FPS 候選 (新增 {0}, 變更 {1})'
    activity_wizard_started     = 'FPS Wizard 啟動 (已記下 {0} keys 當基準)'
    activity_wizard_hint        = '下一步: 進 HSR → ESC → 設定 → 畫面 → 切換 FPS → ESC 關設定面板 (不必關遊戲)'
    activity_reg_diff_detected  = '偵測到 registry 內 FPS 欄位變化 — 立即 diff + patch (不需等 HSR 關閉)'
    activity_hsr_detected       = '偵測到 HSR (PID {0}) — 在 HSR 改 FPS 設定 + ESC 關設定面板後我會立即偵測 (不必關遊戲)'
    activity_hsr_closed         = 'HSR 已關閉 — 強制 diff 看是否有變化'
    activity_wizard_timeout     = 'FPS Wizard: 15 分鐘 timeout,取消'

    # === Balloon notifications ===
    balloon_fps_patched_title    = 'FPS 已寫入'
    balloon_fps_patched_body     = 'patched {0} 個 key → {1} FPS'
    balloon_fps_unlocked_title   = 'FPS 已解鎖'
    balloon_fps_unlocked_body    = '{0}: {1} → {2} FPS'
    balloon_wizard_started_title = 'FPS Wizard 已啟動'
    balloon_wizard_started_body  = '在 HSR 動 FPS 設定 + ESC 關面板後 (不必關遊戲),我會自動 diff + patch 到 {0}'
    balloon_wizard_timeout_title = 'FPS Wizard timeout'
    balloon_wizard_timeout_body  = '15 分鐘沒偵測到變化'
    balloon_scan_done_title      = '視窗修補器'
    balloon_scan_done_body       = '已修補 {0} 個視窗、{1} 個 FPS 設定'
    balloon_guard_stopped_title  = '持續守護已停止'
    balloon_guard_stopped_body   = '之後 HSR 動 FPS 設定工具不再覆寫'
    balloon_guard_started_title  = '持續守護已啟動'
    balloon_guard_started_body   = 'HSR 動其他設定後 FPS 會自動 re-patch 回 120'
    balloon_app_started_body     = '已啟動 (托盤右下角)'

    # === Language switch ===
    lang_restart_title = '語言已切換'
    lang_restart_body  = "語言已改為 {0}。`n`n要立即重啟生效嗎?`n`n是 = 重啟 (3 秒後)`n否 = 下次手動啟動再生效"
}
