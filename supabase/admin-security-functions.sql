-- 관리자 보안 함수 시스템
-- 작성일: 2025-09-06
-- 목표: RLS 정책과 충돌하지 않는 안전한 관리자 기능 구현

-- ==============================================
-- 1. 관리자 권한 확인 헬퍼 함수
-- ==============================================

CREATE OR REPLACE FUNCTION get_admin_permissions(admin_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  admin_perms JSONB;
BEGIN
  SELECT permissions INTO admin_perms
  FROM admin_profiles 
  WHERE id = admin_user_id 
    AND is_active = true;
  
  RETURN COALESCE(admin_perms, '{}'::jsonb);
END;
$$;

-- ==============================================
-- 2. 관리자 예약 승인/확정 함수
-- ==============================================

CREATE OR REPLACE FUNCTION admin_confirm_reservation(
  p_reservation_id INTEGER,
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
  v_admin_id UUID;
  v_permissions JSONB;
  v_reservation RECORD;
BEGIN
  -- 현재 사용자가 관리자인지 확인
  v_admin_id := auth.uid();
  
  IF v_admin_id IS NULL THEN
    RETURN QUERY SELECT false, '인증되지 않은 사용자입니다.', NULL::JSONB;
    RETURN;
  END IF;
  
  -- 관리자 권한 확인
  v_permissions := get_admin_permissions(v_admin_id);
  
  IF NOT (v_permissions->'reservations'->>'write')::boolean THEN
    RETURN QUERY SELECT false, '예약 수정 권한이 없습니다.', NULL::JSONB;
    RETURN;
  END IF;
  
  -- 예약 존재 확인
  SELECT * INTO v_reservation 
  FROM reservations 
  WHERE id = p_reservation_id;
  
  IF NOT FOUND THEN
    RETURN QUERY SELECT false, '존재하지 않는 예약입니다.', NULL::JSONB;
    RETURN;
  END IF;
  
  -- 예약 상태 업데이트
  UPDATE reservations 
  SET 
    status = 'confirmed',
    updated_at = NOW(),
    admin_notes = COALESCE(p_admin_notes, admin_notes)
  WHERE id = p_reservation_id;
  
  -- 업데이트된 예약 정보 반환
  SELECT row_to_json(r.*) INTO v_reservation
  FROM reservations r 
  WHERE r.id = p_reservation_id;
  
  -- 관리자 활동 로그 기록 (옵션)
  INSERT INTO admin_activity_log (
    admin_id, action, target_type, target_id, details, created_at
  ) VALUES (
    v_admin_id, 'confirm_reservation', 'reservation', p_reservation_id,
    jsonb_build_object('notes', p_admin_notes), NOW()
  );
  
  RETURN QUERY SELECT 
    true, 
    NULL::TEXT, 
    to_jsonb(v_reservation);
    
EXCEPTION
  WHEN OTHERS THEN
    RETURN QUERY SELECT 
      false, 
      '예약 승인 처리 중 오류 발생: ' || SQLERRM, 
      NULL::JSONB;
END;
$$;

-- ==============================================
-- 3. 관리자 예약 취소 함수
-- ==============================================

CREATE OR REPLACE FUNCTION admin_cancel_reservation(
  p_reservation_id INTEGER,
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
  v_admin_id UUID;
  v_permissions JSONB;
  v_reservation RECORD;
BEGIN
  -- 현재 사용자가 관리자인지 확인
  v_admin_id := auth.uid();
  
  IF v_admin_id IS NULL THEN
    RETURN QUERY SELECT false, '인증되지 않은 사용자입니다.', NULL::JSONB;
    RETURN;
  END IF;
  
  -- 관리자 권한 확인
  v_permissions := get_admin_permissions(v_admin_id);
  
  IF NOT (v_permissions->'reservations'->>'write')::boolean THEN
    RETURN QUERY SELECT false, '예약 수정 권한이 없습니다.', NULL::JSONB;
    RETURN;
  END IF;
  
  -- 예약 존재 확인
  SELECT * INTO v_reservation 
  FROM reservations 
  WHERE id = p_reservation_id;
  
  IF NOT FOUND THEN
    RETURN QUERY SELECT false, '존재하지 않는 예약입니다.', NULL::JSONB;
    RETURN;
  END IF;
  
  -- 예약 상태 업데이트
  UPDATE reservations 
  SET 
    status = 'cancelled',
    updated_at = NOW(),
    cancellation_reason = p_cancellation_reason,
    admin_notes = COALESCE(p_admin_notes, admin_notes)
  WHERE id = p_reservation_id;
  
  -- 가용성 복구 (해당 슬롯의 available_slots 증가)
  UPDATE availability 
  SET remaining_slots = remaining_slots + 1,
      updated_at = NOW()
  WHERE date = v_reservation.reservation_date 
    AND time_slot = v_reservation.reservation_time;
  
  -- 업데이트된 예약 정보 반환
  SELECT row_to_json(r.*) INTO v_reservation
  FROM reservations r 
  WHERE r.id = p_reservation_id;
  
  -- 관리자 활동 로그 기록
  INSERT INTO admin_activity_log (
    admin_id, action, target_type, target_id, details, created_at
  ) VALUES (
    v_admin_id, 'cancel_reservation', 'reservation', p_reservation_id,
    jsonb_build_object(
      'reason', p_cancellation_reason,
      'notes', p_admin_notes
    ), NOW()
  );
  
  RETURN QUERY SELECT 
    true, 
    NULL::TEXT, 
    to_jsonb(v_reservation);
    
EXCEPTION
  WHEN OTHERS THEN
    RETURN QUERY SELECT 
      false, 
      '예약 취소 처리 중 오류 발생: ' || SQLERRM, 
      NULL::JSONB;
END;
$$;

-- ==============================================
-- 4. 관리자 예약 삭제 함수 (하드 삭제)
-- ==============================================

CREATE OR REPLACE FUNCTION admin_delete_reservation(
  p_reservation_id INTEGER,
  p_deletion_reason TEXT DEFAULT NULL
) RETURNS TABLE(
  success BOOLEAN, 
  error_msg TEXT
)
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
DECLARE
  v_admin_id UUID;
  v_permissions JSONB;
  v_reservation RECORD;
BEGIN
  -- 현재 사용자가 관리자인지 확인
  v_admin_id := auth.uid();
  
  IF v_admin_id IS NULL THEN
    RETURN QUERY SELECT false, '인증되지 않은 사용자입니다.';
    RETURN;
  END IF;
  
  -- 관리자 권한 확인 (삭제 권한은 더 높은 권한 필요)
  v_permissions := get_admin_permissions(v_admin_id);
  
  IF NOT (v_permissions->'reservations'->>'delete')::boolean THEN
    RETURN QUERY SELECT false, '예약 삭제 권한이 없습니다.';
    RETURN;
  END IF;
  
  -- 예약 정보 백업 (삭제 전)
  SELECT * INTO v_reservation 
  FROM reservations 
  WHERE id = p_reservation_id;
  
  IF NOT FOUND THEN
    RETURN QUERY SELECT false, '존재하지 않는 예약입니다.';
    RETURN;
  END IF;
  
  -- 관리자 활동 로그 기록 (삭제 전에)
  INSERT INTO admin_activity_log (
    admin_id, action, target_type, target_id, details, created_at
  ) VALUES (
    v_admin_id, 'delete_reservation', 'reservation', p_reservation_id,
    jsonb_build_object(
      'reason', p_deletion_reason,
      'deleted_reservation_data', row_to_json(v_reservation)
    ), NOW()
  );
  
  -- 가용성 복구
  UPDATE availability 
  SET remaining_slots = remaining_slots + 1,
      updated_at = NOW()
  WHERE date = v_reservation.reservation_date 
    AND time_slot = v_reservation.reservation_time;
  
  -- 예약 삭제
  DELETE FROM reservations WHERE id = p_reservation_id;
  
  RETURN QUERY SELECT true, NULL::TEXT;
    
EXCEPTION
  WHEN OTHERS THEN
    RETURN QUERY SELECT false, '예약 삭제 처리 중 오류 발생: ' || SQLERRM;
END;
$$;

-- ==============================================
-- 5. 관리자 활동 로그 테이블 (없다면 생성)
-- ==============================================

CREATE TABLE IF NOT EXISTS admin_activity_log (
  id SERIAL PRIMARY KEY,
  admin_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  action TEXT NOT NULL, -- 'confirm_reservation', 'cancel_reservation', 'delete_reservation', etc.
  target_type TEXT NOT NULL, -- 'reservation', 'booking', 'availability', etc.
  target_id INTEGER, -- 대상 레코드 ID
  details JSONB, -- 추가 정보 (이유, 메모 등)
  created_at TIMESTAMPTZ DEFAULT NOW(),
  ip_address INET,
  user_agent TEXT
);

-- 인덱스 생성
CREATE INDEX IF NOT EXISTS idx_admin_activity_log_admin_id ON admin_activity_log(admin_id);
CREATE INDEX IF NOT EXISTS idx_admin_activity_log_created_at ON admin_activity_log(created_at);
CREATE INDEX IF NOT EXISTS idx_admin_activity_log_action ON admin_activity_log(action);

-- RLS 정책 설정
ALTER TABLE admin_activity_log ENABLE ROW LEVEL SECURITY;

-- 관리자만 자신의 로그를 볼 수 있음
CREATE POLICY "Admins can view their own activity logs" ON admin_activity_log
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM admin_profiles 
      WHERE id = auth.uid() AND is_active = true
    )
  );

-- ==============================================
-- 6. 예약에 컬럼 추가 (없다면)
-- ==============================================

-- 취소 사유 컬럼 추가
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'reservations' 
    AND column_name = 'cancellation_reason'
  ) THEN
    ALTER TABLE reservations ADD COLUMN cancellation_reason TEXT;
  END IF;
END;
$$;

-- 관리자 메모 컬럼 추가
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'reservations' 
    AND column_name = 'admin_notes'
  ) THEN
    ALTER TABLE reservations ADD COLUMN admin_notes TEXT;
  END IF;
END;
$$;

-- 함수 주석 추가
COMMENT ON FUNCTION admin_confirm_reservation IS '관리자 전용 예약 승인 함수 (RLS 정책 우회)';
COMMENT ON FUNCTION admin_cancel_reservation IS '관리자 전용 예약 취소 함수 (RLS 정책 우회)';
COMMENT ON FUNCTION admin_delete_reservation IS '관리자 전용 예약 삭제 함수 (RLS 정책 우회)';
COMMENT ON FUNCTION get_admin_permissions IS '관리자 권한 조회 헬퍼 함수';