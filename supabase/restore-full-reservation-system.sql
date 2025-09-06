-- 완전한 예약 시스템 복구 가이드
-- 작성일: 2025-09-06
-- 목표: P1 테스트 완료 후 완전한 동시성 제어 예약 시스템으로 복구

-- =======================================================
-- 1단계: availability 테이블 생성 및 초기 데이터 설정
-- =======================================================

-- availability 테이블 생성 (시간대별 예약 가능 슬롯 관리)
CREATE TABLE IF NOT EXISTS availability (
  id SERIAL PRIMARY KEY,
  date DATE NOT NULL,
  time_slot TIME NOT NULL,
  total_slots INTEGER NOT NULL DEFAULT 10,
  remaining_slots INTEGER NOT NULL DEFAULT 10,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(date, time_slot)
);

-- availability 테이블 인덱스
CREATE INDEX IF NOT EXISTS idx_availability_date_time ON availability(date, time_slot);
CREATE INDEX IF NOT EXISTS idx_availability_date ON availability(date);

-- availability 테이블 RLS 설정
ALTER TABLE availability ENABLE ROW LEVEL SECURITY;

-- 모든 사용자가 읽기 가능
DROP POLICY IF EXISTS "Anyone can read availability" ON availability;
CREATE POLICY "Anyone can read availability" ON availability
  FOR SELECT USING (true);

-- 인증된 사용자만 수정 가능
DROP POLICY IF EXISTS "Authenticated users can update availability" ON availability;
CREATE POLICY "Authenticated users can update availability" ON availability
  FOR UPDATE USING (auth.role() = 'authenticated');

-- 서비스 역할만 삽입 가능
DROP POLICY IF EXISTS "Service role can insert availability" ON availability;
CREATE POLICY "Service role can insert availability" ON availability
  FOR INSERT WITH CHECK (auth.role() = 'service_role');

-- =======================================================
-- 2단계: 기본 시간대 슬롯 초기화
-- =======================================================

-- 다음 30일간의 기본 시간대 슬롯 생성 (10:00~18:00, 1시간 단위)
DO $$
DECLARE
  current_date DATE := CURRENT_DATE;
  end_date DATE := CURRENT_DATE + INTERVAL '30 days';
  time_slots TIME[] := ARRAY['10:00'::TIME, '11:00'::TIME, '12:00'::TIME, '13:00'::TIME, 
                            '14:00'::TIME, '15:00'::TIME, '16:00'::TIME, '17:00'::TIME, '18:00'::TIME];
  slot TIME;
BEGIN
  WHILE current_date <= end_date LOOP
    FOREACH slot IN ARRAY time_slots LOOP
      INSERT INTO availability (date, time_slot, total_slots, remaining_slots)
      VALUES (current_date, slot, 10, 10)
      ON CONFLICT (date, time_slot) DO NOTHING;
    END LOOP;
    current_date := current_date + INTERVAL '1 day';
  END LOOP;
END;
$$;

-- =======================================================
-- 3단계: 완전한 원자적 예약 생성 함수 복구
-- =======================================================

-- 기존 단순 함수 삭제
DROP FUNCTION IF EXISTS create_reservation_atomic(TEXT, TEXT, TEXT, DATE, TIME, INTEGER, TEXT, TEXT);

-- 완전한 원자적 예약 생성 함수 (동시성 제어 포함)
CREATE OR REPLACE FUNCTION create_reservation_atomic(
  p_name TEXT,
  p_phone TEXT,
  p_email TEXT DEFAULT NULL,
  p_reservation_date DATE,
  p_reservation_time TIME,
  p_guest_count INTEGER DEFAULT 1,
  p_service_type TEXT DEFAULT NULL,
  p_message TEXT DEFAULT NULL
) RETURNS TABLE(
  success BOOLEAN, 
  reservation_id INTEGER, 
  error_msg TEXT,
  reservation_number TEXT
)
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
DECLARE
  v_reservation_id INTEGER;
  v_available_count INTEGER;
  v_reservation_number TEXT;
BEGIN
  -- 트랜잭션 격리 수준을 SERIALIZABLE로 설정 (최고 수준)
  SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
  
  -- 1. 선택한 슬롯의 가용성 확인 (FOR UPDATE로 락)
  SELECT remaining_slots INTO v_available_count
  FROM availability 
  WHERE date = p_reservation_date 
    AND time_slot = p_reservation_time
  FOR UPDATE;
  
  -- 2. availability 테이블에 해당 슬롯이 없으면 기본값으로 초기화
  IF v_available_count IS NULL THEN
    -- 기본 슬롯 수를 10으로 가정하고 초기화
    INSERT INTO availability (date, time_slot, total_slots, remaining_slots)
    VALUES (p_reservation_date, p_reservation_time, 10, 9)
    ON CONFLICT (date, time_slot) DO UPDATE
    SET remaining_slots = availability.remaining_slots - 1
    WHERE availability.remaining_slots > 0;
    
    v_available_count := 9;
  ELSIF v_available_count <= 0 THEN
    -- 3. 슬롯이 없으면 오류 반환
    RETURN QUERY SELECT 
      false, 
      0, 
      '선택한 시간대에 예약 가능한 슬롯이 없습니다. 다른 시간을 선택해주세요.',
      NULL::TEXT;
    RETURN;
  END IF;
  
  -- 4. 예약번호 생성 (OSO-YYMMDD-XXXX 형식)
  v_reservation_number := 'OSO-' || to_char(p_reservation_date, 'YYMMDD') || '-' || 
                         LPAD(EXTRACT(epoch FROM NOW())::INTEGER % 10000, 4, '0');
  
  -- 5. 예약 생성 (올바른 컬럼명 사용)
  INSERT INTO reservations (
    name, phone, email, reservation_date, reservation_time, 
    guest_count, service_type, message, status, reservation_number
  )
  VALUES (
    p_name, p_phone, p_email, p_reservation_date, p_reservation_time,
    p_guest_count, p_service_type, p_message, 'confirmed', v_reservation_number
  )
  RETURNING id INTO v_reservation_id;
  
  -- 6. 가용성 차감
  UPDATE availability 
  SET remaining_slots = remaining_slots - 1,
      updated_at = NOW()
  WHERE date = p_reservation_date 
    AND time_slot = p_reservation_time;
  
  -- 7. 성공 반환
  RETURN QUERY SELECT 
    true, 
    v_reservation_id, 
    NULL::TEXT,
    v_reservation_number;
  
