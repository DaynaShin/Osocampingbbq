-- 예약 테이블 스키마 수정 및 함수 업데이트
-- 작성일: 2025-09-06
-- 목표: reservation_time 컬럼 추가 및 함수와 테이블 구조 일치

-- =======================================================
-- 1단계: 테이블 구조 확인 및 누락된 컬럼 추가
-- =======================================================

-- reservation_time 컬럼이 없다면 추가
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'reservations' 
    AND column_name = 'reservation_time'
  ) THEN
    ALTER TABLE reservations ADD COLUMN reservation_time TIME;
    RAISE NOTICE 'reservation_time 컬럼이 추가되었습니다.';
  ELSE
    RAISE NOTICE 'reservation_time 컬럼이 이미 존재합니다.';
  END IF;
END;
$$;

-- guest_count 컬럼이 없다면 추가
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'reservations' 
    AND column_name = 'guest_count'
  ) THEN
    ALTER TABLE reservations ADD COLUMN guest_count INTEGER DEFAULT 1;
    RAISE NOTICE 'guest_count 컬럼이 추가되었습니다.';
  ELSE
    RAISE NOTICE 'guest_count 컬럼이 이미 존재합니다.';
  END IF;
END;
$$;

-- reservation_number 컬럼이 없다면 추가
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'reservations' 
    AND column_name = 'reservation_number'
  ) THEN
    ALTER TABLE reservations ADD COLUMN reservation_number TEXT UNIQUE;
    CREATE INDEX IF NOT EXISTS idx_reservations_number ON reservations(reservation_number);
    RAISE NOTICE 'reservation_number 컬럼이 추가되었습니다.';
  ELSE
    RAISE NOTICE 'reservation_number 컬럼이 이미 존재합니다.';
  END IF;
END;
$$;

-- =======================================================
-- 2단계: 수정된 예약 생성 함수 (스키마 매칭)
-- =======================================================

-- 기존 함수 삭제
DROP FUNCTION IF EXISTS create_reservation_atomic(TEXT, TEXT, TEXT, DATE, TIME, INTEGER, TEXT, TEXT);
DROP FUNCTION IF EXISTS create_reservation_atomic(TEXT, TEXT, DATE, TIME, TEXT, INTEGER, TEXT, TEXT);

-- 올바른 컬럼명으로 함수 생성
CREATE OR REPLACE FUNCTION create_reservation_atomic(
  p_name TEXT,
  p_phone TEXT,
  p_reservation_date DATE,
  p_reservation_time TIME,
  p_email TEXT DEFAULT NULL,
  p_guest_count INTEGER DEFAULT 1,
  p_service_type TEXT DEFAULT NULL,
  p_message TEXT DEFAULT NULL
) RETURNS TABLE(
  success BOOLEAN, 
  reservation_id TEXT,  -- UUID를 TEXT로 반환
  error_msg TEXT,
  reservation_number TEXT
)
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
DECLARE
  v_reservation_id TEXT;  -- UUID 타입
  v_reservation_number TEXT;
BEGIN
  -- 1. 예약번호 생성 (OSO-YYMMDD-XXXX 형식)
  v_reservation_number := 'OSO-' || to_char(p_reservation_date, 'YYMMDD') || '-' || 
                         LPAD((EXTRACT(epoch FROM NOW())::INTEGER % 10000)::TEXT, 4, '0');
  
  -- 2. 예약 생성 (실제 테이블 구조에 맞춘 컬럼명)
  INSERT INTO reservations (
    name, phone, email, 
    reservation_date, reservation_time, 
    guest_count, service_type, message, status, reservation_number
  )
  VALUES (
    p_name, p_phone, p_email, p_reservation_date, p_reservation_time,
    p_guest_count, p_service_type, p_message, 'pending', v_reservation_number
  )
  RETURNING id::TEXT INTO v_reservation_id;  -- UUID를 TEXT로 캐스팅
  
  -- 3. 성공 반환
  RETURN QUERY SELECT 
    true, 
    v_reservation_id, 
    NULL::TEXT,
    v_reservation_number;
  
EXCEPTION
  WHEN unique_violation THEN
    RETURN QUERY SELECT 
      false, 
      NULL::TEXT,
      '이미 동일한 정보로 예약이 존재합니다.',
      NULL::TEXT;
  WHEN OTHERS THEN
    RETURN QUERY SELECT 
      false, 
      NULL::TEXT,
      '예약 생성 중 오류 발생: ' || SQLERRM,
      NULL::TEXT;
END;
$$;

-- =======================================================
-- 3단계: 권한 설정 및 인덱스 추가
-- =======================================================

-- 함수 권한 설정
GRANT EXECUTE ON FUNCTION create_reservation_atomic TO anon;
GRANT EXECUTE ON FUNCTION create_reservation_atomic TO authenticated;

-- 필요한 인덱스 추가
CREATE INDEX IF NOT EXISTS idx_reservations_time ON reservations(reservation_time);
CREATE INDEX IF NOT EXISTS idx_reservations_date_time ON reservations(reservation_date, reservation_time);

-- =======================================================
-- 4단계: 테이블 현재 구조 확인 (검증용)
-- =======================================================

-- 현재 reservations 테이블 구조를 확인하는 쿼리 (실행 후 결과 확인)
SELECT 
    column_name, 
    data_type, 
    is_nullable, 
    column_default
FROM information_schema.columns 
WHERE table_name = 'reservations' 
  AND table_schema = 'public'
ORDER BY ordinal_position;

COMMENT ON FUNCTION create_reservation_atomic IS '스키마 매칭된 예약 생성 함수 (P1 테스트용)';