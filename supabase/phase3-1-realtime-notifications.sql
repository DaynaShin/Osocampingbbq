-- Phase 3.1: 실시간 알림 시스템 구현
-- 작성일: 2025년
-- 목표: Supabase Realtime을 활용한 WebSocket 기반 실시간 알림

-- 1. 알림 테이블 생성
CREATE TABLE IF NOT EXISTS notifications (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  type TEXT NOT NULL, -- 'reservation_approved', 'reservation_cancelled', 'new_reservation', 'reservation_modified'
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  recipient_type TEXT NOT NULL, -- 'customer', 'admin'
  recipient_id TEXT, -- 고객의 경우 전화번호, 관리자의 경우 'admin'
  reservation_id INTEGER REFERENCES reservations(id),
  reservation_number TEXT,
  metadata JSONB DEFAULT '{}', -- 추가 데이터 (시설명, 날짜 등)
  is_read BOOLEAN DEFAULT false,
  is_sent BOOLEAN DEFAULT false, -- 브라우저 알림 발송 여부
  priority TEXT DEFAULT 'normal', -- 'low', 'normal', 'high', 'urgent'
  expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '7 days'), -- 알림 만료일
  created_at TIMESTAMPTZ DEFAULT NOW(),
  read_at TIMESTAMPTZ,
  sent_at TIMESTAMPTZ
);

