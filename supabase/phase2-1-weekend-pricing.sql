-- Phase 2.1: VIP 평일/주말 요금 차등 설정을 위한 스키마 확장
-- 작성일: 2025년
-- 목표: VIP동에 평일/주말 차등 가격 정책 적용

-- 1. time_slot_catalog 테이블에 평일/주말 multiplier 추가
ALTER TABLE time_slot_catalog 
  ADD COLUMN IF NOT EXISTS weekday_multiplier DECIMAL(3,2) DEFAULT 1.0,
  ADD COLUMN IF NOT EXISTS weekend_multiplier DECIMAL(3,2) DEFAULT 1.2;

-- 2. resource_catalog 테이블에 주말 가격 정책 플래그 추가
ALTER TABLE resource_catalog 
  ADD COLUMN IF NOT EXISTS has_weekend_pricing BOOLEAN DEFAULT FALSE;

-- 3. 기존 time_slot_catalog 데이터 업데이트 (기본값 설정)
UPDATE time_slot_catalog SET 
  weekday_multiplier = 1.0,
  weekend_multiplier = 1.2
WHERE weekday_multiplier IS NULL OR weekend_multiplier IS NULL;

-- 4. VIP동 시설들에 주말 가격 정책 활성화
UPDATE resource_catalog SET 
  has_weekend_pricing = TRUE 
WHERE category_code = 'VP';

-- 5. VIP동 시간대별 주말 요금 정책 설정
-- 점심: 평일 1.0x, 주말 1.3x
-- 오후: 평일 1.1x, 주말 1.5x  
-- 저녁: 평일 1.2x, 주말 1.8x

UPDATE time_slot_catalog SET 
  weekday_multiplier = 1.0,
  weekend_multiplier = 1.3
WHERE slot_code = 'lunch';

UPDATE time_slot_catalog SET 
  weekday_multiplier = 1.1,
  weekend_multiplier = 1.5
WHERE slot_code = 'afternoon';

UPDATE time_slot_catalog SET 
  weekday_multiplier = 1.2,
  weekend_multiplier = 1.8
WHERE slot_code = 'dinner';

-- 6. 인덱스 추가 (성능 최적화)
CREATE INDEX IF NOT EXISTS idx_resource_weekend_pricing 
  ON resource_catalog(category_code, has_weekend_pricing);

-- 7. 확인 쿼리
SELECT 
  r.internal_code,
  r.category_code,
  r.display_name,
  r.has_weekend_pricing,
  t.slot_code,
  t.display_name as time_name,
  t.weekday_multiplier,
  t.weekend_multiplier
FROM resource_catalog r
JOIN sku_catalog s ON r.internal_code = s.resource_code
JOIN time_slot_catalog t ON s.time_slot_code = t.slot_code
WHERE r.category_code = 'VP'
ORDER BY r.internal_code, t.slot_code;

-- 8. 주말 감지 함수 (PostgreSQL)
CREATE OR REPLACE FUNCTION is_weekend(check_date DATE) 
RETURNS BOOLEAN AS $$
BEGIN
  -- 토요일(6), 일요일(0) 체크 (PostgreSQL의 EXTRACT DOW: 일요일=0, 월요일=1, ...)
  RETURN EXTRACT(DOW FROM check_date) IN (0, 6);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- 9. 동적 가격 계산 함수
CREATE OR REPLACE FUNCTION calculate_dynamic_price(
  p_resource_code TEXT,
  p_time_slot_code TEXT,
  p_reservation_date DATE,
  p_guest_count INTEGER DEFAULT 1
) 
RETURNS INTEGER AS $$
DECLARE
  base_price INTEGER;
  multiplier DECIMAL(3,2);
  weekend_pricing_enabled BOOLEAN;
  final_price INTEGER;
BEGIN
  -- 기본 가격 조회
  SELECT r.price, r.has_weekend_pricing
  INTO base_price, weekend_pricing_enabled
  FROM resource_catalog r
  WHERE r.internal_code = p_resource_code;
  
  -- multiplier 결정 (평일/주말 구분)
  IF weekend_pricing_enabled AND is_weekend(p_reservation_date) THEN
    SELECT t.weekend_multiplier
    INTO multiplier
    FROM time_slot_catalog t
    WHERE t.slot_code = p_time_slot_code;
  ELSE
    SELECT t.weekday_multiplier
    INTO multiplier
    FROM time_slot_catalog t
    WHERE t.slot_code = p_time_slot_code;
  END IF;
  
  -- 최종 가격 계산
  final_price := ROUND(base_price * multiplier);
  
  RETURN final_price;
END;
$$ LANGUAGE plpgsql STABLE;

-- 10. 테스트 쿼리 예시
-- VIP01 저녁 시간대의 평일/주말 가격 비교
SELECT 
  'VP01' as resource_code,
  'dinner' as time_slot,
  '2025-09-08'::DATE as test_date, -- 월요일
  calculate_dynamic_price('VP01', 'dinner', '2025-09-08'::DATE, 4) as weekday_price,
  calculate_dynamic_price('VP01', 'dinner', '2025-09-13'::DATE, 4) as weekend_price, -- 토요일
  EXTRACT(DOW FROM '2025-09-08'::DATE) as monday_dow,
  EXTRACT(DOW FROM '2025-09-13'::DATE) as saturday_dow;