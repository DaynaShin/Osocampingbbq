-- 원자적 예약 시스템 구현
-- 작성일: 2025-09-06
-- 목표: 동시성 제어가 있는 안전한 예약 생성 시스템

-- 1. 원자적 예약 생성 함수
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
  
  -- 5. 예약 생성
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

-- 2. 예약번호 컬럼이 없다면 추가 (안전한 방식)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'reservations' 
    AND column_name = 'reservation_number'
  ) THEN
    ALTER TABLE reservations ADD COLUMN reservation_number TEXT UNIQUE;
    CREATE INDEX IF NOT EXISTS idx_reservations_number ON reservations(reservation_number);
  END IF;
END;
$$;

-- 3. availability 테이블이 없다면 생성
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

-- 4. RLS 정책 설정
ALTER TABLE availability ENABLE ROW LEVEL SECURITY;

-- 모든 사용자가 읽기 가능
CREATE POLICY "Anyone can read availability" ON availability
  FOR SELECT USING (true);

-- 인증된 사용자만 수정 가능 (함수를 통해서만)
CREATE POLICY "Authenticated users can update availability" ON availability
  FOR UPDATE USING (auth.role() = 'authenticated');

-- 서비스 역할만 삽입 가능
CREATE POLICY "Service role can insert availability" ON availability
  FOR INSERT WITH CHECK (auth.role() = 'service_role');

COMMENT ON FUNCTION create_reservation_atomic IS '동시성 제어가 있는 안전한 예약 생성 함수';