EXCEPTION
  WHEN serialization_failure THEN
    RETURN QUERY SELECT 
      false, 
      0, 
      '동시 예약으로 인한 충돌이 발생했습니다. 잠시 후 다시 시도해주세요.',
      NULL::TEXT;
  WHEN unique_violation THEN
    RETURN QUERY SELECT 
      false, 
      0, 
      '이미 동일한 정보로 예약이 존재합니다.',
      NULL::TEXT;
  WHEN OTHERS THEN
    RETURN QUERY SELECT 
      false, 
      0, 
      '예약 처리 중 오류가 발생했습니다: ' || SQLERRM,
      NULL::TEXT;
END;
$$;

-- =======================================================
-- 4단계: 예약 취소/삭제 시 슬롯 복구 함수
-- =======================================================

-- 예약 취소 시 슬롯 복구 함수
CREATE OR REPLACE FUNCTION restore_availability_slot(
  p_reservation_date DATE,
  p_reservation_time TIME
) RETURNS BOOLEAN
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
BEGIN
  -- availability 슬롯 1개 복구
  UPDATE availability 
  SET remaining_slots = remaining_slots + 1,
      updated_at = NOW()
  WHERE date = p_reservation_date 
    AND time_slot = p_reservation_time
    AND remaining_slots < total_slots;
    
  -- 해당 슬롯이 없으면 생성
  IF NOT FOUND THEN
    INSERT INTO availability (date, time_slot, total_slots, remaining_slots)
    VALUES (p_reservation_date, p_reservation_time, 10, 10)
    ON CONFLICT (date, time_slot) DO NOTHING;
  END IF;
  
  RETURN TRUE;
EXCEPTION
  WHEN OTHERS THEN
    RETURN FALSE;
END;
$$;

-- =======================================================
-- 5단계: 권한 설정
-- =======================================================

-- 함수 실행 권한 부여
GRANT EXECUTE ON FUNCTION create_reservation_atomic TO anon;
GRANT EXECUTE ON FUNCTION create_reservation_atomic TO authenticated;
GRANT EXECUTE ON FUNCTION restore_availability_slot TO authenticated;

-- =======================================================
-- 6단계: 기존 예약 데이터 마이그레이션 (선택적)
-- =======================================================

-- 기존 예약이 있다면 해당 슬롯의 가용성 차감
DO $$
DECLARE
  reservation_record RECORD;
BEGIN
  -- 기존 예약들을 순회하며 availability 차감
  FOR reservation_record IN 
    SELECT DISTINCT reservation_date, reservation_time 
    FROM reservations 
    WHERE status IN ('confirmed', 'pending')
      AND reservation_date >= CURRENT_DATE
  LOOP
    -- 해당 슬롯의 가용성을 1 차감
    UPDATE availability 
    SET remaining_slots = GREATEST(remaining_slots - 1, 0),
        updated_at = NOW()
    WHERE date = reservation_record.reservation_date 
      AND time_slot = reservation_record.reservation_time;
  END LOOP;
END;
$$;

-- =======================================================
-- 7단계: 검증 쿼리 (실행 후 확인용)
-- =======================================================

-- 1) availability 테이블 상태 확인
-- SELECT * FROM availability WHERE date >= CURRENT_DATE ORDER BY date, time_slot LIMIT 20;

-- 2) 예약 가능한 슬롯 조회
-- SELECT date, time_slot, remaining_slots FROM availability 
-- WHERE date >= CURRENT_DATE AND remaining_slots > 0 
-- ORDER BY date, time_slot LIMIT 10;

-- 3) 함수 테스트
-- SELECT * FROM create_reservation_atomic(
--   '테스트고객', '010-1234-5678', 'test@example.com',
--   CURRENT_DATE + 1, '14:00'::TIME, 2, 'camping', '테스트 예약'
-- );

COMMENT ON FUNCTION create_reservation_atomic IS '완전한 동시성 제어가 있는 예약 생성 함수 (복구된 버전)';
COMMENT ON FUNCTION restore_availability_slot IS '예약 취소/삭제 시 가용 슬롯 복구 함수';
COMMENT ON TABLE availability IS '시간대별 예약 가능 슬롯 관리 테이블';