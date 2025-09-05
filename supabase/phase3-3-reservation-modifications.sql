-- Phase 3.3: 예약 변경/취소 기능 구현
-- 작성일: 2025년
-- 목표: 고객이 직접 예약을 수정/취소할 수 있는 시스템

-- 1. 예약 변경 이력 테이블
CREATE TABLE IF NOT EXISTS reservation_modifications (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  reservation_id INTEGER REFERENCES reservations(id) ON DELETE CASCADE,
  reservation_number TEXT NOT NULL,
  modification_type TEXT NOT NULL, -- 'change_date', 'change_time', 'change_guests', 'cancel', 'partial_refund'
  status TEXT DEFAULT 'pending', -- 'pending', 'approved', 'rejected', 'processing', 'completed'
  
  -- 변경 전 정보
  original_data JSONB NOT NULL,
  
  -- 변경 후 정보 (취소의 경우 null)
  new_data JSONB,
  
  -- 변경 요청 정보
  requested_by TEXT NOT NULL, -- 'customer', 'admin'
  customer_phone TEXT,
  reason TEXT, -- 고객이 제공한 변경/취소 사유
  
  -- 관리자 처리 정보
  processed_by TEXT, -- 관리자 ID (향후 관리자 인증 시스템 연동)
  admin_notes TEXT,
  processing_date TIMESTAMPTZ,
  
  -- 취소/환불 정보
  cancellation_policy_applied TEXT, -- 적용된 취소 정책
  refund_amount INTEGER DEFAULT 0, -- 환불 금액
  refund_reason TEXT,
  refund_processed_at TIMESTAMPTZ,
  
  -- 수수료 정보
  change_fee INTEGER DEFAULT 0, -- 변경 수수료
  cancellation_fee INTEGER DEFAULT 0, -- 취소 수수료
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. 취소 정책 테이블
CREATE TABLE IF NOT EXISTS cancellation_policies (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  policy_name TEXT NOT NULL UNIQUE,
  description TEXT,
  
  -- 취소 시점별 환불율 (예약일까지 남은 일수 기준)
  refund_rules JSONB NOT NULL, -- [{"days_before": 7, "refund_rate": 100}, {"days_before": 3, "refund_rate": 50}]
  
  -- 수수료 설정
  change_fee INTEGER DEFAULT 0, -- 변경 수수료 (원)
  min_cancellation_fee INTEGER DEFAULT 0, -- 최소 취소 수수료
  max_cancellation_fee INTEGER, -- 최대 취소 수수료
  
  -- 변경 제한
  max_changes_allowed INTEGER DEFAULT 2, -- 최대 변경 가능 횟수
  change_deadline_hours INTEGER DEFAULT 24, -- 변경 마감 시간 (예약일 기준)
  cancellation_deadline_hours INTEGER DEFAULT 24, -- 취소 마감 시간
  
  -- 적용 범위
  applies_to_categories TEXT[] DEFAULT '{}', -- 적용 카테고리 (빈 배열이면 전체 적용)
  is_active BOOLEAN DEFAULT true,
  is_default BOOLEAN DEFAULT false,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. 인덱스 추가
CREATE INDEX IF NOT EXISTS idx_reservation_modifications_reservation 
ON reservation_modifications(reservation_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_reservation_modifications_status 
ON reservation_modifications(status, created_at);

CREATE INDEX IF NOT EXISTS idx_reservation_modifications_phone 
ON reservation_modifications(customer_phone, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_cancellation_policies_active 
ON cancellation_policies(is_active, is_default);

-- 4. RLS (Row Level Security) 정책 설정
ALTER TABLE reservation_modifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE cancellation_policies ENABLE ROW LEVEL SECURITY;

-- 고객은 자신의 예약 변경 내역만 조회 가능
CREATE POLICY "customers_can_view_own_modifications" ON reservation_modifications
FOR SELECT USING (customer_phone = current_setting('app.current_user_phone', true));

-- 고객은 자신의 변경 요청만 생성 가능
CREATE POLICY "customers_can_create_modifications" ON reservation_modifications
FOR INSERT WITH CHECK (customer_phone = current_setting('app.current_user_phone', true));

-- 관리자는 모든 변경 내역 조회/수정 가능
CREATE POLICY "admins_can_manage_modifications" ON reservation_modifications
FOR ALL USING (true) WITH CHECK (true);

-- 취소 정책은 모든 사용자가 조회 가능, 관리자만 수정 가능
CREATE POLICY "users_can_view_policies" ON cancellation_policies
FOR SELECT USING (is_active = true);

CREATE POLICY "admins_can_manage_policies" ON cancellation_policies
FOR ALL USING (true) WITH CHECK (true);

-- 5. 기본 취소 정책 삽입
INSERT INTO cancellation_policies (
  policy_name, 
  description, 
  refund_rules, 
  change_fee,
  min_cancellation_fee,
  max_cancellation_fee,
  max_changes_allowed,
  change_deadline_hours,
  cancellation_deadline_hours,
  is_default
) VALUES (
  'standard_policy',
  '표준 취소/변경 정책',
  '[
    {"days_before": 7, "refund_rate": 100, "description": "7일 전까지 100% 환불"},
    {"days_before": 3, "refund_rate": 70, "description": "3-6일 전 70% 환불"},
    {"days_before": 1, "refund_rate": 50, "description": "1-2일 전 50% 환불"},
    {"days_before": 0, "refund_rate": 0, "description": "당일 환불 불가"}
  ]'::jsonb,
  10000,  -- 변경 수수료 1만원
  5000,   -- 최소 취소 수수료 5천원
  50000,  -- 최대 취소 수수료 5만원
  2,      -- 최대 2회 변경 가능
  24,     -- 24시간 전까지 변경 가능
  24,     -- 24시간 전까지 취소 가능
  true
) ON CONFLICT (policy_name) DO NOTHING;

-- VIP동 전용 정책 (더 관대한 정책)
INSERT INTO cancellation_policies (
  policy_name, 
  description, 
  refund_rules, 
  change_fee,
  min_cancellation_fee,
  max_cancellation_fee,
  max_changes_allowed,
  change_deadline_hours,
  cancellation_deadline_hours,
  applies_to_categories,
  is_default
) VALUES (
  'vip_policy',
  'VIP동 취소/변경 정책 (관대한 조건)',
  '[
    {"days_before": 3, "refund_rate": 100, "description": "3일 전까지 100% 환불"},
    {"days_before": 1, "refund_rate": 80, "description": "1-2일 전 80% 환불"},
    {"days_before": 0, "refund_rate": 50, "description": "당일 50% 환불"}
  ]'::jsonb,
  5000,   -- 변경 수수료 5천원
  0,      -- 최소 취소 수수료 없음
  30000,  -- 최대 취소 수수료 3만원
  3,      -- 최대 3회 변경 가능
  12,     -- 12시간 전까지 변경 가능
  12,     -- 12시간 전까지 취소 가능
  '{"VP"}',  -- VIP동만 적용
  false
) ON CONFLICT (policy_name) DO NOTHING;

-- 6. 예약 변경/취소 관련 함수들

-- 6.1. 적용 가능한 취소 정책 조회
CREATE OR REPLACE FUNCTION get_applicable_cancellation_policy(p_reservation_id INTEGER)
RETURNS cancellation_policies AS $$
DECLARE
  reservation_record RECORD;
  policy_record cancellation_policies;
BEGIN
  -- 예약 정보 조회
  SELECT r.*, sc.resource_code
  INTO reservation_record
  FROM reservations r
  LEFT JOIN sku_catalog sc ON r.sku_code = sc.sku_code
  WHERE r.id = p_reservation_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION '예약을 찾을 수 없습니다: %', p_reservation_id;
  END IF;
  
  -- 카테고리별 정책 조회
  SELECT * INTO policy_record
  FROM cancellation_policies
  WHERE is_active = true
    AND (
      applies_to_categories = '{}' OR 
      reservation_record.resource_code = ANY(applies_to_categories)
    )
  ORDER BY 
    CASE WHEN applies_to_categories != '{}' THEN 1 ELSE 2 END, -- 특정 카테고리 우선
    is_default DESC,
    created_at DESC
  LIMIT 1;
  
  IF NOT FOUND THEN
    -- 기본 정책 조회
    SELECT * INTO policy_record
    FROM cancellation_policies
    WHERE is_active = true AND is_default = true
    LIMIT 1;
  END IF;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION '적용 가능한 취소 정책이 없습니다';
  END IF;
  
  RETURN policy_record;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- 6.2. 환불 금액 계산
CREATE OR REPLACE FUNCTION calculate_refund_amount(
  p_reservation_id INTEGER,
  p_cancellation_date TIMESTAMPTZ DEFAULT NOW()
) RETURNS JSONB AS $$
DECLARE
  reservation_record RECORD;
  policy_record cancellation_policies;
  days_before INTEGER;
  refund_rule JSONB;
  refund_rate INTEGER := 0;
  refund_amount INTEGER := 0;
  cancellation_fee INTEGER := 0;
  result JSONB;
BEGIN
  -- 예약 정보 조회
  SELECT * INTO reservation_record
  FROM reservations
  WHERE id = p_reservation_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION '예약을 찾을 수 없습니다: %', p_reservation_id;
  END IF;
  
  -- 적용 정책 조회
  policy_record := get_applicable_cancellation_policy(p_reservation_id);
  
  -- 예약일까지 남은 일수 계산
  days_before := EXTRACT(DAY FROM reservation_record.reservation_date - p_cancellation_date::date);
  
  -- 환불율 찾기 (규칙을 일수 순으로 정렬하여 적용)
  FOR refund_rule IN 
    SELECT * FROM jsonb_array_elements(policy_record.refund_rules)
    ORDER BY (value->>'days_before')::integer DESC
  LOOP
    IF days_before >= (refund_rule->>'days_before')::integer THEN
      refund_rate := (refund_rule->>'refund_rate')::integer;
      EXIT;
    END IF;
  END LOOP;
  
  -- 환불 금액 계산
  refund_amount := (reservation_record.total_price * refund_rate / 100);
  
  -- 취소 수수료 계산
  IF refund_rate < 100 THEN
    cancellation_fee := GREATEST(
      policy_record.min_cancellation_fee,
      LEAST(
        COALESCE(policy_record.max_cancellation_fee, reservation_record.total_price),
        reservation_record.total_price - refund_amount
      )
    );
    refund_amount := GREATEST(0, refund_amount - cancellation_fee);
  END IF;
  
  -- 결과 반환
  result := jsonb_build_object(
    'original_amount', reservation_record.total_price,
    'days_before', days_before,
    'refund_rate', refund_rate,
    'refund_amount', refund_amount,
    'cancellation_fee', cancellation_fee,
    'policy_name', policy_record.policy_name,
    'applied_rule', (
      SELECT value 
      FROM jsonb_array_elements(policy_record.refund_rules) 
      WHERE (value->>'days_before')::integer <= days_before
      ORDER BY (value->>'days_before')::integer DESC 
      LIMIT 1
    )
  );
  
  RETURN result;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- 6.3. 변경 가능 여부 확인
CREATE OR REPLACE FUNCTION can_modify_reservation(
  p_reservation_id INTEGER,
  p_modification_type TEXT DEFAULT 'change_date'
) RETURNS JSONB AS $$
DECLARE
  reservation_record RECORD;
  policy_record cancellation_policies;
  modification_count INTEGER;
  hours_before INTEGER;
  deadline_hours INTEGER;
  can_modify BOOLEAN := false;
  reason TEXT := '';
  result JSONB;
BEGIN
  -- 예약 정보 조회
  SELECT * INTO reservation_record
  FROM reservations
  WHERE id = p_reservation_id;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'can_modify', false,
      'reason', '예약을 찾을 수 없습니다'
    );
  END IF;
  
  -- 이미 취소된 예약은 변경 불가
  IF reservation_record.status = 'cancelled' THEN
    RETURN jsonb_build_object(
      'can_modify', false,
      'reason', '이미 취소된 예약은 변경할 수 없습니다'
    );
  END IF;
  
  -- 완료된 예약은 변경 불가
  IF reservation_record.status = 'completed' THEN
    RETURN jsonb_build_object(
      'can_modify', false,
      'reason', '완료된 예약은 변경할 수 없습니다'
    );
  END IF;
  
  -- 적용 정책 조회
  policy_record := get_applicable_cancellation_policy(p_reservation_id);
  
  -- 기존 변경 횟수 확인
  SELECT COUNT(*) INTO modification_count
  FROM reservation_modifications
  WHERE reservation_id = p_reservation_id
    AND modification_type != 'cancel'
    AND status IN ('approved', 'completed');
  
  -- 최대 변경 횟수 확인
  IF modification_count >= policy_record.max_changes_allowed THEN
    RETURN jsonb_build_object(
      'can_modify', false,
      'reason', format('최대 변경 가능 횟수(%s회)를 초과했습니다', policy_record.max_changes_allowed)
    );
  END IF;
  
  -- 예약일까지 남은 시간 계산
  hours_before := EXTRACT(EPOCH FROM reservation_record.reservation_date - NOW()) / 3600;
  
  -- 변경 종류별 마감시간 확인
  deadline_hours := CASE 
    WHEN p_modification_type = 'cancel' THEN policy_record.cancellation_deadline_hours
    ELSE policy_record.change_deadline_hours
  END;
  
  IF hours_before < deadline_hours THEN
    RETURN jsonb_build_object(
      'can_modify', false,
      'reason', format('%s시간 전까지만 %s 가능합니다', 
        deadline_hours, 
        CASE WHEN p_modification_type = 'cancel' THEN '취소' ELSE '변경' END
      )
    );
  END IF;
  
  -- 모든 조건 통과
  result := jsonb_build_object(
    'can_modify', true,
    'reason', '변경 가능',
    'remaining_changes', policy_record.max_changes_allowed - modification_count,
    'hours_before', hours_before,
    'deadline_hours', deadline_hours,
    'policy_name', policy_record.policy_name
  );
  
  -- 변경 수수료 정보 추가
  IF p_modification_type != 'cancel' THEN
    result := result || jsonb_build_object('change_fee', policy_record.change_fee);
  END IF;
  
  RETURN result;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- 6.4. 예약 변경 요청 생성
CREATE OR REPLACE FUNCTION create_modification_request(
  p_reservation_id INTEGER,
  p_modification_type TEXT,
  p_customer_phone TEXT,
  p_new_data JSONB DEFAULT NULL,
  p_reason TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  reservation_record RECORD;
  modification_check JSONB;
  original_data JSONB;
  modification_id UUID;
  change_fee INTEGER := 0;
  policy_record cancellation_policies;
BEGIN
  -- 변경 가능 여부 확인
  modification_check := can_modify_reservation(p_reservation_id, p_modification_type);
  
  IF NOT (modification_check->>'can_modify')::boolean THEN
    RAISE EXCEPTION '변경 불가: %', modification_check->>'reason';
  END IF;
  
  -- 예약 정보 조회
  SELECT * INTO reservation_record
  FROM reservations
  WHERE id = p_reservation_id;
  
  -- 원본 데이터 구성
  original_data := jsonb_build_object(
    'reservation_date', reservation_record.reservation_date,
    'guest_count', reservation_record.guest_count,
    'sku_code', reservation_record.sku_code,
    'total_price', reservation_record.total_price,
    'status', reservation_record.status
  );
  
  -- 변경 수수료 계산
  IF p_modification_type != 'cancel' THEN
    policy_record := get_applicable_cancellation_policy(p_reservation_id);
    change_fee := policy_record.change_fee;
  END IF;
  
  -- 변경 요청 생성
  INSERT INTO reservation_modifications (
    reservation_id,
    reservation_number,
    modification_type,
    original_data,
    new_data,
    requested_by,
    customer_phone,
    reason,
    change_fee
  ) VALUES (
    p_reservation_id,
    reservation_record.reservation_number,
    p_modification_type,
    original_data,
    p_new_data,
    'customer',
    p_customer_phone,
    p_reason,
    change_fee
  ) RETURNING id INTO modification_id;
  
  RETURN modification_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6.5. 변경 요청 승인/거부
CREATE OR REPLACE FUNCTION process_modification_request(
  p_modification_id UUID,
  p_action TEXT, -- 'approve', 'reject'
  p_admin_notes TEXT DEFAULT NULL,
  p_processed_by TEXT DEFAULT 'admin'
) RETURNS BOOLEAN AS $$
DECLARE
  modification_record RECORD;
  reservation_record RECORD;
  refund_info JSONB;
BEGIN
  -- 변경 요청 조회
  SELECT * INTO modification_record
  FROM reservation_modifications
  WHERE id = p_modification_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION '변경 요청을 찾을 수 없습니다: %', p_modification_id;
  END IF;
  
  IF modification_record.status != 'pending' THEN
    RAISE EXCEPTION '이미 처리된 요청입니다: %', modification_record.status;
  END IF;
  
  -- 변경 요청 상태 업데이트
  UPDATE reservation_modifications SET
    status = CASE 
      WHEN p_action = 'approve' THEN 'approved'
      WHEN p_action = 'reject' THEN 'rejected'
      ELSE 'rejected'
    END,
    processed_by = p_processed_by,
    admin_notes = p_admin_notes,
    processing_date = NOW(),
    updated_at = NOW()
  WHERE id = p_modification_id;
  
  -- 승인된 경우 실제 예약 정보 업데이트
  IF p_action = 'approve' THEN
    IF modification_record.modification_type = 'cancel' THEN
      -- 취소 처리
      UPDATE reservations SET 
        status = 'cancelled',
        updated_at = NOW()
      WHERE id = modification_record.reservation_id;
      
      -- 환불 정보 계산 및 기록
      refund_info := calculate_refund_amount(modification_record.reservation_id);
      
      UPDATE reservation_modifications SET
        refund_amount = (refund_info->>'refund_amount')::integer,
        cancellation_fee = (refund_info->>'cancellation_fee')::integer,
        cancellation_policy_applied = refund_info->>'policy_name'
      WHERE id = p_modification_id;
      
    ELSE
      -- 변경 처리
      SELECT * INTO reservation_record FROM reservations WHERE id = modification_record.reservation_id;
      
      UPDATE reservations SET
        reservation_date = COALESCE(
          (modification_record.new_data->>'reservation_date')::date,
          reservation_date
        ),
        guest_count = COALESCE(
          (modification_record.new_data->>'guest_count')::integer,
          guest_count
        ),
        sku_code = COALESCE(
          modification_record.new_data->>'sku_code',
          sku_code
        ),
        total_price = COALESCE(
          (modification_record.new_data->>'total_price')::integer,
          total_price
        ),
        updated_at = NOW()
      WHERE id = modification_record.reservation_id;
    END IF;
    
    -- 변경 완료 상태로 업데이트
    UPDATE reservation_modifications SET
      status = 'completed'
    WHERE id = p_modification_id;
  END IF;
  
  RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. 고객용 조회 함수들

-- 7.1. 고객 변경 내역 조회
CREATE OR REPLACE FUNCTION get_customer_modifications(
  p_customer_phone TEXT,
  p_limit INTEGER DEFAULT 10
) RETURNS TABLE(
  id UUID,
  reservation_number TEXT,
  modification_type TEXT,
  status TEXT,
  original_data JSONB,
  new_data JSONB,
  reason TEXT,
  change_fee INTEGER,
  refund_amount INTEGER,
  admin_notes TEXT,
  created_at TIMESTAMPTZ,
  processing_date TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    rm.id,
    rm.reservation_number,
    rm.modification_type,
    rm.status,
    rm.original_data,
    rm.new_data,
    rm.reason,
    rm.change_fee,
    rm.refund_amount,
    rm.admin_notes,
    rm.created_at,
    rm.processing_date
  FROM reservation_modifications rm
  WHERE rm.customer_phone = p_customer_phone
  ORDER BY rm.created_at DESC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- 7.2. 예약 변경 가능 옵션 조회 (날짜/시간 변경용)
CREATE OR REPLACE FUNCTION get_available_modification_options(
  p_reservation_id INTEGER,
  p_new_date DATE DEFAULT NULL
) RETURNS TABLE(
  sku_code TEXT,
  resource_name TEXT,
  time_slot_name TEXT,
  base_price INTEGER,
  total_price INTEGER,
  is_available BOOLEAN
) AS $$
DECLARE
  reservation_record RECORD;
  target_date DATE;
BEGIN
  -- 예약 정보 조회
  SELECT * INTO reservation_record
  FROM reservations
  WHERE id = p_reservation_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION '예약을 찾을 수 없습니다: %', p_reservation_id;
  END IF;
  
  target_date := COALESCE(p_new_date, reservation_record.reservation_date);
  
  RETURN QUERY
  SELECT 
    sc.sku_code,
    rc.display_name as resource_name,
    tc.display_name as time_slot_name,
    sc.base_price,
    calculateTotalPriceWithGuests(sc.sku_code, target_date, reservation_record.guest_count) as total_price,
    NOT EXISTS(
      SELECT 1 FROM reservations r2 
      WHERE r2.sku_code = sc.sku_code 
        AND r2.reservation_date = target_date
        AND r2.status IN ('pending', 'confirmed')
        AND r2.id != p_reservation_id
    ) as is_available
  FROM sku_catalog sc
  JOIN resource_catalog rc ON sc.resource_code = rc.internal_code
  JOIN time_slot_catalog tc ON sc.time_slot_code = tc.slot_code
  WHERE rc.internal_code = (
    SELECT sc2.resource_code 
    FROM sku_catalog sc2 
    WHERE sc2.sku_code = reservation_record.sku_code
  )
  ORDER BY tc.display_order, sc.base_price;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- 8. 관리자용 조회 함수들

-- 8.1. 모든 변경 요청 조회 (관리자용)
CREATE OR REPLACE FUNCTION get_all_modification_requests(
  p_status TEXT DEFAULT NULL,
  p_limit INTEGER DEFAULT 50
) RETURNS TABLE(
  id UUID,
  reservation_id INTEGER,
  reservation_number TEXT,
  modification_type TEXT,
  status TEXT,
  customer_phone TEXT,
  reason TEXT,
  change_fee INTEGER,
  refund_amount INTEGER,
  requested_by TEXT,
  created_at TIMESTAMPTZ,
  processing_date TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    rm.id,
    rm.reservation_id,
    rm.reservation_number,
    rm.modification_type,
    rm.status,
    rm.customer_phone,
    rm.reason,
    rm.change_fee,
    rm.refund_amount,
    rm.requested_by,
    rm.created_at,
    rm.processing_date
  FROM reservation_modifications rm
  WHERE (p_status IS NULL OR rm.status = p_status)
  ORDER BY 
    CASE rm.status 
      WHEN 'pending' THEN 1 
      WHEN 'approved' THEN 2 
      ELSE 3 
    END,
    rm.created_at DESC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- 9. 트리거 함수 - 변경 승인 시 알림 발송
CREATE OR REPLACE FUNCTION trigger_modification_notifications()
RETURNS TRIGGER AS $$
BEGIN
  -- 변경 요청이 승인되었을 때
  IF TG_OP = 'UPDATE' AND OLD.status = 'pending' AND NEW.status = 'approved' THEN
    -- SMS/이메일 알림 발송 (Phase 3.2 연동)
    IF NEW.modification_type = 'cancel' THEN
      PERFORM send_reservation_message(NEW.reservation_id, 'reservation_cancelled');
    ELSE  
      -- 변경 승인 알림 (새로운 템플릿 필요)
      PERFORM notify_reservation_approved(NEW.reservation_id); -- 임시로 승인 알림 사용
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 변경 요청 테이블에 트리거 설정
DROP TRIGGER IF EXISTS modification_notification_trigger ON reservation_modifications;
CREATE TRIGGER modification_notification_trigger
  AFTER UPDATE OF status ON reservation_modifications
  FOR EACH ROW
  EXECUTE FUNCTION trigger_modification_notifications();

-- 10. 테스트 함수
CREATE OR REPLACE FUNCTION test_modification_system(p_reservation_id INTEGER)
RETURNS TEXT AS $$
DECLARE
  result TEXT := '';
  policy_info cancellation_policies;
  can_modify_info JSONB;
  refund_info JSONB;
BEGIN
  -- 정책 조회 테스트
  BEGIN
    policy_info := get_applicable_cancellation_policy(p_reservation_id);
    result := result || format('적용 정책: %s\n', policy_info.policy_name);
  EXCEPTION WHEN OTHERS THEN
    result := result || format('정책 조회 실패: %s\n', SQLERRM);
  END;
  
  -- 변경 가능 여부 테스트
  BEGIN
    can_modify_info := can_modify_reservation(p_reservation_id, 'change_date');
    result := result || format('변경 가능: %s\n', can_modify_info->>'can_modify');
    result := result || format('사유: %s\n', can_modify_info->>'reason');
  EXCEPTION WHEN OTHERS THEN
    result := result || format('변경 가능 여부 확인 실패: %s\n', SQLERRM);
  END;
  
  -- 환불 계산 테스트
  BEGIN
    refund_info := calculate_refund_amount(p_reservation_id);
    result := result || format('환불 금액: %s원\n', refund_info->>'refund_amount');
    result := result || format('취소 수수료: %s원\n', refund_info->>'cancellation_fee');
  EXCEPTION WHEN OTHERS THEN
    result := result || format('환불 계산 실패: %s\n', SQLERRM);
  END;
  
  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;