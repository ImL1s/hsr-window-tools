# zh-CN (简体中文)
@{
    # === Tray ===
    tray_title            = '窗口修补器'
    tray_status_waiting   = '等待目标程序启动...'

    # === Tray menu items ===
    tray_menu_scan_now        = '立即扫描修补'
    tray_menu_manage_targets  = '管理目标...'
    tray_menu_fps_wizard      = 'FPS 探查向导 (HSR 解锁到 120 FPS)...'
    tray_menu_guard_on        = '持续守护: 启用'
    tray_menu_guard_off       = '持续守护: 停止'
    tray_menu_open_log        = '打开 log'
    tray_menu_open_config_dir = '打开配置文件夹'
    tray_menu_language        = '语言 / Language'
    tray_menu_exit            = '退出'

    # === Startup errors ===
    error_admin_required_title = '需要管理员权限'
    error_admin_required_body  = "需要管理员权限才能修补游戏窗口。`n`n你刚刚在 UAC 对话框点了「否」。`n`n请重新双击图标,并在 UAC 询问时点「是」。"
    error_startup_failed_title = '错误'
    error_startup_failed_body  = '启动失败:{0}'
    error_already_running_title = '已启动'
    error_already_running_body  = "窗口修补器已在运行中。`n`n请从右下角托盘图标打开设置。"

    # === Wizard ===
    wizard_start_title     = 'FPS 探查向导'
    wizard_start_body      = "FPS 探查向导会对比「现在」和「之后」HSR 写到 registry 的内容。`n`n下一步:`n  1) 点「确定」建立基准快照`n  2) 在 HSR 进设置 -> 画面 -> 随便动一个选项 -> ESC 关闭设置面板`n  3) 检测到 FPS 字段变化后会自动弹窗问是否 patch 到 120`n`n不必关 HSR,过程约 5-30 秒。"
    wizard_reg_missing_title = '错误'
    wizard_reg_missing_body  = 'Registry 路径不存在: {0}'
    wizard_running_title   = '进行中'
    wizard_running_body    = 'FPS 向导已在运行中,请先让它完成或重启工具'
    wizard_result_title    = 'FPS 向导结果'
    wizard_no_result_title = 'FPS 向导无结果'
    wizard_partial_fail_title = '向导部分失败'
    wizard_partial_fail_body  = "没成功 patch 任何 key (Apply-FpsCandidates 返回 0)`n`n可能原因: registry binary 无法写入,或 FPS pattern 未匹配"

    # === Wizard summary ===
    wizard_summary_header           = "本次扫描结果`n  新增 key: {0}`n  变更 key: {1}`n`n"
    wizard_summary_found_prefix     = "★ 找到 {0} 个 FPS 候选:`n"
    wizard_summary_apply_prompt     = "`n是否现在写入 {0} FPS patch?"
    wizard_summary_no_candidate     = "没找到明显 FPS 候选。可能:`n  • 等 2-3 秒让 HSR flush registry 后再试`n  • FPS 设置不在此 path`n`n变更 keys (前 5):`n"

    # === Guard ===
    guard_prompt_title = '启动持续守护?'
    guard_prompt_body  = "已 patch FPS={0}。`n`n是否启动「持续守护」?`n`n是 = 之后 HSR 动其他设置若把 FPS 写回 30/60,工具会 2 秒内 re-patch 回 {0}`n否 = 只 patch 这一次,用户后续手动调整 FPS 不被覆盖`n`n之后可从 tray 右键菜单「持续守护: 启用/停止」随时切换。"
    guard_enabled_title = '守护已启动'
    guard_enabled_body  = "持续守护已启动。`n`n停止方法:右下角托盘右键 → 持续守护:停止"

    # === Settings dialog ===
    settings_no_target_title  = '没有启用目标'
    settings_no_target_body   = "目前没有启用的目标。`n`n请至少启用一个 (左侧勾选框)。"
    settings_unsaved_title    = '未保存'
    settings_unsaved_discard_body = "你有未保存的变更,确定要放弃?`n`n是 = 放弃并关闭`n否 = 继续编辑"
    settings_unsaved_save_body    = "你有未保存的变更,要保存吗?`n`n是 = 保存并关闭`n否 = 不保存关闭`n取消 = 继续编辑"
    settings_status_format    = '{0} 个目标 · 已修补 {1} 个窗口'
    settings_activity_count_format = '({0} 条)'

    # === Activity messages ===
    activity_window_patched     = '窗口已修补 — {0} (现可拖动边框)'
    activity_fps_waiting        = 'FPS 等待中 — {0}: 进游戏设置 → 图形 → 任意动一个选项点保存,key 生成后自动解锁'
    activity_fps_unlocked       = 'FPS 已解锁 — {0} {1} → {2}'
    activity_guard_enabled      = '★ 已启动持续守护 (fpsTarget={0}) — 可从 tray menu 随时停止'
    activity_guard_disabled_user = '★ 持续守护已停止 — 用户手动调 HSR FPS 不再被覆盖'
    activity_guard_enabled_user  = '★ 持续守护已启动 — fpsTarget=120,registry 写回会被 2 秒内 re-patch'
    activity_guard_decline      = '向导: 用户选择只 patch 一次,不启动持续守护'
    activity_wizard_patched     = 'FPS 向导: 已 patch {0} 个 key → {1}'
    activity_wizard_zero        = '向导: Apply-FpsCandidates 返回 0 patched, 不启用守护'
    activity_wizard_no_candidate = 'FPS 向导: 没找到 FPS 候选 (新增 {0}, 变更 {1})'
    activity_wizard_started     = 'FPS 向导启动 (已记录 {0} keys 当基准)'
    activity_wizard_hint        = '下一步: 进 HSR → ESC → 设置 → 画面 → 切换 FPS → ESC 关设置面板 (不必关游戏)'
    activity_reg_diff_detected  = '检测到 registry 内 FPS 字段变化 — 立即 diff + patch (不需等 HSR 关闭)'
    activity_hsr_detected       = '检测到 HSR (PID {0}) — 在 HSR 改 FPS 设置 + ESC 关设置面板后我会立即检测 (不必关游戏)'
    activity_hsr_closed         = 'HSR 已关闭 — 强制 diff 看是否有变化'
    activity_wizard_timeout     = 'FPS 向导: 15 分钟 timeout,取消'

    # === Balloon notifications ===
    balloon_fps_patched_title = 'FPS 已写入'
    balloon_fps_patched_body  = 'patched {0} 个 key → {1} FPS'

    # === Language switch ===
    lang_restart_title = '语言已切换'
    lang_restart_body  = "语言已改为 {0}。`n`n要立即重启生效吗?`n`n是 = 重启 (3 秒后)`n否 = 下次手动启动再生效"
}
