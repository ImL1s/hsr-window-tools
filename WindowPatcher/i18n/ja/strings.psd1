# ja (日本語) — translated by LLM, native-speaker review welcomed
@{
    # === Tray ===
    tray_title            = 'ウィンドウパッチャー'
    tray_status_waiting   = '対象プロセスの起動を待機中...'

    # === Tray menu items ===
    tray_menu_scan_now        = '今すぐスキャン＆パッチ'
    tray_menu_manage_targets  = 'ターゲットを管理...'
    tray_menu_fps_wizard      = 'FPS ウィザード (HSR を 120 FPS に解放)...'
    tray_menu_guard_on        = '常時保護: 有効化'
    tray_menu_guard_off       = '常時保護: 停止'
    tray_menu_open_log        = 'ログを開く'
    tray_menu_open_config_dir = '設定フォルダを開く'
    tray_menu_language        = '言語 / Language'
    tray_menu_exit            = '終了'

    # === Startup errors ===
    error_admin_required_title = '管理者権限が必要'
    error_admin_required_body  = "ゲームウィンドウのパッチには管理者権限が必要です。`n`n先ほど UAC ダイアログで「いいえ」を選択しました。`n`nアイコンを再度ダブルクリックし、UAC で「はい」をクリックしてください。"
    error_startup_failed_title = 'エラー'
    error_startup_failed_body  = '起動失敗: {0}'
    error_already_running_title = '起動済み'
    error_already_running_body  = "ウィンドウパッチャーは既に実行中です。`n`n右下のトレイアイコンから設定を開いてください。"

    # === Wizard ===
    wizard_start_title     = 'FPS ウィザード'
    wizard_start_body      = "FPS ウィザードは HSR がレジストリに書き込む内容を「現在」と「変更後」で比較します。`n`n次の手順:`n  1) 「OK」をクリックしてベースラインスナップショットを作成`n  2) HSR で 設定 -> 画面 -> 任意のオプションを変更 -> ESC で設定パネルを閉じる`n  3) FPS フィールドの変化を検出すると、{0} にパッチするか確認のダイアログが表示されます`n`nHSR を閉じる必要はありません。所要時間は約 5-30 秒。"
    wizard_reg_missing_title = 'エラー'
    wizard_reg_missing_body  = 'レジストリパスが見つかりません: {0}'
    wizard_running_title   = '実行中'
    wizard_running_body    = 'FPS ウィザードは既に実行中です。完了を待つかツールを再起動してください。'
    wizard_result_title    = 'FPS ウィザード結果'
    wizard_no_result_title = 'FPS ウィザード - 結果なし'
    wizard_partial_fail_title = 'ウィザード部分失敗'
    wizard_partial_fail_body  = "key のパッチに失敗しました (Apply-FpsCandidates が 0 を返しました)`n`n考えられる原因: レジストリバイナリが書き込み不可、または FPS パターンが一致しなかった"

    # === Wizard summary ===
    wizard_summary_header           = "スキャン結果`n  追加 key: {0}`n  変更 key: {1}`n`n"
    wizard_summary_found_prefix     = "★ {0} 個の FPS 候補が見つかりました:`n"
    wizard_summary_apply_prompt     = "`n今 {0} FPS パッチを適用しますか?"
    wizard_summary_no_candidate     = "明確な FPS 候補が見つかりませんでした。考えられる原因:`n  • HSR のレジストリフラッシュを 2-3 秒待ってから再試行`n  • FPS 設定がこの path にない`n`n変更された keys (最初の 5 件):`n"

    # === Guard ===
    guard_prompt_title = '常時保護を有効化しますか?'
    guard_prompt_body  = "FPS={0} のパッチが完了しました。`n`n常時保護を有効化しますか?`n`nはい = HSR が他の設定変更で FPS を 30/60 に書き戻した場合、2 秒以内に {0} に再パッチします`nいいえ = 一回限りのパッチ、ユーザーの後続の手動 FPS 変更は上書きされません`n`nトレイ右クリックメニュー「常時保護: 有効化/停止」でいつでも切り替え可能。"
    guard_enabled_title = '保護が有効'
    guard_enabled_body  = "常時保護が有効化されました。`n`n停止方法: 右下のトレイアイコンを右クリック → 常時保護: 停止"

    # === Settings dialog ===
    settings_no_target_title  = '有効なターゲットなし'
    settings_no_target_body   = "現在有効なターゲットがありません。`n`n少なくとも 1 つ有効化してください (左側のチェックボックス)。"
    settings_unsaved_title    = '未保存'
    settings_unsaved_discard_body = "未保存の変更があります。破棄しますか?`n`nはい = 破棄して閉じる`nいいえ = 編集を続ける"
    settings_unsaved_save_body    = "未保存の変更があります。保存しますか?`n`nはい = 保存して閉じる`nいいえ = 保存せず閉じる`nキャンセル = 編集を続ける"
    settings_status_format    = '{0} ターゲット · {1} ウィンドウをパッチ済み'
    settings_activity_count_format = '({0} 件)'

    # === Activity messages ===
    activity_window_patched     = 'ウィンドウをパッチ済み — {0} (枠をドラッグ可能)'
    activity_fps_waiting        = 'FPS 待機中 — {0}: ゲーム内設定 → グラフィック → 任意のオプションを変更して保存、key が生成されると自動解放'
    activity_fps_unlocked       = 'FPS 解放済み — {0} {1} → {2}'
    activity_guard_enabled      = '★ 常時保護を有効化 (fpsTarget={0}) — トレイメニューからいつでも停止可能'
    activity_guard_disabled_user = '★ 常時保護を停止 — 手動の HSR FPS 変更は上書きされなくなりました'
    activity_guard_enabled_user  = '★ 常時保護を有効化 — fpsTarget=120、レジストリ書き戻しは 2 秒以内に再パッチされます'
    activity_guard_decline      = 'ウィザード: ユーザーは一回限りのパッチを選択、常時保護は有効化されません'
    activity_wizard_patched     = 'FPS ウィザード: {0} 個の key をパッチ → {1}'
    activity_wizard_zero        = 'ウィザード: Apply-FpsCandidates が 0 を返しました、保護は有効化されません'
    activity_wizard_no_candidate = 'FPS ウィザード: FPS 候補が見つかりません (追加 {0}, 変更 {1})'
    activity_wizard_started     = 'FPS ウィザード起動 ({0} keys をベースラインとして記録)'
    activity_wizard_hint        = '次のステップ: HSR → ESC → 設定 → グラフィック → FPS を切り替え → ESC で設定パネルを閉じる (ゲームを閉じる必要なし)'
    activity_reg_diff_detected  = 'レジストリ内の FPS フィールド変化を検出 — 直ちに diff + patch (HSR の終了を待たない)'
    activity_hsr_detected       = 'HSR を検出 (PID {0}) — HSR の FPS 設定変更 + ESC で設定パネルを閉じた直後に検出します (ゲームを閉じる必要なし)'
    activity_hsr_closed         = 'HSR が閉じられました — 強制 diff で変化を確認'
    activity_wizard_timeout     = 'FPS ウィザード: 15 分タイムアウト、キャンセル'

    # === Balloon notifications ===
    balloon_fps_patched_title    = 'FPS パッチ済み'
    balloon_fps_patched_body     = '{0} 個の key をパッチ → {1} FPS'
    balloon_fps_unlocked_title   = 'FPS 解放済み'
    balloon_fps_unlocked_body    = '{0}: {1} → {2} FPS'
    balloon_wizard_started_title = 'FPS ウィザード起動'
    balloon_wizard_started_body  = 'HSR で FPS 設定変更 + ESC でパネルを閉じた後 (ゲームを閉じる必要なし)、自動的に diff + patch を {0} に実行します'
    balloon_wizard_timeout_title = 'FPS ウィザード timeout'
    balloon_wizard_timeout_body  = '15 分間変化を検出できませんでした'
    balloon_scan_done_title      = 'ウィンドウパッチャー'
    balloon_scan_done_body       = '{0} ウィンドウ、{1} FPS 設定をパッチ'
    balloon_guard_stopped_title  = '常時保護が停止'
    balloon_guard_stopped_body   = 'HSR の FPS 変更は今後上書きされません'
    balloon_guard_started_title  = '常時保護が有効'
    balloon_guard_started_body   = 'HSR が他の設定を変更すると FPS は自動的に 120 に再パッチされます'
    balloon_app_started_body     = '起動済み (右下のトレイ)'

    # === Language switch ===
    lang_restart_title = '言語が切り替えられました'
    lang_restart_body  = "言語が {0} に変更されました。`n`n今すぐ再起動して反映しますか?`n`nはい = 3 秒後に再起動`nいいえ = 次回手動起動時に反映"
}
