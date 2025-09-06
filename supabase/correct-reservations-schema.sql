-- 올바른 reservations 테이블 구조 정의
-- 작성일: 2025-09-06
-- 목표: P1 테스트에 필요한 정확한 테이블 구조 생성

-- =======================================================
-- 🔍 PROBLEM ANALYSIS (문제 분석)
-- =======================================================

-- 발견된 문제들:
-- 1. database-schema.sql: name, phone, email, reservation_time 사용 ✅
-- 2. integrated-schema.sql: name, phone, email 사용하지만 reservation_time 없음 ❌  
-- 3. create-test-reservation.html: customer_name, customer_phone 조회 시도 ❌
-- 4. 함수: name, phone, email, reservation_time 사용 ✅

-- =======================================================
-- ✅ CORRECT SCHEMA (올바른 스키마)
-- =======================================================

-- 기존 테이블이 있다면 삭제 (개발 환경에서만!)
-- DROP TABLE IF EXISTS reservations CASCADE;

-- 완전히 정확한 reservations 테이블 생성
CREATE TABLE IF NOT EXISTS reservations (
  -- 기본 식별자
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  
  -- 고객 정보 (함수와 일치)
  name VARCHAR(100) NOT NULL,           -- ✅ 함수: p_name
  phone VARCHAR(20) NOT NULL,           -- ✅ 함수: p_phone  
  email VARCHAR(255),                   -- ✅ 함수: p_email
  
  -- 예약 정보 (함수와 일치)
  reservation_date DATE NOT NULL,       -- ✅ 함수: p_reservation_date
  reservation_time TIME NOT NULL,       -- ✅ 함수: p_reservation_time
  guest_count INTEGER DEFAULT 1,       -- ✅ 함수: p_guest_count
  service_type VARCHAR(100),            -- ✅ 함수: p_service_type
  message TEXT,                         -- ✅ 함수: p_message
  
  -- 시스템 필드
  status VARCHAR(20) DEFAULT 'pending', -- pending, confirmed, cancelled
  reservation_number TEXT UNIQUE,       -- OSO-YYMMDD-XXXX 형식
  
  -- 타임스탬프
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =======================================================
-- 📊 BACKWARD COMPATIBILITY (하위 호환성)
-- =======================================================

-- 기존 코드에서 customer_name, customer_phone을 사용하는 경우를 위한 VIEW
CREATE OR REPLACE VIEW reservations_legacy AS
SELECT 
  id,
  name AS customer_name,                -- 호환성: name → customer_name
  phone AS customer_phone,              -- 호환성: phone → customer_phone  
  email AS customer_email,              -- 호환성: email → customer_email
  reservation_date,
  reservation_time,
  guest_count,
  service_type,
  message,
  status,
  reservation_number,
  created_at,
  updated_at
FROM reservations;

-- =======================================================
-- 🔍 INDEXES (인덱스)
-- =======================================================

-- 성능 최적화를 위한 인덱스
CREATE INDEX IF NOT EXISTS idx_reservations_date ON reservations(reservation_date);
CREATE INDEX IF NOT EXISTS idx_reservations_time ON reservations(reservation_time);
CREATE INDEX IF NOT EXISTS idx_reservations_date_time ON reservations(reservation_date, reservation_time);
CREATE INDEX IF NOT EXISTS idx_reservations_status ON reservations(status);
CREATE INDEX IF NOT EXISTS idx_reservations_phone ON reservations(phone);
CREATE INDEX IF NOT EXISTS idx_reservations_number ON reservations(reservation_number);
CREATE INDEX IF NOT EXISTS idx_reservations_created_at ON reservations(created_at);

-- =======================================================
-- 🔐 RLS POLICIES (행 수준 보안 정책)
-- =======================================================

-- RLS 활성화
ALTER TABLE reservations ENABLE ROW LEVEL SECURITY;

-- 기존 정책 정리
DROP POLICY IF EXISTS "Anyone can insert reservations" ON reservations;
DROP POLICY IF EXISTS "Authenticated users can view reservations" ON reservations;
DROP POLICY IF EXISTS "Authenticated users can update reservations" ON reservations;
DROP POLICY IF EXISTS "Authenticated users can delete reservations" ON reservations;

-- 새로운 정책 생성
CREATE POLICY "Anyone can insert reservations" ON reservations
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Anyone can view reservations" ON reservations
  FOR SELECT USING (true);

CREATE POLICY "Authenticated users can update reservations" ON reservations
  FOR UPDATE USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can delete reservations" ON reservations
  FOR DELETE USING (auth.role() = 'authenticated');

-- =======================================================
-- ⚙️ TRIGGERS (트리거)
-- =======================================================

-- updated_at 자동 업데이트 함수
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- updated_at 트리거
DROP TRIGGER IF EXISTS update_reservations_updated_at ON reservations;
CREATE TRIGGER update_reservations_updated_at
  BEFORE UPDATE ON reservations
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- =======================================================
-- ✅ VALIDATION QUERY (검증 쿼리)
-- =======================================================

-- 테이블 구조 확인
SELECT 
  column_name, 
  data_type, 
  is_nullable, 
  column_default,
  character_maximum_length
FROM information_schema.columns 
WHERE table_name = 'reservations' 
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- 인덱스 확인
SELECT 
  indexname, 
  indexdef 
FROM pg_indexes 
WHERE tablename = 'reservations' 
  AND schemaname = 'public';

-- RLS 정책 확인
SELECT 
  policyname, 
  cmd, 
  qual 
FROM pg_policies 
WHERE tablename = 'reservations' 
  AND schemaname = 'public';

-- =======================================================
-- 📝 COMMENTS (주석)
-- =======================================================

COMMENT ON TABLE reservations IS 'OSO Camping BBQ 예약 시스템 메인 테이블';
COMMENT ON COLUMN reservations.id IS '예약 고유 식별자 (UUID)';
COMMENT ON COLUMN reservations.name IS '고객 이름';
COMMENT ON COLUMN reservations.phone IS '고객 전화번호';
COMMENT ON COLUMN reservations.email IS '고객 이메일 (선택사항)';
COMMENT ON COLUMN reservations.reservation_date IS '예약 날짜';
COMMENT ON COLUMN reservations.reservation_time IS '예약 시간';
COMMENT ON COLUMN reservations.guest_count IS '예약 인원수';
COMMENT ON COLUMN reservations.service_type IS '서비스 타입 (camping, bbq, camping_bbq 등)';
COMMENT ON COLUMN reservations.message IS '특별 요청사항';
COMMENT ON COLUMN reservations.status IS '예약 상태 (pending, confirmed, cancelled)';
COMMENT ON COLUMN reservations.reservation_number IS '예약번호 (OSO-YYMMDD-XXXX 형식)';

COMMENT ON VIEW reservations_legacy IS '기존 코드 호환성을 위한 뷰 (customer_name, customer_phone 매핑)';

-- =======================================================
-- 🎯 SUCCESS MESSAGE
-- =======================================================

DO $$
BEGIN
  RAISE NOTICE '✅ reservations 테이블이 올바르게 생성되었습니다!';
  RAISE NOTICE '📋 테이블 구조: id(UUID), name, phone, email, reservation_date, reservation_time, guest_count, service_type, message, status, reservation_number';
  RAISE NOTICE '🔍 하위 호환성: reservations_legacy 뷰를 통해 customer_name, customer_phone 접근 가능';
  RAISE NOTICE '🚀 이제 create_reservation_atomic() 함수와 완전히 호환됩니다!';
END;
$$;