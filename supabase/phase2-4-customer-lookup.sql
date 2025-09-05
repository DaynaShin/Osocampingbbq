-- Phase 2.4: 하이브리드 예약자 조회 시스템 구현
-- 작성일: 2025년
-- 목표: 간단 조회(예약번호+전화번호) + 선택적 고객 계정 시스템

-- 1. 예약번호 생성을 위한 시퀀스 및 함수
CREATE SEQUENCE IF NOT EXISTS reservation_number_seq 
  START WITH 1001 
  INCREMENT BY 1;

-- 예약번호 생성 함수 (OSO-YYMMDD-A001 형식)
CREATE OR REPLACE FUNCTION generate_reservation_number()
RETURNS TEXT AS $$
DECLARE
  seq_num INTEGER;
  date_part TEXT;
  alpha_part CHAR(1);
  number_part TEXT;
  result TEXT;
BEGIN
  -- 시퀀스 다음 값 가져오기
  seq_num := nextval('reservation_number_seq');
  
  -- 날짜 부분 (YYMMDD)
  date_part := to_char(CURRENT_DATE, 'YYMMDD');
  
  -- 알파벳 부분 (A~Z 순환)
  alpha_part := chr(65 + ((seq_num - 1001) / 1000) % 26);
  
  -- 숫자 부분 (001~999)
  number_part := lpad(((seq_num - 1001) % 1000 + 1)::text, 3, '0');
  
  result := 'OSO-' || date_part || '-' || alpha_part || number_part;
  
  RETURN result;
END;
$$ LANGUAGE plpgsql;

-- 2. reservations 테이블에 예약번호 컬럼 추가
ALTER TABLE reservations 
  ADD COLUMN IF NOT EXISTS reservation_number TEXT UNIQUE;

-- 3. 기존 예약들에 예약번호 부여
UPDATE reservations 
SET reservation_number = generate_reservation_number()
WHERE reservation_number IS NULL;

-- 4. 예약번호 자동 생성 트리거
CREATE OR REPLACE FUNCTION set_reservation_number()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.reservation_number IS NULL THEN
    NEW.reservation_number := generate_reservation_number();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_set_reservation_number
  BEFORE INSERT ON reservations
  FOR EACH ROW
  EXECUTE FUNCTION set_reservation_number();

-- 5. 고객 프로필 테이블 (선택적 계정)
CREATE TABLE IF NOT EXISTS customer_profiles (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  phone TEXT NOT NULL UNIQUE,
  email TEXT,
  name TEXT NOT NULL,
  password_hash TEXT, -- NULL이면 계정 없음 (간단 조회만)
  is_verified BOOLEAN DEFAULT false,
  preferences JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  last_login_at TIMESTAMPTZ
);

-- 6. 예약과 고객 프로필 연결
ALTER TABLE reservations 
  ADD COLUMN IF NOT EXISTS customer_profile_id UUID REFERENCES customer_profiles(id);

-- 기존 예약들에 고객 프로필 자동 생성 (비밀번호 없음)
INSERT INTO customer_profiles (phone, email, name)
SELECT DISTINCT phone, email, name
FROM reservations r
WHERE NOT EXISTS (
  SELECT 1 FROM customer_profiles cp 
  WHERE cp.phone = r.phone
)
ON CONFLICT (phone) DO NOTHING;

-- 기존 예약들과 고객 프로필 연결
UPDATE reservations 
SET customer_profile_id = cp.id
FROM customer_profiles cp
WHERE reservations.phone = cp.phone 
  AND reservations.customer_profile_id IS NULL;