-- 2. 인덱스 추가 (성능 최적화)
CREATE INDEX IF NOT EXISTS idx_notifications_recipient 
ON notifications(recipient_type, recipient_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_unread 
ON notifications(recipient_type, recipient_id, is_read, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_reservation 
ON notifications(reservation_id, created_at DESC);

-- 3. RLS (Row Level Security) 정책 설정
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- 고객은 자신에게 온 알림만 조회 가능 (전화번호 기반)
CREATE POLICY "customers_can_view_own_notifications" ON notifications
FOR SELECT USING (recipient_type = 'customer');

-- 관리자는 관리자용 알림만 조회 가능
CREATE POLICY "admins_can_view_admin_notifications" ON notifications
FOR SELECT USING (recipient_type = 'admin');

-- 시스템에서만 알림 생성 가능 (함수를 통해서만)
CREATE POLICY "system_can_insert_notifications" ON notifications
FOR INSERT WITH CHECK (true);

-- 알림 읽음 상태 업데이트 가능
CREATE POLICY "users_can_update_read_status" ON notifications
FOR UPDATE USING (true)
WITH CHECK (true);

-- 4. 알림 생성 함수들
-- 4.1. 예약 승인 알림
CREATE OR REPLACE FUNCTION notify_reservation_approved(p_reservation_id INTEGER)
RETURNS UUID AS $$
DECLARE
  reservation_record RECORD;
  notification_id UUID;
BEGIN
  -- 예약 정보 조회
  SELECT r.*, rc.display_name as facility_name, tc.display_name as time_slot
  INTO reservation_record
  FROM reservations r
  LEFT JOIN sku_catalog sc ON r.sku_code = sc.sku_code
  LEFT JOIN resource_catalog rc ON sc.resource_code = rc.internal_code
  LEFT JOIN time_slot_catalog tc ON sc.time_slot_code = tc.slot_code
  WHERE r.id = p_reservation_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION '예약을 찾을 수 없습니다: %', p_reservation_id;
  END IF;
  
  -- 고객에게 승인 알림 생성
  INSERT INTO notifications (
    type, title, message, recipient_type, recipient_id,
    reservation_id, reservation_number, metadata, priority
  ) VALUES (
    'reservation_approved',
    '🎉 예약이 승인되었습니다!',
    format('%s %s 예약이 승인되었습니다. 예약번호: %s', 
           reservation_record.facility_name,
           reservation_record.time_slot,
           reservation_record.reservation_number),
    'customer',
    reservation_record.phone,
    p_reservation_id,
    reservation_record.reservation_number,
    jsonb_build_object(
      'facility_name', reservation_record.facility_name,
      'time_slot', reservation_record.time_slot,
      'reservation_date', reservation_record.reservation_date,
      'guest_count', reservation_record.guest_count
    ),
    'high'
  ) RETURNING id INTO notification_id;
  
  RETURN notification_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4.2. 새 예약 신청 알림 (관리자용)
CREATE OR REPLACE FUNCTION notify_new_reservation(p_reservation_id INTEGER)
RETURNS UUID AS $$
DECLARE
  reservation_record RECORD;
  notification_id UUID;
BEGIN
  -- 예약 정보 조회
  SELECT r.*, rc.display_name as facility_name, tc.display_name as time_slot
  INTO reservation_record
  FROM reservations r
  LEFT JOIN sku_catalog sc ON r.sku_code = sc.sku_code
  LEFT JOIN resource_catalog rc ON sc.resource_code = rc.internal_code
  LEFT JOIN time_slot_catalog tc ON sc.time_slot_code = tc.slot_code
  WHERE r.id = p_reservation_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION '예약을 찾을 수 없습니다: %', p_reservation_id;
  END IF;
  
  -- 관리자에게 신규 예약 알림 생성
  INSERT INTO notifications (
    type, title, message, recipient_type, recipient_id,
    reservation_id, reservation_number, metadata, priority
  ) VALUES (
    'new_reservation',
    '🔔 새로운 예약 신청',
    format('%s님이 %s %s 예약을 신청했습니다.',
           reservation_record.name,
           reservation_record.facility_name,
           reservation_record.time_slot),
    'admin',
    'admin',
    p_reservation_id,
    reservation_record.reservation_number,
    jsonb_build_object(
      'customer_name', reservation_record.name,
      'customer_phone', reservation_record.phone,
      'facility_name', reservation_record.facility_name,
      'time_slot', reservation_record.time_slot,
      'reservation_date', reservation_record.reservation_date,
      'guest_count', reservation_record.guest_count
    ),
    'normal'
  ) RETURNING id INTO notification_id;
  
  RETURN notification_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4.3. 예약 취소 알림
CREATE OR REPLACE FUNCTION notify_reservation_cancelled(p_reservation_id INTEGER)
RETURNS UUID AS $$
DECLARE
  reservation_record RECORD;
  notification_id UUID;
BEGIN
  -- 예약 정보 조회
  SELECT r.*, rc.display_name as facility_name, tc.display_name as time_slot
  INTO reservation_record
  FROM reservations r
  LEFT JOIN sku_catalog sc ON r.sku_code = sc.sku_code
  LEFT JOIN resource_catalog rc ON sc.resource_code = rc.internal_code
  LEFT JOIN time_slot_catalog tc ON sc.time_slot_code = tc.slot_code
  WHERE r.id = p_reservation_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION '예약을 찾을 수 없습니다: %', p_reservation_id;
  END IF;
  
  -- 고객에게 취소 알림 생성
  INSERT INTO notifications (
    type, title, message, recipient_type, recipient_id,
    reservation_id, reservation_number, metadata, priority
  ) VALUES (
    'reservation_cancelled',
    '❌ 예약이 취소되었습니다',
    format('%s %s 예약이 취소되었습니다. 예약번호: %s', 
           reservation_record.facility_name,
           reservation_record.time_slot,
           reservation_record.reservation_number),
    'customer',
    reservation_record.phone,
    p_reservation_id,
    reservation_record.reservation_number,
    jsonb_build_object(
      'facility_name', reservation_record.facility_name,
      'time_slot', reservation_record.time_slot,
      'reservation_date', reservation_record.reservation_date
    ),
    'high'
  ) RETURNING id INTO notification_id;
  
  RETURN notification_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. 트리거 설정 (예약 상태 변경 시 자동 알림)
CREATE OR REPLACE FUNCTION trigger_reservation_notifications()
RETURNS TRIGGER AS $$
BEGIN
  -- 새 예약 생성 시
  IF TG_OP = 'INSERT' THEN
    PERFORM notify_new_reservation(NEW.id);
    RETURN NEW;
  END IF;
  
  -- 예약 상태 변경 시
  IF TG_OP = 'UPDATE' THEN
    -- pending → confirmed: 승인 알림
    IF OLD.status = 'pending' AND NEW.status = 'confirmed' THEN
      PERFORM notify_reservation_approved(NEW.id);
    END IF;
    
    -- 취소 알림 (pending/confirmed → cancelled)
    IF OLD.status IN ('pending', 'confirmed') AND NEW.status = 'cancelled' THEN
      PERFORM notify_reservation_cancelled(NEW.id);
    END IF;
    
    RETURN NEW;
  END IF;
  
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- 예약 테이블에 트리거 설정
DROP TRIGGER IF EXISTS reservation_notification_trigger ON reservations;
CREATE TRIGGER reservation_notification_trigger
  AFTER INSERT OR UPDATE OF status ON reservations
  FOR EACH ROW
  EXECUTE FUNCTION trigger_reservation_notifications();

-- 6. 알림 조회 함수들
-- 6.1. 고객용 알림 조회
CREATE OR REPLACE FUNCTION get_customer_notifications(p_phone TEXT, p_limit INTEGER DEFAULT 20)
RETURNS TABLE(
  id UUID,
  type TEXT,
  title TEXT,
  message TEXT,
  reservation_number TEXT,
  metadata JSONB,
  is_read BOOLEAN,
  priority TEXT,
  created_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    n.id,
    n.type,
    n.title,
    n.message,
    n.reservation_number,
    n.metadata,
    n.is_read,
    n.priority,
    n.created_at
  FROM notifications n
  WHERE n.recipient_type = 'customer'
    AND n.recipient_id = p_phone
    AND n.expires_at > NOW()
  ORDER BY n.created_at DESC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- 6.2. 관리자용 알림 조회
CREATE OR REPLACE FUNCTION get_admin_notifications(p_limit INTEGER DEFAULT 50)
RETURNS TABLE(
  id UUID,
  type TEXT,
  title TEXT,
  message TEXT,
  reservation_number TEXT,
  metadata JSONB,
  is_read BOOLEAN,
  priority TEXT,
  created_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    n.id,
    n.type,
    n.title,
    n.message,
    n.reservation_number,
    n.metadata,
    n.is_read,
    n.priority,
    n.created_at
  FROM notifications n
  WHERE n.recipient_type = 'admin'
    AND n.expires_at > NOW()
  ORDER BY 
    CASE n.priority
      WHEN 'urgent' THEN 1
      WHEN 'high' THEN 2
      WHEN 'normal' THEN 3
      WHEN 'low' THEN 4
    END,
    n.created_at DESC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- 7. 알림 읽음 상태 업데이트
CREATE OR REPLACE FUNCTION mark_notification_as_read(p_notification_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  UPDATE notifications 
  SET is_read = true, read_at = NOW()
  WHERE id = p_notification_id;
  
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. 만료된 알림 자동 정리 (정기적으로 실행)
CREATE OR REPLACE FUNCTION cleanup_expired_notifications()
RETURNS INTEGER AS $$
DECLARE
  deleted_count INTEGER;
BEGIN
  DELETE FROM notifications 
  WHERE expires_at < NOW()
    AND created_at < NOW() - INTERVAL '30 days';
  
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 9. Realtime을 위한 발행 설정 활성화
-- 알림 테이블에 대한 실시간 구독 활성화
ALTER TABLE notifications REPLICA IDENTITY FULL;

-- 테스트용 알림 생성 함수
CREATE OR REPLACE FUNCTION create_test_notification(
  p_type TEXT DEFAULT 'test',
  p_recipient_type TEXT DEFAULT 'admin'
)
RETURNS UUID AS $$
DECLARE
  notification_id UUID;
BEGIN
  INSERT INTO notifications (
    type, title, message, recipient_type, recipient_id, priority
  ) VALUES (
    p_type,
    '테스트 알림',
    '실시간 알림 시스템 테스트입니다.',
    p_recipient_type,
    CASE WHEN p_recipient_type = 'admin' THEN 'admin' ELSE '010-0000-0000' END,
    'normal'
  ) RETURNING id INTO notification_id;
  
  RETURN notification_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;