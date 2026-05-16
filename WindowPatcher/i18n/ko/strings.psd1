# ko (한국어) — translated by LLM, native-speaker review welcomed
@{
    # === Tray ===
    tray_title            = '윈도우 패처'
    tray_status_waiting   = '대상 프로세스 시작 대기 중...'

    # === Tray menu items ===
    tray_menu_scan_now        = '지금 스캔 및 패치'
    tray_menu_manage_targets  = '대상 관리...'
    tray_menu_fps_wizard      = 'FPS 마법사 (HSR 120 FPS 잠금 해제)...'
    tray_menu_guard_on        = '지속 보호: 활성화'
    tray_menu_guard_off       = '지속 보호: 중지 (fpsTarget={0})'
    tray_menu_open_log        = '로그 열기'
    tray_menu_open_config_dir = '설정 폴더 열기'
    tray_menu_language        = '언어 / Language'
    tray_menu_exit            = '종료'

    # === Startup errors ===
    error_admin_required_title = '관리자 권한 필요'
    error_admin_required_body  = "게임 창을 패치하려면 관리자 권한이 필요합니다.`n`n방금 UAC 대화 상자에서 「아니오」를 클릭했습니다.`n`n아이콘을 다시 더블 클릭하고 UAC가 묻는 대로 「예」를 클릭하세요."
    error_startup_failed_title = '오류'
    error_startup_failed_body  = '시작 실패: {0}'
    error_already_running_title = '이미 실행 중'
    error_already_running_body  = "윈도우 패처가 이미 실행 중입니다.`n`n오른쪽 하단 트레이 아이콘에서 설정을 열어 주세요."

    # === Wizard ===
    wizard_start_title     = 'FPS 마법사'
    wizard_start_body      = "FPS 마법사는 HSR이 레지스트리에 쓰는 내용을 「현재」와 「변경 후」로 비교합니다.`n`n다음 단계:`n  1) 「확인」을 클릭하여 베이스라인 스냅샷 생성`n  2) HSR에서 설정 -> 화면 -> 임의 옵션 변경 -> ESC로 설정 패널 닫기`n  3) FPS 필드 변경이 감지되면 {0}(으)로 패치할지 묻는 대화 상자가 표시됩니다`n`nHSR을 닫을 필요 없습니다. 약 5-30초 소요됩니다."
    wizard_reg_missing_title = '오류'
    wizard_reg_missing_body  = '레지스트리 경로를 찾을 수 없음: {0}'
    wizard_running_title   = '진행 중'
    wizard_running_body    = 'FPS 마법사가 이미 실행 중입니다. 완료를 기다리거나 도구를 재시작하세요.'
    wizard_result_title    = 'FPS 마법사 결과'
    wizard_no_result_title = 'FPS 마법사 - 결과 없음'
    wizard_partial_fail_title = '마법사 부분 실패'
    wizard_partial_fail_body  = "key 패치에 실패했습니다 (Apply-FpsCandidates가 0을 반환)`n`n가능한 원인: 레지스트리 바이너리 쓰기 불가, 또는 FPS 패턴이 일치하지 않음"

    # === Wizard summary ===
    wizard_summary_header           = "스캔 결과`n  추가 key: {0}`n  변경 key: {1}`n`n"
    wizard_summary_found_prefix     = "★ {0}개의 FPS 후보 발견:`n"
    wizard_summary_apply_prompt     = "`n지금 {0} FPS 패치를 적용하시겠습니까?"
    wizard_summary_no_candidate     = "명확한 FPS 후보를 찾을 수 없습니다. 가능한 원인:`n  • HSR이 레지스트리를 flush하도록 2-3초 기다린 후 재시도`n  • FPS 설정이 이 path에 없음`n`n변경된 keys (처음 5개):`n"

    # === Guard ===
    guard_prompt_title = '지속 보호를 활성화하시겠습니까?'
    guard_prompt_body  = "FPS={0} 패치 완료.`n`n지속 보호를 활성화하시겠습니까?`n`n예 = HSR이 다른 설정 변경으로 FPS를 30/60으로 다시 쓰면, 도구가 2초 이내에 {0}으로 재패치합니다`n아니오 = 일회성 패치, 사용자의 후속 수동 FPS 조정은 덮어쓰여지지 않습니다`n`n트레이 우클릭 메뉴 「지속 보호: 활성화/중지」로 언제든지 전환 가능."
    guard_enabled_title = '보호 활성화됨'
    guard_enabled_body  = "지속 보호가 활성화되었습니다.`n`n중지 방법: 오른쪽 하단 트레이 우클릭 → 지속 보호: 중지"

    # === Settings dialog ===
    settings_no_target_title  = '활성화된 대상 없음'
    settings_no_target_body   = "현재 활성화된 대상이 없습니다.`n`n최소 한 개 이상 활성화해 주세요 (왼쪽 체크박스)."
    settings_unsaved_title    = '저장되지 않음'
    settings_unsaved_discard_body = "저장되지 않은 변경 사항이 있습니다. 폐기하시겠습니까?`n`n예 = 폐기하고 닫기`n아니오 = 편집 계속"
    settings_unsaved_save_body    = "저장되지 않은 변경 사항이 있습니다. 저장하시겠습니까?`n`n예 = 저장하고 닫기`n아니오 = 저장하지 않고 닫기`n취소 = 편집 계속"
    settings_status_format    = '{0}개 대상 · {1}개 창 패치됨'
    settings_activity_count_format = '({0}개)'

    # === Activity messages ===
    activity_window_patched     = '창 패치됨 — {0} (이제 테두리 드래그 가능)'
    activity_fps_waiting        = 'FPS 대기 중 — {0}: 게임 내 설정 → 그래픽 → 임의 옵션 변경 후 저장, key 생성 후 자동 잠금 해제'
    activity_fps_unlocked       = 'FPS 잠금 해제됨 — {0} {1} → {2}'
    activity_guard_enabled      = '★ 지속 보호 활성화됨 (fpsTarget={0}) — 트레이 메뉴에서 언제든지 중지 가능'
    activity_guard_disabled_user = '★ 지속 보호 중지됨 — 수동 HSR FPS 조정이 더 이상 덮어쓰이지 않습니다'
    activity_guard_enabled_user  = '★ 지속 보호 활성화됨 — fpsTarget=120, 레지스트리 쓰기 백은 2초 이내 재패치됩니다'
    activity_guard_decline      = '마법사: 사용자가 일회성 패치 선택, 지속 보호 활성화 안 됨'
    activity_wizard_patched     = 'FPS 마법사: {0}개 key 패치됨 → {1}'
    activity_wizard_zero        = '마법사: Apply-FpsCandidates가 0을 반환, 보호 활성화 안 됨'
    activity_wizard_no_candidate = 'FPS 마법사: FPS 후보 없음 (추가 {0}, 변경 {1})'
    activity_wizard_started     = 'FPS 마법사 시작 ({0} keys를 베이스라인으로 기록)'
    activity_wizard_hint        = '다음 단계: HSR → ESC → 설정 → 그래픽 → FPS 전환 → ESC로 설정 패널 닫기 (게임 닫을 필요 없음)'
    activity_reg_diff_detected  = '레지스트리 내 FPS 필드 변경 감지 — 즉시 diff + patch (HSR 종료 대기 불필요)'
    activity_hsr_detected       = 'HSR 감지 (PID {0}) — HSR의 FPS 설정 변경 + ESC로 설정 패널 닫은 직후 즉시 감지 (게임 닫을 필요 없음)'
    activity_hsr_closed         = 'HSR 종료됨 — 강제 diff로 변경 사항 확인'
    activity_wizard_timeout     = 'FPS 마법사: 15분 timeout, 취소'

    # === Balloon notifications ===
    balloon_fps_patched_title    = 'FPS 패치됨'
    balloon_fps_patched_body     = '{0}개 key 패치됨 → {1} FPS'
    balloon_fps_unlocked_title   = 'FPS 잠금 해제됨'
    balloon_fps_unlocked_body    = '{0}: {1} → {2} FPS'
    balloon_wizard_started_title = 'FPS 마법사 시작'
    balloon_wizard_started_body  = 'HSR에서 FPS 설정 변경 + ESC로 패널 닫은 후 (게임 닫을 필요 없음), 자동으로 diff + patch를 {0}으로 실행합니다'
    balloon_wizard_timeout_title = 'FPS 마법사 timeout'
    balloon_wizard_timeout_body  = '15분 동안 변경 사항이 감지되지 않았습니다'
    balloon_scan_done_title      = '윈도우 패처'
    balloon_scan_done_body       = '{0}개 창, {1}개 FPS 설정 패치됨'
    balloon_guard_stopped_title  = '지속 보호 중지됨'
    balloon_guard_stopped_body   = 'HSR FPS 변경 사항은 더 이상 덮어쓰이지 않습니다'
    balloon_guard_started_title  = '지속 보호 활성화됨'
    balloon_guard_started_body   = 'HSR이 다른 설정을 변경하면 FPS가 자동으로 120으로 재패치됩니다'
    balloon_app_started_body     = '시작됨 (오른쪽 하단 트레이)'

    # === Language switch ===
    lang_restart_title = '언어 전환됨'
    lang_restart_body  = "언어가 {0}(으)로 변경되었습니다.`n`n지금 재시작하여 적용하시겠습니까?`n`n예 = 3초 후 재시작`n아니오 = 다음 수동 시작 시 적용"
}
