-- Phase 3.2: SMS/이메일 자동 발송 시스템 구현
-- 작성일: 2025년
-- 목표: 예약 승인/변경/취소 시 자동 SMS/이메일 발송

-- 1. 메시지 템플릿 테이블
CREATE TABLE IF NOT EXISTS message_templates (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  template_code TEXT NOT NULL UNIQUE, -- 'reservation_confirmed', 'reservation_cancelled', 'reminder_1day'
  template_name TEXT NOT NULL,
  message_type TEXT NOT NULL, -- 'sms', 'email', 'both'
  subject TEXT, -- 이메일용 제목 (SMS는 null)
  content TEXT NOT NULL, -- 메시지 내용 (변수 치환 가능: {customer_name}, {facility_name} 등)
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. 메시지 발송 기록 테이블
CREATE TABLE IF NOT EXISTS message_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  reservation_id INTEGER REFERENCES reservations(id),
  reservation_number TEXT,
  message_type TEXT NOT NULL, -- 'sms', 'email'
  recipient_phone TEXT,
  recipient_email TEXT,
  template_code TEXT REFERENCES message_templates(template_code),
  subject TEXT, -- 실제 발송된 제목
  content TEXT NOT NULL, -- 실제 발송된 내용 (변수 치환 완료)
  status TEXT DEFAULT 'pending', -- 'pending', 'sent', 'failed', 'delivered'
  provider_response JSONB, -- Twilio, SendGrid 응답 데이터
  sent_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  failed_at TIMESTAMPTZ,
  error_message TEXT,
  retry_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. 인덱스 추가 (성능 최적화)
CREATE INDEX IF NOT EXISTS idx_message_templates_code 
ON message_templates(template_code, is_active);

CREATE INDEX IF NOT EXISTS idx_message_logs_reservation 
ON message_logs(reservation_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_message_logs_status 
ON message_logs(status, created_at);

CREATE INDEX IF NOT EXISTS idx_message_logs_phone 
ON message_logs(recipient_phone, created_at DESC);

-- 4. RLS (Row Level Security) 정책 설정
ALTER TABLE message_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE message_logs ENABLE ROW LEVEL SECURITY;

-- 템플릿은 관리자만 조회/수정 가능
CREATE POLICY "admins_can_manage_templates" ON message_templates
FOR ALL USING (true) WITH CHECK (true);

-- 로그는 시스템에서만 생성, 관리자는 조회 가능
CREATE POLICY "system_can_create_logs" ON message_logs
FOR INSERT WITH CHECK (true);

CREATE POLICY "admins_can_view_logs" ON message_logs
FOR SELECT USING (true);

-- 5. 기본 메시지 템플릿 삽입
INSERT INTO message_templates (template_code, template_name, message_type, subject, content) VALUES
('reservation_confirmed_sms', '예약 승인 SMS', 'sms', NULL, 
 '🎉 OSO캠핑장 예약이 승인되었습니다!\n예약번호: {reservation_number}\n시설: {facility_name}\n날짜: {reservation_date}\n인원: {guest_count}명\n문의: 010-0000-0000'),

('reservation_confirmed_email', '예약 승인 이메일', 'email', 'OSO캠핑장 예약 승인 안내', 
 '안녕하세요 {customer_name}님,\n\nOSO캠핑장 예약이 정상적으로 승인되었습니다.\n\n📋 예약 상세 정보\n• 예약번호: {reservation_number}\n• 예약자: {customer_name}\n• 연락처: {customer_phone}\n• 시설명: {facility_name}\n• 예약일: {reservation_date}\n• 이용 인원: {guest_count}명\n• 총 결제금액: {total_price}원\n\n즐거운 캠핑 되세요!\n\n문의사항이 있으시면 언제든지 연락 부탁드립니다.\n감사합니다.\n\nOSO캠핑장\n연락처: 010-0000-0000'),

('reservation_cancelled_sms', '예약 취소 SMS', 'sms', NULL,
 '❌ OSO캠핑장 예약이 취소되었습니다.\n예약번호: {reservation_number}\n취소 사유: {cancellation_reason}\n문의: 010-0000-0000'),

('reservation_cancelled_email', '예약 취소 이메일', 'email', 'OSO캠핑장 예약 취소 안내',
 '안녕하세요 {customer_name}님,\n\nOSO캠핑장 예약이 취소되었음을 안내드립니다.\n\n📋 취소된 예약 정보\n• 예약번호: {reservation_number}\n• 시설명: {facility_name}\n• 예약일: {reservation_date}\n• 취소 사유: {cancellation_reason}\n\n기타 문의사항이 있으시면 언제든지 연락 부탁드립니다.\n\nOSO캠핑장\n연락처: 010-0000-0000'),

('reminder_1day_sms', '1일전 리마인더 SMS', 'sms', NULL,
 '📅 내일은 OSO캠핑장 이용일입니다!\n예약번호: {reservation_number}\n시설: {facility_name}\n체크인: {checkin_time}\n즐거운 캠핑 되세요! 🏕️'),

('reminder_1day_email', '1일전 리마인더 이메일', 'email', 'OSO캠핑장 이용 안내 (내일 체크인)',
 '안녕하세요 {customer_name}님,\n\n내일은 OSO캠핑장 이용일입니다! 🏕️\n\n📋 예약 정보 확인\n• 예약번호: {reservation_number}\n• 시설명: {facility_name}\n• 이용일: {reservation_date}\n• 체크인 시간: {checkin_time}\n• 인원: {guest_count}명\n\n⚠️ 체크인 안내\n• 체크인 시간을 꼭 확인해주세요\n• 신분증을 지참해주세요\n• 추가 인원은 현장에서 별도 결제가 필요합니다\n\n즐거운 캠핑 되세요!\n\nOSO캠핑장\n연락처: 010-0000-0000');

-- 6. 메시지 발송 함수들
-- 6.1. 변수 치환 함수
CREATE OR REPLACE FUNCTION replace_message_variables(
  template_content TEXT,
  p_reservation_id INTEGER
) RETURNS TEXT AS $$
DECLARE
  reservation_data RECORD;
  result_content TEXT;
BEGIN
  -- 예약 정보 조회
  SELECT 
    r.reservation_number,
    r.name as customer_name,
    r.phone as customer_phone,
    r.email as customer_email,
    r.reservation_date,
    r.guest_count,
    r.total_price,
    r.status,
    rc.display_name as facility_name,
    tc.display_name as time_slot,
    CASE 
      WHEN tc.slot_code LIKE '%morning%' THEN '09:00'
      WHEN tc.slot_code LIKE '%afternoon%' THEN '14:00'
      WHEN tc.slot_code LIKE '%evening%' THEN '18:00'
      ELSE '체크인 시간 확인'
    END as checkin_time
  INTO reservation_data
  FROM reservations r
  LEFT JOIN sku_catalog sc ON r.sku_code = sc.sku_code
  LEFT JOIN resource_catalog rc ON sc.resource_code = rc.internal_code
  LEFT JOIN time_slot_catalog tc ON sc.time_slot_code = tc.slot_code
  WHERE r.id = p_reservation_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION '예약을 찾을 수 없습니다: %', p_reservation_id;
  END IF;
  
  -- 변수 치환
  result_content := template_content;
  result_content := REPLACE(result_content, '{reservation_number}', COALESCE(reservation_data.reservation_number, ''));
  result_content := REPLACE(result_content, '{customer_name}', COALESCE(reservation_data.customer_name, ''));
  result_content := REPLACE(result_content, '{customer_phone}', COALESCE(reservation_data.customer_phone, ''));
  result_content := REPLACE(result_content, '{customer_email}', COALESCE(reservation_data.customer_email, ''));
  result_content := REPLACE(result_content, '{facility_name}', COALESCE(reservation_data.facility_name, ''));
  result_content := REPLACE(result_content, '{time_slot}', COALESCE(reservation_data.time_slot, ''));
  result_content := REPLACE(result_content, '{reservation_date}', COALESCE(reservation_data.reservation_date::TEXT, ''));
  result_content := REPLACE(result_content, '{guest_count}', COALESCE(reservation_data.guest_count::TEXT, ''));
  result_content := REPLACE(result_content, '{total_price}', COALESCE(FORMAT('%s', reservation_data.total_price), ''));
  result_content := REPLACE(result_content, '{checkin_time}', COALESCE(reservation_data.checkin_time, ''));
  result_content := REPLACE(result_content, '{cancellation_reason}', '관리자 요청');
  
  RETURN result_content;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- 6.2. SMS 발송 요청 함수
CREATE OR REPLACE FUNCTION send_sms_message(
  p_reservation_id INTEGER,
  p_template_code TEXT,
  p_phone TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  template_record RECORD;
  reservation_record RECORD;
  message_content TEXT;
  message_subject TEXT;
  log_id UUID;
  target_phone TEXT;
BEGIN
  -- 템플릿 조회
  SELECT * INTO template_record
  FROM message_templates 
  WHERE template_code = p_template_code 
    AND is_active = true
    AND message_type IN ('sms', 'both');
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'SMS 템플릿을 찾을 수 없습니다: %', p_template_code;
  END IF;
  
  -- 예약 정보 조회
  SELECT phone, reservation_number INTO reservation_record
  FROM reservations WHERE id = p_reservation_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION '예약을 찾을 수 없습니다: %', p_reservation_id;
  END IF;
  
  -- 전화번호 결정 (파라미터 우선, 없으면 예약자 전화번호)
  target_phone := COALESCE(p_phone, reservation_record.phone);
  
  IF target_phone IS NULL THEN
    RAISE EXCEPTION '전화번호가 없습니다';
  END IF;
  
  -- 메시지 내용 변수 치환
  message_content := replace_message_variables(template_record.content, p_reservation_id);
  message_subject := replace_message_variables(COALESCE(template_record.subject, ''), p_reservation_id);
  
  -- 발송 로그 생성
  INSERT INTO message_logs (
    reservation_id, reservation_number, message_type, recipient_phone,
    template_code, subject, content, status
  ) VALUES (
    p_reservation_id, reservation_record.reservation_number, 'sms', target_phone,
    p_template_code, message_subject, message_content, 'pending'
  ) RETURNING id INTO log_id;
  
  -- 실제 SMS 발송은 외부 서비스(Twilio)에서 처리
  -- 여기서는 발송 요청만 기록
  
  RETURN log_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6.3. 이메일 발송 요청 함수
CREATE OR REPLACE FUNCTION send_email_message(
  p_reservation_id INTEGER,
  p_template_code TEXT,
  p_email TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  template_record RECORD;
  reservation_record RECORD;
  message_content TEXT;
  message_subject TEXT;
  log_id UUID;
  target_email TEXT;
BEGIN
  -- 템플릿 조회
  SELECT * INTO template_record
  FROM message_templates 
  WHERE template_code = p_template_code 
    AND is_active = true
    AND message_type IN ('email', 'both');
  
  IF NOT FOUND THEN
    RAISE EXCEPTION '이메일 템플릿을 찾을 수 없습니다: %', p_template_code;
  END IF;
  
  -- 예약 정보 조회
  SELECT email, reservation_number INTO reservation_record
  FROM reservations WHERE id = p_reservation_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION '예약을 찾을 수 없습니다: %', p_reservation_id;
  END IF;
  
  -- 이메일 주소 결정 (파라미터 우선, 없으면 예약자 이메일)
  target_email := COALESCE(p_email, reservation_record.email);
  
  IF target_email IS NULL THEN
    RAISE EXCEPTION '이메일 주소가 없습니다';
  END IF;
  
  -- 메시지 내용 변수 치환
  message_content := replace_message_variables(template_record.content, p_reservation_id);
  message_subject := replace_message_variables(COALESCE(template_record.subject, 'OSO캠핑장 안내'), p_reservation_id);
  
  -- 발송 로그 생성
  INSERT INTO message_logs (
    reservation_id, reservation_number, message_type, recipient_email,
    template_code, subject, content, status
  ) VALUES (
    p_reservation_id, reservation_record.reservation_number, 'email', target_email,
    p_template_code, message_subject, message_content, 'pending'
  ) RETURNING id INTO log_id;
  
  -- 실제 이메일 발송은 외부 서비스(SendGrid)에서 처리
  -- 여기서는 발송 요청만 기록
  
  RETURN log_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6.4. 통합 메시지 발송 함수 (SMS + 이메일)
CREATE OR REPLACE FUNCTION send_reservation_message(
  p_reservation_id INTEGER,
  p_template_code TEXT,
  p_send_sms BOOLEAN DEFAULT true,
  p_send_email BOOLEAN DEFAULT true
) RETURNS JSONB AS $$
DECLARE
  sms_log_id UUID;
  email_log_id UUID;
  result JSONB := '{}';
BEGIN
  -- SMS 발송
  IF p_send_sms THEN
    BEGIN
      sms_log_id := send_sms_message(p_reservation_id, p_template_code || '_sms');
      result := result || jsonb_build_object('sms_log_id', sms_log_id);
    EXCEPTION WHEN OTHERS THEN
      result := result || jsonb_build_object('sms_error', SQLERRM);
    END;
  END IF;
  
  -- 이메일 발송
  IF p_send_email THEN
    BEGIN
      email_log_id := send_email_message(p_reservation_id, p_template_code || '_email');
      result := result || jsonb_build_object('email_log_id', email_log_id);
    EXCEPTION WHEN OTHERS THEN
      result := result || jsonb_build_object('email_error', SQLERRM);
    END;
  END IF;
  
  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. 발송 상태 업데이트 함수들
CREATE OR REPLACE FUNCTION update_message_status(
  p_log_id UUID,
  p_status TEXT,
  p_provider_response JSONB DEFAULT NULL,
  p_error_message TEXT DEFAULT NULL
) RETURNS BOOLEAN AS $$
BEGIN
  UPDATE message_logs SET
    status = p_status,
    provider_response = COALESCE(p_provider_response, provider_response),
    error_message = p_error_message,
    sent_at = CASE WHEN p_status = 'sent' THEN NOW() ELSE sent_at END,
    delivered_at = CASE WHEN p_status = 'delivered' THEN NOW() ELSE delivered_at END,
    failed_at = CASE WHEN p_status = 'failed' THEN NOW() ELSE failed_at END,
    retry_count = CASE WHEN p_status = 'failed' THEN retry_count + 1 ELSE retry_count END
  WHERE id = p_log_id;
  
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. 트리거 함수 - 예약 상태 변경 시 자동 메시지 발송
CREATE OR REPLACE FUNCTION trigger_reservation_messages()
RETURNS TRIGGER AS $$
DECLARE
  message_result JSONB;
BEGIN
  -- 예약 승인 시 확인 메시지 발송
  IF TG_OP = 'UPDATE' AND OLD.status = 'pending' AND NEW.status = 'confirmed' THEN
    SELECT send_reservation_message(NEW.id, 'reservation_confirmed') INTO message_result;
    -- 알림 시스템과 연동
    PERFORM notify_reservation_approved(NEW.id);
  END IF;
  
  -- 예약 취소 시 취소 메시지 발송
  IF TG_OP = 'UPDATE' AND OLD.status IN ('pending', 'confirmed') AND NEW.status = 'cancelled' THEN
    SELECT send_reservation_message(NEW.id, 'reservation_cancelled') INTO message_result;
    -- 알림 시스템과 연동
    PERFORM notify_reservation_cancelled(NEW.id);
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 기존 예약 트리거에 메시지 발송 기능 추가
DROP TRIGGER IF EXISTS reservation_message_trigger ON reservations;
CREATE TRIGGER reservation_message_trigger
  AFTER UPDATE OF status ON reservations
  FOR EACH ROW
  EXECUTE FUNCTION trigger_reservation_messages();

-- 9. 리마인더 발송을 위한 함수
CREATE OR REPLACE FUNCTION send_daily_reminders()
RETURNS INTEGER AS $$
DECLARE
  reservation_record RECORD;
  sent_count INTEGER := 0;
BEGIN
  -- 내일 체크인 예약 중 confirmed 상태인 것들
  FOR reservation_record IN
    SELECT id, reservation_date, name, phone
    FROM reservations 
    WHERE status = 'confirmed'
      AND reservation_date = CURRENT_DATE + INTERVAL '1 day'
      AND id NOT IN (
        SELECT DISTINCT reservation_id 
        FROM message_logs 
        WHERE template_code IN ('reminder_1day_sms', 'reminder_1day_email')
          AND created_at::date = CURRENT_DATE
      )
  LOOP
    -- 리마인더 메시지 발송
    PERFORM send_reservation_message(
      reservation_record.id, 
      'reminder_1day',
      true,  -- SMS 발송
      true   -- 이메일 발송 (이메일 주소가 있는 경우)
    );
    
    sent_count := sent_count + 1;
  END LOOP;
  
  RETURN sent_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 10. 발송 실패 메시지 재발송 함수
CREATE OR REPLACE FUNCTION retry_failed_messages(p_max_retries INTEGER DEFAULT 3)
RETURNS INTEGER AS $$
DECLARE
  retry_count INTEGER := 0;
  log_record RECORD;
BEGIN
  FOR log_record IN
    SELECT id, reservation_id, template_code
    FROM message_logs
    WHERE status = 'failed'
      AND retry_count < p_max_retries
      AND created_at > NOW() - INTERVAL '24 hours'
  LOOP
    -- 재발송 시도
    IF log_record.template_code LIKE '%_sms' THEN
      PERFORM send_sms_message(log_record.reservation_id, log_record.template_code);
    ELSIF log_record.template_code LIKE '%_email' THEN
      PERFORM send_email_message(log_record.reservation_id, log_record.template_code);
    END IF;
    
    retry_count := retry_count + 1;
  END LOOP;
  
  RETURN retry_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 11. 조회 함수들
-- 발송 로그 조회 (관리자용)
CREATE OR REPLACE FUNCTION get_message_logs(
  p_limit INTEGER DEFAULT 50,
  p_status TEXT DEFAULT NULL,
  p_message_type TEXT DEFAULT NULL
) RETURNS TABLE(
  id UUID,
  reservation_number TEXT,
  message_type TEXT,
  recipient_phone TEXT,
  recipient_email TEXT,
  template_code TEXT,
  subject TEXT,
  status TEXT,
  sent_at TIMESTAMPTZ,
  error_message TEXT,
  retry_count INTEGER,
  created_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ml.id,
    ml.reservation_number,
    ml.message_type,
    ml.recipient_phone,
    ml.recipient_email,
    ml.template_code,
    ml.subject,
    ml.status,
    ml.sent_at,
    ml.error_message,
    ml.retry_count,
    ml.created_at
  FROM message_logs ml
  WHERE (p_status IS NULL OR ml.status = p_status)
    AND (p_message_type IS NULL OR ml.message_type = p_message_type)
  ORDER BY ml.created_at DESC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- 12. 테스트 함수
CREATE OR REPLACE FUNCTION test_message_system(p_reservation_id INTEGER)
RETURNS TEXT AS $$
DECLARE
  result TEXT := '';
  sms_result UUID;
  email_result UUID;
BEGIN
  -- SMS 테스트
  BEGIN
    sms_result := send_sms_message(p_reservation_id, 'reservation_confirmed_sms');
    result := result || format('SMS 발송 요청 성공: %s\n', sms_result);
  EXCEPTION WHEN OTHERS THEN
    result := result || format('SMS 발송 실패: %s\n', SQLERRM);
  END;
  
  -- 이메일 테스트
  BEGIN
    email_result := send_email_message(p_reservation_id, 'reservation_confirmed_email');
    result := result || format('이메일 발송 요청 성공: %s\n', email_result);
  EXCEPTION WHEN OTHERS THEN
    result := result || format('이메일 발송 실패: %s\n', SQLERRM);
  END;
  
  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;