-- 7. 예약 조회 함수 (예약번호 + 전화번호)
CREATE OR REPLACE FUNCTION lookup_reservation_simple(
  p_reservation_number TEXT,
  p_phone TEXT
)
RETURNS TABLE(
  reservation_id INTEGER,
  reservation_number TEXT,
  customer_name TEXT,
  customer_phone TEXT,
  customer_email TEXT,
  reservation_date DATE,
  guest_count INTEGER,
  status TEXT,
  facility_name TEXT,
  time_slot TEXT,
  total_amount INTEGER,
  special_requests TEXT,
  created_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    r.id,
    r.reservation_number,
    r.name,
    r.phone,
    r.email,
    r.reservation_date,
    r.guest_count,
    r.status,
    rc.display_name as facility_name,
    tc.display_name as time_slot,
    COALESCE(r.total_amount, rc.price) as total_amount,
    r.special_requests,
    r.created_at
  FROM reservations r
  LEFT JOIN sku_catalog sc ON r.sku_code = sc.sku_code
  LEFT JOIN resource_catalog rc ON sc.resource_code = rc.internal_code
  LEFT JOIN time_slot_catalog tc ON sc.time_slot_code = tc.slot_code
  WHERE r.reservation_number = p_reservation_number 
    AND r.phone = p_phone;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- 8. 고객 계정 생성 함수
CREATE OR REPLACE FUNCTION create_customer_account(
  p_phone TEXT,
  p_password TEXT,
  p_email TEXT DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
  customer_id UUID;
  result JSON;
BEGIN
  -- 기존 프로필 확인
  SELECT id INTO customer_id 
  FROM customer_profiles 
  WHERE phone = p_phone;
  
  IF customer_id IS NULL THEN
    -- 새 고객 프로필 생성
    INSERT INTO customer_profiles (phone, email, password_hash)
    VALUES (p_phone, p_email, crypt(p_password, gen_salt('bf')))
    RETURNING id INTO customer_id;
    
    result := json_build_object(
      'success', true,
      'message', '계정이 생성되었습니다.',
      'customer_id', customer_id
    );
  ELSE
    -- 기존 프로필에 비밀번호 설정
    UPDATE customer_profiles 
    SET 
      password_hash = crypt(p_password, gen_salt('bf')),
      email = COALESCE(p_email, email),
      updated_at = NOW()
    WHERE id = customer_id;
    
    result := json_build_object(
      'success', true,
      'message', '계정 설정이 완료되었습니다.',
      'customer_id', customer_id
    );
  END IF;
  
  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 9. 고객 로그인 함수
CREATE OR REPLACE FUNCTION customer_login(
  p_phone TEXT,
  p_password TEXT
)
RETURNS JSON AS $$
DECLARE
  customer_record customer_profiles%ROWTYPE;
  result JSON;
BEGIN
  SELECT * INTO customer_record
  FROM customer_profiles
  WHERE phone = p_phone 
    AND password_hash IS NOT NULL
    AND password_hash = crypt(p_password, password_hash);
  
  IF customer_record.id IS NULL THEN
    result := json_build_object(
      'success', false,
      'message', '전화번호 또는 비밀번호가 올바르지 않습니다.'
    );
  ELSE
    -- 로그인 시간 업데이트
    UPDATE customer_profiles 
    SET last_login_at = NOW()
    WHERE id = customer_record.id;
    
    result := json_build_object(
      'success', true,
      'customer', json_build_object(
        'id', customer_record.id,
        'name', customer_record.name,
        'phone', customer_record.phone,
        'email', customer_record.email
      )
    );
  END IF;
  
  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 10. 고객의 모든 예약 조회 함수
CREATE OR REPLACE FUNCTION get_customer_reservations(p_customer_id UUID)
RETURNS TABLE(
  reservation_id INTEGER,
  reservation_number TEXT,
  reservation_date DATE,
  guest_count INTEGER,
  status TEXT,
  facility_name TEXT,
  time_slot TEXT,
  total_amount INTEGER,
  special_requests TEXT,
  created_at TIMESTAMPTZ,
  can_modify BOOLEAN
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    r.id,
    r.reservation_number,
    r.reservation_date,
    r.guest_count,
    r.status,
    rc.display_name as facility_name,
    tc.display_name as time_slot,
    COALESCE(r.total_amount, rc.price) as total_amount,
    r.special_requests,
    r.created_at,
    (r.reservation_date > CURRENT_DATE + INTERVAL '1 day' AND r.status = 'pending') as can_modify
  FROM reservations r
  LEFT JOIN sku_catalog sc ON r.sku_code = sc.sku_code
  LEFT JOIN resource_catalog rc ON sc.resource_code = rc.internal_code  
  LEFT JOIN time_slot_catalog tc ON sc.time_slot_code = tc.slot_code
  WHERE r.customer_profile_id = p_customer_id
  ORDER BY r.created_at DESC;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- 11. 인덱스 추가 (성능 최적화)
CREATE INDEX IF NOT EXISTS idx_reservations_number ON reservations(reservation_number);
CREATE INDEX IF NOT EXISTS idx_reservations_phone ON reservations(phone);
CREATE INDEX IF NOT EXISTS idx_reservations_customer_profile ON reservations(customer_profile_id);
CREATE INDEX IF NOT EXISTS idx_customer_profiles_phone ON customer_profiles(phone);

-- 12. 예약번호 중복 방지를 위한 제약조건
ALTER TABLE reservations 
  ADD CONSTRAINT unique_reservation_number UNIQUE (reservation_number);

-- 13. 테스트 쿼리
-- 예약번호 생성 테스트
SELECT generate_reservation_number() as sample_reservation_number;

-- 간단 조회 테스트 (실제 데이터로 테스트 필요)
-- SELECT * FROM lookup_reservation_simple('OSO-250905-A001', '010-1234-5678');

-- 14. 예약 완료 알림을 위한 뷰
CREATE OR REPLACE VIEW reservation_complete_info AS
SELECT 
  r.id,
  r.reservation_number,
  r.name as customer_name,
  r.phone,
  r.email,
  r.reservation_date,
  rc.display_name as facility_name,
  tc.display_name as time_slot,
  formatTimeSlot(tc.start_local, tc.end_local) as time_range,
  r.guest_count,
  COALESCE(r.total_amount, rc.price) as amount,
  r.special_requests,
  '예약이 접수되었습니다. 예약번호: ' || r.reservation_number || 
  ' (전화번호와 함께 예약 조회 시 필요)' as completion_message
FROM reservations r
LEFT JOIN sku_catalog sc ON r.sku_code = sc.sku_code  
LEFT JOIN resource_catalog rc ON sc.resource_code = rc.internal_code
LEFT JOIN time_slot_catalog tc ON sc.time_slot_code = tc.slot_code;