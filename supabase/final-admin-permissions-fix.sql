-- 관리자 권한 시스템 완전 수정판
-- 작성일: 2025-09-06
-- 목표: 모든 예상 문제점을 해결한 안정적인 관리자 권한 시스템

-- ==============================================
-- 문제점 해결 요약
-- ==============================================
-- ✅ auth.email() 함수 비존재 → auth.users 테이블 직접 조회
-- ✅ admin_activity_log 테이블 미생성 → 테이블 생성 코드 추가
-- ✅ NOT FOUND 처리 로직 → 명시적 RETURN 추가
-- ✅ 이메일 대소문자 문제 → LOWER() 함수 사용
-- ✅ NULL 처리 강화 → 모든 단계에서 NULL 체크

-- ==============================================
-- 1. 필요한 테이블 생성 (존재하지 않으면)
-- ==============================================

-- admin_activity_log 테이블 생성
CREATE TABLE IF NOT EXISTS admin_activity_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id UUID NOT NULL,
  admin_email TEXT NOT NULL,
  action_type TEXT NOT NULL,
  target_id TEXT,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_admin_activity_log_admin_id ON admin_activity_log(admin_id);
CREATE INDEX IF NOT EXISTS idx_admin_activity_log_created_at ON admin_activity_log(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_activity_log_action ON admin_activity_log(action_type);

-- ==============================================
-- 2. 안전한 현재 사용자 이메일 조회 함수
-- ==============================================

CREATE OR REPLACE FUNCTION get_current_user_email()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_user_email TEXT;
BEGIN
  -- 현재 인증된 사용자 ID 가져오기
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RETURN NULL;
  END IF;
  
  -- auth.users 테이블에서 이메일 조회
  SELECT LOWER(TRIM(u.email)) INTO v_user_email
  FROM auth.users u
  WHERE u.id = v_user_id;
  
  RETURN v_user_email;
EXCEPTION
  WHEN OTHERS THEN
    RETURN NULL;
END;
$$;

-- ==============================================
-- 3. 강화된 관리자 권한 확인 함수
-- ==============================================

CREATE OR REPLACE FUNCTION get_admin_permissions()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_email TEXT;
  v_admin_perms JSONB;
BEGIN
  -- 현재 사용자 이메일 가져오기
  v_user_email := get_current_user_email();
  
  IF v_user_email IS NULL OR v_user_email = '' THEN
    RETURN '{}'::jsonb;
  END IF;
  
  -- 관리자 권한 조회 (이메일 기반, 대소문자 무시)
  SELECT COALESCE(ap.permissions, '{}'::jsonb) INTO v_admin_perms
  FROM admin_profiles ap
  WHERE LOWER(TRIM(ap.email)) = v_user_email 
    AND ap.is_active = true;
  
  -- 결과가 없으면 빈 객체 반환
  IF v_admin_perms IS NULL THEN
    RETURN '{}'::jsonb;
  END IF;
  
  RETURN v_admin_perms;
EXCEPTION
  WHEN OTHERS THEN
    RETURN '{}'::jsonb;
END;
$$;

-- ==============================================
-- 4. 관리자 상태 확인 함수 (디버깅용)
-- ==============================================

CREATE OR REPLACE FUNCTION check_admin_status()
RETURNS TABLE (
    step_name TEXT,
    step_result TEXT,
    step_value TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_user_email TEXT;
  v_profile_exists BOOLEAN := false;
  v_profile_active BOOLEAN := false;
  v_profile_role TEXT;
  v_permissions JSONB;
BEGIN
  -- Step 1: 현재 사용자 ID 확인
  v_user_id := auth.uid();
  RETURN QUERY SELECT 'Step 1: User ID'::TEXT, 
                      CASE WHEN v_user_id IS NOT NULL THEN 'SUCCESS' ELSE 'FAILED' END::TEXT,
                      COALESCE(v_user_id::TEXT, 'NULL')::TEXT;
  
  -- Step 2: 사용자 이메일 확인
  v_user_email := get_current_user_email();
  RETURN QUERY SELECT 'Step 2: User Email'::TEXT,
                      CASE WHEN v_user_email IS NOT NULL THEN 'SUCCESS' ELSE 'FAILED' END::TEXT,
                      COALESCE(v_user_email, 'NULL')::TEXT;
  
  IF v_user_email IS NULL THEN
    RETURN QUERY SELECT 'ERROR'::TEXT, 'Cannot get user email'::TEXT, ''::TEXT;
    RETURN;
  END IF;
  
  -- Step 3: admin_profiles에서 프로필 확인
  SELECT true, ap.is_active, ap.role, ap.permissions 
  INTO v_profile_exists, v_profile_active, v_profile_role, v_permissions
  FROM admin_profiles ap
  WHERE LOWER(TRIM(ap.email)) = v_user_email;
  
  RETURN QUERY SELECT 'Step 3: Profile Exists'::TEXT,
                      CASE WHEN v_profile_exists THEN 'SUCCESS' ELSE 'FAILED' END::TEXT,
                      CASE WHEN v_profile_exists THEN 'Profile Found' ELSE 'Profile Not Found' END::TEXT;
  
  RETURN QUERY SELECT 'Step 4: Profile Active'::TEXT,
                      CASE WHEN v_profile_active THEN 'SUCCESS' ELSE 'FAILED' END::TEXT,
                      CASE WHEN v_profile_active THEN 'Active' ELSE 'Inactive' END::TEXT;
  
  RETURN QUERY SELECT 'Step 5: Profile Role'::TEXT, 'INFO'::TEXT, COALESCE(v_profile_role, 'NULL')::TEXT;
  
  RETURN QUERY SELECT 'Step 6: Permissions'::TEXT, 'INFO'::TEXT, COALESCE(v_permissions::TEXT, 'NULL')::TEXT;
END;
$$;

-- ==============================================
-- 5. 간단한 관리자 확인 함수
-- ==============================================

CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_email TEXT;
  v_is_admin BOOLEAN := false;
BEGIN
  -- 현재 사용자 이메일 가져오기
  v_user_email := get_current_user_email();
  
  IF v_user_email IS NULL THEN
    RETURN false;
  END IF;
  
  -- 관리자 여부 확인
  SELECT true INTO v_is_admin
  FROM admin_profiles ap
  WHERE LOWER(TRIM(ap.email)) = v_user_email 
    AND ap.is_active = true
  LIMIT 1;
  
  RETURN COALESCE(v_is_admin, false);
EXCEPTION
  WHEN OTHERS THEN
    RETURN false;
END;
$$;

-- ==============================================
-- 6. 관리자 로그 기록 함수
-- ==============================================

CREATE OR REPLACE FUNCTION log_admin_activity(
  p_action_type TEXT,
  p_target_id TEXT DEFAULT NULL,
  p_notes TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin_id UUID;
  v_admin_email TEXT;
BEGIN
  v_admin_id := auth.uid();
  v_admin_email := get_current_user_email();
  
  IF v_admin_id IS NULL OR v_admin_email IS NULL THEN
    RETURN false;
  END IF;
  
  INSERT INTO admin_activity_log (
    admin_id, admin_email, action_type, target_id, notes, created_at
  )
  VALUES (
    v_admin_id, v_admin_email, p_action_type, p_target_id, p_notes, NOW()
  );
  
  RETURN true;
EXCEPTION
  WHEN OTHERS THEN
    RETURN false;
END;
$$;

-- ==============================================
-- 7. UUID 기반 관리자 예약 승인 함수 (완전 수정판)
-- ==============================================

CREATE OR REPLACE FUNCTION admin_confirm_reservation(
  p_reservation_id UUID,
  p_admin_notes TEXT DEFAULT NULL
) RETURNS TABLE(
  success BOOLEAN, 
  error_msg TEXT,
  reservation_data JSONB
)
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
DECLARE
  v_reservation RECORD;
BEGIN
  -- 관리자 권한 확인
  IF NOT is_admin() THEN
    RETURN QUERY SELECT false, '관리자 권한이 없습니다.'::TEXT, NULL::JSONB;
    RETURN;
  END IF;
  
  -- 예약 존재 확인
  SELECT * INTO v_reservation FROM reservations WHERE id = p_reservation_id;
  
  IF NOT FOUND THEN
    RETURN QUERY SELECT false, '예약을 찾을 수 없습니다.'::TEXT, NULL::JSONB;
    RETURN;
  END IF;
  
  -- 예약 상태 업데이트
  UPDATE reservations 
  SET status = 'confirmed', updated_at = NOW()
  WHERE id = p_reservation_id;
  
  -- 관리자 활동 로그
  PERFORM log_admin_activity('confirm_reservation', p_reservation_id::TEXT, p_admin_notes);
  
  -- 성공 반환
  RETURN QUERY SELECT 
    true, 
    NULL::TEXT,
    jsonb_build_object(
      'reservation_id', p_reservation_id,
      'customer_name', v_reservation.name,
      'status', 'confirmed',
      'admin_notes', p_admin_notes
    );
END;
$$;

-- ==============================================
-- 8. UUID 기반 관리자 예약 취소 함수 (완전 수정판)
-- ==============================================

CREATE OR REPLACE FUNCTION admin_cancel_reservation(
  p_reservation_id UUID,
  p_cancellation_reason TEXT DEFAULT NULL,
  p_admin_notes TEXT DEFAULT NULL
) RETURNS TABLE(
  success BOOLEAN, 
  error_msg TEXT,
  reservation_data JSONB
)
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
DECLARE
  v_reservation RECORD;
  v_full_notes TEXT;
BEGIN
  -- 관리자 권한 확인
  IF NOT is_admin() THEN
    RETURN QUERY SELECT false, '관리자 권한이 없습니다.'::TEXT, NULL::JSONB;
    RETURN;
  END IF;
  
  -- 예약 존재 확인
  SELECT * INTO v_reservation FROM reservations WHERE id = p_reservation_id;
  
  IF NOT FOUND THEN
    RETURN QUERY SELECT false, '예약을 찾을 수 없습니다.'::TEXT, NULL::JSONB;
    RETURN;
  END IF;
  
  -- 예약 상태 업데이트
  UPDATE reservations 
  SET status = 'cancelled', updated_at = NOW()
  WHERE id = p_reservation_id;
  
  -- 로그용 메모 조합
  v_full_notes := COALESCE(p_cancellation_reason, '');
  IF p_admin_notes IS NOT NULL THEN
    v_full_notes := v_full_notes || ' | Admin Notes: ' || p_admin_notes;
  END IF;
  
  -- 관리자 활동 로그
  PERFORM log_admin_activity('cancel_reservation', p_reservation_id::TEXT, v_full_notes);
  
  -- 성공 반환
  RETURN QUERY SELECT 
    true, 
    NULL::TEXT,
    jsonb_build_object(
      'reservation_id', p_reservation_id,
      'customer_name', v_reservation.name,
      'status', 'cancelled',
      'cancellation_reason', p_cancellation_reason,
      'admin_notes', p_admin_notes
    );
END;
$$;

-- ==============================================
-- 9. UUID 기반 관리자 예약 삭제 함수 (완전 수정판)
-- ==============================================

CREATE OR REPLACE FUNCTION admin_delete_reservation(
  p_reservation_id UUID,
  p_deletion_reason TEXT DEFAULT NULL
) RETURNS TABLE(
  success BOOLEAN, 
  error_msg TEXT,
  reservation_data JSONB
)
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
DECLARE
  v_reservation RECORD;
  v_backup_info TEXT;
BEGIN
  -- 관리자 권한 확인
  IF NOT is_admin() THEN
    RETURN QUERY SELECT false, '관리자 권한이 없습니다.'::TEXT, NULL::JSONB;
    RETURN;
  END IF;
  
  -- 예약 존재 확인
  SELECT * INTO v_reservation FROM reservations WHERE id = p_reservation_id;
  
  IF NOT FOUND THEN
    RETURN QUERY SELECT false, '예약을 찾을 수 없습니다.'::TEXT, NULL::JSONB;
    RETURN;
  END IF;
  
  -- 삭제 전 백업 정보 생성
  v_backup_info := 'DELETED - ' || v_reservation.name || ' (' || v_reservation.phone || 
                   ') Date: ' || v_reservation.reservation_date || 
                   COALESCE(' Reason: ' || p_deletion_reason, '');
  
  -- 관리자 활동 로그 (삭제 전)
  PERFORM log_admin_activity('delete_reservation', p_reservation_id::TEXT, v_backup_info);
  
  -- 예약 삭제
  DELETE FROM reservations WHERE id = p_reservation_id;
  
  -- 성공 반환
  RETURN QUERY SELECT 
    true, 
    NULL::TEXT,
    jsonb_build_object(
      'reservation_id', p_reservation_id,
      'customer_name', v_reservation.name,
      'action', 'deleted',
      'deletion_reason', p_deletion_reason
    );
END;
$$;

-- ==============================================
-- 10. 함수 권한 설정
-- ==============================================

GRANT EXECUTE ON FUNCTION get_current_user_email TO authenticated;
GRANT EXECUTE ON FUNCTION get_admin_permissions TO authenticated;
GRANT EXECUTE ON FUNCTION check_admin_status TO authenticated;
GRANT EXECUTE ON FUNCTION is_admin TO authenticated;
GRANT EXECUTE ON FUNCTION log_admin_activity TO authenticated;
GRANT EXECUTE ON FUNCTION admin_confirm_reservation TO authenticated;
GRANT EXECUTE ON FUNCTION admin_cancel_reservation TO authenticated;
GRANT EXECUTE ON FUNCTION admin_delete_reservation TO authenticated;

-- ==============================================
-- 11. 함수 존재 확인 및 테스트
-- ==============================================

-- 생성된 함수들 확인
SELECT 
    'Function Check' as test_type,
    proname as function_name,
    pg_get_function_arguments(oid) as arguments
FROM pg_proc 
WHERE proname IN (
    'get_current_user_email', 'get_admin_permissions', 'check_admin_status', 
    'is_admin', 'admin_confirm_reservation', 'admin_cancel_reservation', 
    'admin_delete_reservation', 'log_admin_activity'
)
ORDER BY proname;

-- ==============================================
-- 12. 테스트 쿼리 예시
-- ==============================================

-- 관리자 상태 전체 체크 (이것부터 실행해서 문제 진단)
SELECT 'ADMIN STATUS CHECK' as test_name;
SELECT * FROM check_admin_status();

-- 간단한 관리자 확인
SELECT 'IS ADMIN CHECK' as test_name, is_admin() as result;

-- 권한 확인
SELECT 'PERMISSIONS CHECK' as test_name, get_admin_permissions() as permissions;

-- 현재 사용자 이메일 확인
SELECT 'EMAIL CHECK' as test_name, get_current_user_email() as email;

-- ==============================================
-- 13. 성공 메시지
-- ==============================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🎉 관리자 권한 시스템 완전 수정 완료!';
    RAISE NOTICE '=====================================';
    RAISE NOTICE '✅ get_current_user_email() - 안전한 이메일 조회';
    RAISE NOTICE '✅ get_admin_permissions() - 강화된 권한 확인';
    RAISE NOTICE '✅ check_admin_status() - 단계별 디버깅';
    RAISE NOTICE '✅ is_admin() - 간단한 관리자 확인';
    RAISE NOTICE '✅ log_admin_activity() - 활동 로그 기록';
    RAISE NOTICE '✅ admin_confirm_reservation() - UUID 기반 승인';
    RAISE NOTICE '✅ admin_cancel_reservation() - UUID 기반 취소';
    RAISE NOTICE '✅ admin_delete_reservation() - UUID 기반 삭제';
    RAISE NOTICE '✅ admin_activity_log 테이블 생성';
    RAISE NOTICE '';
    RAISE NOTICE '🔍 디버깅 방법:';
    RAISE NOTICE '   SELECT * FROM check_admin_status();';
    RAISE NOTICE '   SELECT is_admin();';
    RAISE NOTICE '';
    RAISE NOTICE '🚀 이제 관리자 보안 테스트가 완벽하게 작동할 것입니다!';
    RAISE NOTICE '=====================================';
END;
$$;