-- Phase 2.2: 추가 인원 요금 시스템 구현을 위한 스키마 확장
-- 작성일: 2025년
-- 목표: 기준 인원 초과 시 추가 요금 부과 시스템 구축

-- 1. resource_catalog 테이블에 추가 인원 관련 컬럼 추가
ALTER TABLE resource_catalog 
  ADD COLUMN IF NOT EXISTS base_guests INTEGER DEFAULT 4,
  ADD COLUMN IF NOT EXISTS extra_guest_fee INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS max_extra_guests INTEGER DEFAULT 4;

-- 2. 기존 데이터 업데이트 (카테고리별 기본값 설정)

-- 프라이빗룸: 기본 4명, 추가 인원당 8,000원, 최대 2명 추가 가능
UPDATE resource_catalog SET 
  base_guests = 4,
  extra_guest_fee = 8000,
  max_extra_guests = 2
WHERE category_code = 'PR';

-- 소파테이블: 기본 2명, 추가 인원당 5,000원, 최대 2명 추가 가능
UPDATE resource_catalog SET 
  base_guests = 2,
  extra_guest_fee = 5000,
  max_extra_guests = 2
WHERE category_code = 'ST';

-- 텐트동: 기본 6명, 추가 인원당 6,000원, 최대 4명 추가 가능
UPDATE resource_catalog SET 
  base_guests = 6,
  extra_guest_fee = 6000,
  max_extra_guests = 4
WHERE category_code = 'TN';

-- VIP동: 기본 8명, 추가 인원당 12,000원, 최대 4명 추가 가능
UPDATE resource_catalog SET 
  base_guests = 8,
  extra_guest_fee = 12000,
  max_extra_guests = 4
WHERE category_code = 'VP';

-- 야장테이블: 기본 10명, 추가 인원당 4,000원, 최대 6명 추가 가능
UPDATE resource_catalog SET 
  base_guests = 10,
  extra_guest_fee = 4000,
  max_extra_guests = 6
WHERE category_code = 'YT';

-- 3. max_guests 컬럼 업데이트 (기본 인원 + 최대 추가 인원)
UPDATE resource_catalog SET 
  max_guests = base_guests + max_extra_guests;

-- 4. 추가 인원 요금 계산 함수 (기존 함수 업그레이드)
CREATE OR REPLACE FUNCTION calculate_total_price_with_guests(
  p_resource_code TEXT,
  p_time_slot_code TEXT,
  p_reservation_date DATE,
  p_guest_count INTEGER DEFAULT 1
) 
RETURNS JSON AS $$
DECLARE
  base_price INTEGER;
  base_guests INTEGER;
  extra_guest_fee INTEGER;
  max_extra_guests INTEGER;
  weekend_pricing_enabled BOOLEAN;
  multiplier DECIMAL(3,2);
  base_total INTEGER;
  extra_guests_count INTEGER;
  extra_guests_fee INTEGER;
  final_price INTEGER;
  result JSON;
BEGIN
  -- 시설 기본 정보 조회
  SELECT r.price, r.base_guests, r.extra_guest_fee, r.max_extra_guests, r.has_weekend_pricing
  INTO base_price, base_guests, extra_guest_fee, max_extra_guests, weekend_pricing_enabled
  FROM resource_catalog r
  WHERE r.internal_code = p_resource_code;
  
  -- 인원수 유효성 검사
  IF p_guest_count > (base_guests + max_extra_guests) THEN
    RAISE EXCEPTION '최대 수용 인원을 초과했습니다. (최대: %명)', base_guests + max_extra_guests;
  END IF;
  
  -- multiplier 결정 (평일/주말 + VIP동 구분)
  IF weekend_pricing_enabled AND is_weekend(p_reservation_date) THEN
    SELECT t.weekend_multiplier INTO multiplier
    FROM time_slot_catalog t WHERE t.slot_code = p_time_slot_code;
  ELSE
    SELECT COALESCE(t.weekday_multiplier, t.price_multiplier, 1.0) INTO multiplier
    FROM time_slot_catalog t WHERE t.slot_code = p_time_slot_code;
  END IF;
  
  -- 기본 가격 계산 (기본 인원까지)
  base_total := ROUND(base_price * multiplier);
  
  -- 추가 인원 계산
  extra_guests_count := GREATEST(0, p_guest_count - base_guests);
  extra_guests_fee := extra_guests_count * extra_guest_fee;
  
  -- 최종 가격
  final_price := base_total + extra_guests_fee;
  
  -- JSON 결과 반환
  result := json_build_object(
    'base_price', base_price,
    'multiplier', multiplier,
    'base_total', base_total,
    'base_guests', base_guests,
    'guest_count', p_guest_count,
    'extra_guests_count', extra_guests_count,
    'extra_guest_fee_per_person', extra_guest_fee,
    'extra_guests_fee_total', extra_guests_fee,
    'final_price', final_price,
    'is_weekend', weekend_pricing_enabled AND is_weekend(p_reservation_date),
    'price_breakdown', json_build_object(
      'base_facility', base_total,
      'extra_guests', extra_guests_fee,
      'total', final_price
    )
  );
  
  RETURN result;
END;
$$ LANGUAGE plpgsql STABLE;

-- 5. 인덱스 추가 (성능 최적화)
CREATE INDEX IF NOT EXISTS idx_resource_guest_pricing 
  ON resource_catalog(category_code, base_guests, extra_guest_fee);

-- 6. 확인 쿼리 - 카테고리별 인원 정책 현황
SELECT 
  category_code,
  COUNT(*) as facility_count,
  MIN(base_guests) as min_base_guests,
  MAX(base_guests) as max_base_guests,
  MIN(extra_guest_fee) as min_extra_fee,
  MAX(extra_guest_fee) as max_extra_fee,
  MIN(max_extra_guests) as min_max_extra,
  MAX(max_extra_guests) as max_max_extra,
  MIN(max_guests) as min_total_capacity,
  MAX(max_guests) as max_total_capacity
FROM resource_catalog 
GROUP BY category_code 
ORDER BY category_code;

-- 7. 테스트 쿼리 예시
-- VIP01에서 12명 예약 시 주말 가격 계산
SELECT 
  'VP01' as resource_code,
  'dinner' as time_slot,
  '2025-09-13'::DATE as weekend_date, -- 토요일
  12 as guest_count,
  calculate_total_price_with_guests('VP01', 'dinner', '2025-09-13'::DATE, 12) as price_breakdown;

-- 8. 시설별 상세 인원 정책 조회
SELECT 
  r.internal_code,
  r.category_code,
  r.display_name,
  r.base_guests || '명 (기본)' as base_capacity,
  '+ ' || r.max_extra_guests || '명 (추가)' as extra_capacity,
  '= ' || r.max_guests || '명 (최대)' as total_capacity,
  '₩' || r.extra_guest_fee::text || '/명' as extra_fee,
  r.price as base_price
FROM resource_catalog r
WHERE r.active = true
ORDER BY r.category_code, r.internal_code;