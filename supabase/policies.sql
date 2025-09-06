-- Secure RLS policies for OSO Camping BBQ System
-- This is the single source of truth for RLS policies.
-- These policies are designed for a production environment where admin
-- actions are routed through a secure backend service using the 'service_role' key.

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
  EXECUTE 'DROP POLICY IF EXISTS resource_catalog_select_public ON public.resource_catalog';
  EXECUTE 'DROP POLICY IF EXISTS resource_catalog_manage_admin ON public.resource_catalog';
  
  -- Time Slot Catalog 정책 삭제
  EXECUTE 'DROP POLICY IF EXISTS time_slot_catalog_select_public ON public.time_slot_catalog';
  EXECUTE 'DROP POLICY IF EXISTS time_slot_catalog_manage_admin ON public.time_slot_catalog';
  
  -- SKU Catalog 정책 삭제
  EXECUTE 'DROP POLICY IF EXISTS sku_catalog_select_public ON public.sku_catalog';
  EXECUTE 'DROP POLICY IF EXISTS sku_catalog_manage_admin ON public.sku_catalog';
  
  -- Reservations 정책 삭제
  EXECUTE 'DROP POLICY IF EXISTS reservations_select_public ON public.reservations';
  EXECUTE 'DROP POLICY IF EXISTS reservations_insert_public ON public.reservations';
  EXECUTE 'DROP POLICY IF EXISTS reservations_update_admin ON public.reservations';
  EXECUTE 'DROP POLICY IF EXISTS reservations_delete_admin ON public.reservations';
  
  -- Bookings 정책 삭제
  EXECUTE 'DROP POLICY IF EXISTS bookings_manage_admin ON public.bookings';
  
  -- Availability 정책 삭제
  EXECUTE 'DROP POLICY IF EXISTS availability_select_public ON public.availability';
  EXECUTE 'DROP POLICY IF EXISTS availability_manage_admin ON public.availability';
  
EXCEPTION WHEN OTHERS THEN 
  NULL;
END $$;

-- ============================================
-- 정책 정의
-- ============================================

-- Resource Catalog: Public can read, admin can manage.
CREATE POLICY resource_catalog_select_public ON public.resource_catalog FOR SELECT USING (true);
CREATE POLICY resource_catalog_manage_admin ON public.resource_catalog FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');

-- Time Slot Catalog: Public can read, admin can manage.
CREATE POLICY time_slot_catalog_select_public ON public.time_slot_catalog FOR SELECT USING (true);
CREATE POLICY time_slot_catalog_manage_admin ON public.time_slot_catalog FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');

-- SKU Catalog: Public can read, admin can manage.
CREATE POLICY sku_catalog_select_public ON public.sku_catalog FOR SELECT USING (true);
CREATE POLICY sku_catalog_manage_admin ON public.sku_catalog FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');

-- Reservations: Public can create and read, admin can update/delete.
CREATE POLICY reservations_select_public ON public.reservations FOR SELECT USING (true);
CREATE POLICY reservations_insert_public ON public.reservations FOR INSERT WITH CHECK (true);
CREATE POLICY reservations_update_admin ON public.reservations FOR UPDATE USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
CREATE POLICY reservations_delete_admin ON public.reservations FOR DELETE USING (auth.role() = 'service_role');

-- Bookings: Only admin can manage.
CREATE POLICY bookings_manage_admin ON public.bookings FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');

-- Availability: Public can read, admin can manage.
CREATE POLICY availability_select_public ON public.availability FOR SELECT USING (true);
CREATE POLICY availability_manage_admin ON public.availability FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
