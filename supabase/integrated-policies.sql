-- RLS Policies for Integrated OSO Camping BBQ System
-- 통합 스키마용 보안 정책 설정

-- ============================================
-- RLS 활성화
-- ============================================

ALTER TABLE public.resource_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.time_slot_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sku_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reservations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.availability ENABLE ROW LEVEL SECURITY;

-- ============================================
-- 기존 정책 삭제 (있다면)
-- ============================================

DO $$ 
BEGIN
  -- Resource Catalog 정책 삭제
  EXECUTE 'DROP POLICY IF EXISTS resource_catalog_select_all ON public.resource_catalog';
  EXECUTE 'DROP POLICY IF EXISTS resource_catalog_insert_all ON public.resource_catalog';
  EXECUTE 'DROP POLICY IF EXISTS resource_catalog_update_all ON public.resource_catalog';
  EXECUTE 'DROP POLICY IF EXISTS resource_catalog_delete_all ON public.resource_catalog';
  
  -- Time Slot Catalog 정책 삭제
  EXECUTE 'DROP POLICY IF EXISTS time_slot_catalog_select_all ON public.time_slot_catalog';
  EXECUTE 'DROP POLICY IF EXISTS time_slot_catalog_insert_all ON public.time_slot_catalog';
  EXECUTE 'DROP POLICY IF EXISTS time_slot_catalog_update_all ON public.time_slot_catalog';
  EXECUTE 'DROP POLICY IF EXISTS time_slot_catalog_delete_all ON public.time_slot_catalog';
  
  -- SKU Catalog 정책 삭제
  EXECUTE 'DROP POLICY IF EXISTS sku_catalog_select_all ON public.sku_catalog';
  EXECUTE 'DROP POLICY IF EXISTS sku_catalog_insert_all ON public.sku_catalog';
  EXECUTE 'DROP POLICY IF EXISTS sku_catalog_update_all ON public.sku_catalog';
  EXECUTE 'DROP POLICY IF EXISTS sku_catalog_delete_all ON public.sku_catalog';
  
  -- Reservations 정책 삭제
  EXECUTE 'DROP POLICY IF EXISTS reservations_select_all ON public.reservations';
  EXECUTE 'DROP POLICY IF EXISTS reservations_insert_all ON public.reservations';
  EXECUTE 'DROP POLICY IF EXISTS reservations_update_all ON public.reservations';
  EXECUTE 'DROP POLICY IF EXISTS reservations_delete_all ON public.reservations';
  
  -- Bookings 정책 삭제
  EXECUTE 'DROP POLICY IF EXISTS bookings_select_all ON public.bookings';
  EXECUTE 'DROP POLICY IF EXISTS bookings_insert_all ON public.bookings';
  EXECUTE 'DROP POLICY IF EXISTS bookings_update_all ON public.bookings';
  EXECUTE 'DROP POLICY IF EXISTS bookings_delete_all ON public.bookings';
  
  -- Availability 정책 삭제
  EXECUTE 'DROP POLICY IF EXISTS availability_select_all ON public.availability';
  EXECUTE 'DROP POLICY IF EXISTS availability_insert_all ON public.availability';
  EXECUTE 'DROP POLICY IF EXISTS availability_update_all ON public.availability';
  EXECUTE 'DROP POLICY IF EXISTS availability_delete_all ON public.availability';
  
EXCEPTION WHEN OTHERS THEN 
  NULL;
END $$;

-- ============================================
-- 개발용 정책 (모든 익명 사용자 허용)
-- ============================================

-- Resource Catalog 정책
CREATE POLICY resource_catalog_select_all ON public.resource_catalog FOR SELECT USING (true);
CREATE POLICY resource_catalog_insert_all ON public.resource_catalog FOR INSERT WITH CHECK (true);
CREATE POLICY resource_catalog_update_all ON public.resource_catalog FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY resource_catalog_delete_all ON public.resource_catalog FOR DELETE USING (true);

-- Time Slot Catalog 정책
CREATE POLICY time_slot_catalog_select_all ON public.time_slot_catalog FOR SELECT USING (true);
CREATE POLICY time_slot_catalog_insert_all ON public.time_slot_catalog FOR INSERT WITH CHECK (true);
CREATE POLICY time_slot_catalog_update_all ON public.time_slot_catalog FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY time_slot_catalog_delete_all ON public.time_slot_catalog FOR DELETE USING (true);

-- SKU Catalog 정책
CREATE POLICY sku_catalog_select_all ON public.sku_catalog FOR SELECT USING (true);
CREATE POLICY sku_catalog_insert_all ON public.sku_catalog FOR INSERT WITH CHECK (true);
CREATE POLICY sku_catalog_update_all ON public.sku_catalog FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY sku_catalog_delete_all ON public.sku_catalog FOR DELETE USING (true);

-- Reservations 정책
CREATE POLICY reservations_select_all ON public.reservations FOR SELECT USING (true);
CREATE POLICY reservations_insert_all ON public.reservations FOR INSERT WITH CHECK (true);
CREATE POLICY reservations_update_all ON public.reservations FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY reservations_delete_all ON public.reservations FOR DELETE USING (true);

-- Bookings 정책
CREATE POLICY bookings_select_all ON public.bookings FOR SELECT USING (true);
CREATE POLICY bookings_insert_all ON public.bookings FOR INSERT WITH CHECK (true);
CREATE POLICY bookings_update_all ON public.bookings FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY bookings_delete_all ON public.bookings FOR DELETE USING (true);

-- Availability 정책
CREATE POLICY availability_select_all ON public.availability FOR SELECT USING (true);
CREATE POLICY availability_insert_all ON public.availability FOR INSERT WITH CHECK (true);
CREATE POLICY availability_update_all ON public.availability FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY availability_delete_all ON public.availability FOR DELETE USING (true);