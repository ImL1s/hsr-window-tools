# en (English, fallback for any locale not in our 5-language set)
@{
    # === Tray ===
    tray_title            = 'WindowPatcher'
    tray_status_waiting   = 'Waiting for target process...'

    # === Tray menu items ===
    tray_menu_scan_now        = 'Scan and patch now'
    tray_menu_manage_targets  = 'Manage targets...'
    tray_menu_fps_wizard      = 'FPS Wizard (unlock HSR to 120 FPS)...'
    tray_menu_guard_on        = 'Persistent guard: Enable'
    tray_menu_guard_off       = 'Persistent guard: Disable'
    tray_menu_open_log        = 'Open log'
    tray_menu_open_config_dir = 'Open config folder'
    tray_menu_language        = 'Language / 語言'
    tray_menu_exit            = 'Exit'

    # === Startup errors ===
    error_admin_required_title = 'Administrator required'
    error_admin_required_body  = "Administrator privileges are required to patch game windows.`n`nYou just clicked No on the UAC prompt.`n`nPlease double-click the icon again and click Yes when UAC asks."
    error_startup_failed_title = 'Error'
    error_startup_failed_body  = 'Startup failed: {0}'
    error_already_running_title = 'Already running'
    error_already_running_body  = "WindowPatcher is already running.`n`nOpen settings from the tray icon at the bottom-right corner."

    # === Wizard ===
    wizard_start_title     = 'FPS Wizard'
    wizard_start_body      = "The FPS Wizard compares HSR registry content before and after you change a setting.`n`nNext steps:`n  1) Click OK to capture the baseline snapshot`n  2) In HSR: Settings -> Display -> change any option -> press ESC to close the panel`n  3) When an FPS field change is detected, you'll be prompted to patch to {0}`n`nNo need to close HSR; takes about 5-30 seconds."
    wizard_reg_missing_title = 'Error'
    wizard_reg_missing_body  = 'Registry path not found: {0}'
    wizard_running_title   = 'In progress'
    wizard_running_body    = 'The FPS Wizard is already running. Wait for it to finish or restart the tool.'
    wizard_result_title    = 'FPS Wizard Result'
    wizard_no_result_title = 'FPS Wizard - No Result'
    wizard_partial_fail_title = 'Wizard partially failed'
    wizard_partial_fail_body  = "No keys were patched (Apply-FpsCandidates returned 0).`n`nLikely reason: registry binary not writable, or FPS pattern did not match."

    # === Wizard summary ===
    wizard_summary_header           = "Scan results`n  Added keys:   {0}`n  Changed keys: {1}`n`n"
    wizard_summary_found_prefix     = "* Found {0} FPS candidate(s):`n"
    wizard_summary_apply_prompt     = "`nApply {0} FPS patch now?"
    wizard_summary_no_candidate     = "No obvious FPS candidates found. Possible reasons:`n  - Wait 2-3 seconds for HSR to flush registry, then retry`n  - FPS setting is not under this path`n`nChanged keys (first 5):`n"

    # === Guard ===
    guard_prompt_title = 'Enable persistent guard?'
    guard_prompt_body  = "FPS={0} has been patched.`n`nEnable persistent guard?`n`nYes = If HSR writes FPS back to 30/60 later (e.g. after touching other settings), the tool will re-patch back to {0} within 2 seconds`nNo = One-shot patch only; subsequent manual FPS changes won't be overwritten`n`nYou can toggle this anytime via tray right-click menu - Persistent guard: Enable/Disable."
    guard_enabled_title = 'Guard enabled'
    guard_enabled_body  = "Persistent guard is enabled.`n`nTo stop: right-click the tray icon -> Persistent guard: Disable."

    # === Settings dialog ===
    settings_no_target_title  = 'No target enabled'
    settings_no_target_body   = "No targets are enabled right now.`n`nPlease enable at least one (checkbox on the left)."
    settings_unsaved_title    = 'Unsaved'
    settings_unsaved_discard_body = "You have unsaved changes. Discard?`n`nYes = Discard and close`nNo = Keep editing"
    settings_unsaved_save_body    = "You have unsaved changes. Save them?`n`nYes = Save and close`nNo = Close without saving`nCancel = Keep editing"
    settings_status_format    = '{0} target(s) - {1} window(s) patched'
    settings_activity_count_format = '({0} entries)'

    # === Activity messages ===
    activity_window_patched     = 'Window patched - {0} (border draggable now)'
    activity_fps_waiting        = 'FPS waiting - {0}: in-game Settings -> Display -> change and save any option, key will appear and unlock automatically'
    activity_fps_unlocked       = 'FPS unlocked - {0} {1} -> {2}'
    activity_guard_enabled      = '* Persistent guard enabled (fpsTarget={0}) - toggle off via tray menu anytime'
    activity_guard_disabled_user = '* Persistent guard stopped - manual HSR FPS changes are no longer overwritten'
    activity_guard_enabled_user  = '* Persistent guard enabled - fpsTarget=120; any registry write-back will be re-patched within 2 seconds'
    activity_guard_decline      = 'Wizard: User chose one-shot patch; persistent guard not enabled'
    activity_wizard_patched     = 'FPS Wizard: Patched {0} key(s) -> {1}'
    activity_wizard_zero        = 'Wizard: Apply-FpsCandidates returned 0 patched; guard not enabled'
    activity_wizard_no_candidate = 'FPS Wizard: No FPS candidates found (added {0}, changed {1})'
    activity_wizard_started     = 'FPS Wizard started ({0} keys recorded as baseline)'
    activity_wizard_hint        = 'Next: HSR -> ESC -> Settings -> Display -> toggle FPS -> ESC to close panel (no need to close the game)'
    activity_reg_diff_detected  = 'Registry FPS field change detected - running diff + patch immediately (no need to wait for HSR to close)'
    activity_hsr_detected       = 'HSR detected (PID {0}) - I will detect immediately after you change FPS in HSR settings + close panel (no need to close game)'
    activity_hsr_closed         = 'HSR closed - forcing diff to check for changes'
    activity_wizard_timeout     = 'FPS Wizard: 15-minute timeout; cancelling'

    # === Balloon notifications ===
    balloon_fps_patched_title    = 'FPS patched'
    balloon_fps_patched_body     = 'patched {0} key(s) -> {1} FPS'
    balloon_fps_unlocked_title   = 'FPS unlocked'
    balloon_fps_unlocked_body    = '{0}: {1} -> {2} FPS'
    balloon_wizard_started_title = 'FPS Wizard started'
    balloon_wizard_started_body  = "After you change FPS in HSR + close the panel with ESC (no need to close the game), I'll automatically diff + patch to {0}"
    balloon_wizard_timeout_title = 'FPS Wizard timeout'
    balloon_wizard_timeout_body  = 'No changes detected in 15 minutes'
    balloon_scan_done_title      = 'WindowPatcher'
    balloon_scan_done_body       = 'Patched {0} window(s), {1} FPS setting(s)'
    balloon_guard_stopped_title  = 'Persistent guard stopped'
    balloon_guard_stopped_body   = 'HSR FPS changes will no longer be overwritten'
    balloon_guard_started_title  = 'Persistent guard enabled'
    balloon_guard_started_body   = 'When HSR touches other settings, FPS will be auto-repatched to 120'
    balloon_app_started_body     = 'Started (tray in the bottom-right corner)'

    # === Language switch ===
    lang_restart_title = 'Language switched'
    lang_restart_body  = "Language changed to {0}.`n`nRestart now to apply?`n`nYes = Restart in 3 seconds`nNo = Effective on next manual start"
}
