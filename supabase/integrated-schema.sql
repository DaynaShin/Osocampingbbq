-- Integrated Schema for OSO Camping BBQ Reservation System
-- 기존 OSO 카탈로그 시스템 + 예약 시스템 통합
-- Supabase SQL Editor에서 실행

BEGIN;

-- UUID 확장 설치
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- OSO CAMPING BBQ 카탈로그 시스템
-- ============================================

-- 자원 카탈로그 (장소 정보)
CREATE TABLE IF NOT EXISTS public.resource_catalog (
  internal_code TEXT PRIMARY KEY,
  category_code TEXT NOT NULL, -- PR, ST, TN, VP, YT
  label TEXT,
  display_name TEXT NOT NULL,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  price INTEGER DEFAULT 0, -- 기본 요금 (추가)
  max_guests INTEGER DEFAULT 4, -- 최대 수용 인원 (추가)
  description TEXT, -- 설명 (추가)
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  CHECK (internal_code ~ '^[A-Z]{2}[0-9]{2}$')
);

-- 타임슬롯 카탈로그 (시간대 정보)
CREATE TABLE IF NOT EXISTS public.time_slot_catalog (
  slot_id TEXT PRIMARY KEY,
  part_name TEXT NOT NULL, -- 1부, 2부, 3부
  slot_name TEXT NOT NULL, -- 타임1, 타임2, 타임3
  start_local TIME NOT NULL,
  end_local TIME NOT NULL,
  duration_minutes INTEGER, -- 소요시간 (분) (추가)
  price_multiplier DECIMAL(3,2) DEFAULT 1.0, -- 시간대별 요금 배수 (추가)
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- SKU 카탈로그 (예약 가능한 슬롯 조합)
CREATE TABLE IF NOT EXISTS public.sku_catalog (
  sku_code TEXT PRIMARY KEY,
  internal_code TEXT NOT NULL REFERENCES public.resource_catalog(internal_code) ON DELETE CASCADE,
  slot_id TEXT NOT NULL REFERENCES public.time_slot_catalog(slot_id) ON DELETE CASCADE,
  active BOOLEAN DEFAULT TRUE, -- 예약 가능 여부 (추가)
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  CHECK (sku_code ~ '^[A-Z]{2}[0-9]{2}-T[123]$')
);

-- ============================================
-- 예약 관리 시스템
-- ============================================

-- 예약 신청 테이블 (기존 reservations 개선)
CREATE TABLE IF NOT EXISTS public.reservations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  phone TEXT NOT NULL,
  email TEXT,
  reservation_date DATE NOT NULL,
  sku_code TEXT REFERENCES public.sku_catalog(sku_code), -- OSO SKU와 연결
  guest_count INTEGER DEFAULT 1,
  special_requests TEXT,
  status TEXT NOT NULL DEFAULT 'pending', -- pending | confirmed | cancelled
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 실제 예약 현황 테이블 (기존 bookings 개선)  
CREATE TABLE IF NOT EXISTS public.bookings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  customer_name TEXT NOT NULL,
  customer_phone TEXT NOT NULL,
  customer_email TEXT,
  booking_date DATE NOT NULL,
  sku_code TEXT NOT NULL REFERENCES public.sku_catalog(sku_code), -- OSO SKU와 연결
  guest_count INTEGER NOT NULL DEFAULT 1,
  base_price INTEGER NOT NULL, -- 기본 요금
  total_amount INTEGER NOT NULL, -- 최종 결제 금액
  status TEXT NOT NULL DEFAULT 'confirmed', -- pending | confirmed | cancelled | completed | no_show
  special_requests TEXT,
  check_in_time TIMESTAMP WITH TIME ZONE, -- 실제 입장 시간 (추가)
  check_out_time TIMESTAMP WITH TIME ZONE, -- 실제 퇴장 시간 (추가)
  payment_method TEXT, -- 결제 방법 (추가)
  payment_status TEXT DEFAULT 'pending', -- 결제 상태 (추가)
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 날짜별 가용성 관리 테이블 (새로 추가)
CREATE TABLE IF NOT EXISTS public.availability (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  sku_code TEXT NOT NULL REFERENCES public.sku_catalog(sku_code),
  date DATE NOT NULL,
  available_slots INTEGER DEFAULT 1, -- 해당 날짜/SKU의 가용 슬롯 수
  booked_slots INTEGER DEFAULT 0, -- 예약된 슬롯 수
  blocked BOOLEAN DEFAULT FALSE, -- 관리자가 차단한 경우
  block_reason TEXT, -- 차단 사유
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(sku_code, date)
);

-- ============================================
-- 인덱스 생성
-- ============================================

-- 자원 카탈로그 인덱스
CREATE INDEX IF NOT EXISTS idx_resource_catalog_category ON public.resource_catalog(category_code);
CREATE INDEX IF NOT EXISTS idx_resource_catalog_active ON public.resource_catalog(active);

-- 예약 인덱스
CREATE INDEX IF NOT EXISTS idx_reservations_date ON public.reservations(reservation_date);
CREATE INDEX IF NOT EXISTS idx_reservations_status ON public.reservations(status);
CREATE INDEX IF NOT EXISTS idx_reservations_sku ON public.reservations(sku_code);

-- 예약현황 인덱스
CREATE INDEX IF NOT EXISTS idx_bookings_date ON public.bookings(booking_date);
CREATE INDEX IF NOT EXISTS idx_bookings_status ON public.bookings(status);
CREATE INDEX IF NOT EXISTS idx_bookings_sku ON public.bookings(sku_code);

-- 가용성 인덱스
CREATE INDEX IF NOT EXISTS idx_availability_date ON public.availability(date);
CREATE INDEX IF NOT EXISTS idx_availability_sku_date ON public.availability(sku_code, date);

-- ============================================
-- 트리거 함수 및 트리거
-- ============================================

-- updated_at 자동 업데이트 함수
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 트리거 생성
DROP TRIGGER IF EXISTS resource_catalog_updated_at ON public.resource_catalog;
CREATE TRIGGER resource_catalog_updated_at
  BEFORE UPDATE ON public.resource_catalog
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS reservations_updated_at ON public.reservations;
CREATE TRIGGER reservations_updated_at
  BEFORE UPDATE ON public.reservations
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS bookings_updated_at ON public.bookings;
CREATE TRIGGER bookings_updated_at
  BEFORE UPDATE ON public.bookings
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS availability_updated_at ON public.availability;
CREATE TRIGGER availability_updated_at
  BEFORE UPDATE ON public.availability
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============================================
-- 유용한 뷰 생성
-- ============================================

-- 예약 가능한 슬롯 뷰 (자주 사용되는 조합)
CREATE OR REPLACE VIEW public.available_slots AS
SELECT 
  s.sku_code,
  r.internal_code,
  r.category_code,
  r.display_name as resource_name,
  r.price as base_price,
  r.max_guests,
  t.slot_name,
  t.part_name,
  t.start_local,
  t.end_local,
  t.duration_minutes,
  s.active
FROM public.sku_catalog s
JOIN public.resource_catalog r ON s.internal_code = r.internal_code
JOIN public.time_slot_catalog t ON s.slot_id = t.slot_id
WHERE s.active = TRUE AND r.active = TRUE;

-- 예약 상세 뷰
CREATE OR REPLACE VIEW public.reservation_details AS
SELECT 
  res.*,
  r.category_code,
  r.display_name as resource_name,
  t.slot_name,
  t.start_local,
  t.end_local,
  r.price as base_price
FROM public.reservations res
LEFT JOIN public.sku_catalog s ON res.sku_code = s.sku_code
LEFT JOIN public.resource_catalog r ON s.internal_code = r.internal_code
LEFT JOIN public.time_slot_catalog t ON s.slot_id = t.slot_id;

-- 예약현황 상세 뷰
CREATE OR REPLACE VIEW public.booking_details AS
SELECT 
  b.*,
  r.category_code,
  r.display_name as resource_name,
  t.slot_name,
  t.start_local,
  t.end_local
FROM public.bookings b
JOIN public.sku_catalog s ON b.sku_code = s.sku_code
JOIN public.resource_catalog r ON s.internal_code = r.internal_code
JOIN public.time_slot_catalog t ON s.slot_id = t.slot_id;

COMMIT;