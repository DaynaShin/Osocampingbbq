-- 관리자 페이지와 고객 계정 시스템 통합
-- 작성일: 2025년
-- 목표: 관리자 페이지에서 예약자 계정 정보 표시

-- 1. 관리자용 예약 조회 함수 (계정 정보 포함)
CREATE OR REPLACE FUNCTION get_admin_reservations_with_customer()
RETURNS TABLE(
    reservation_id INTEGER,
    reservation_number TEXT,
    reservation_date DATE,
    customer_name TEXT,
    customer_phone TEXT,
    customer_email TEXT,
    guest_count INTEGER,
    status TEXT,
    facility_name TEXT,
    facility_category TEXT,
    time_slot TEXT,
    total_amount INTEGER,
    special_requests TEXT,
    created_at TIMESTAMPTZ,
    -- 고객 계정 관련 정보
    has_customer_account BOOLEAN,
    account_type TEXT,
    customer_profile_id UUID,
    last_login_at TIMESTAMPTZ,
    total_reservations_count INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        r.id as reservation_id,
        r.reservation_number,
        r.reservation_date,
        r.name as customer_name,
        r.phone as customer_phone,
        r.email as customer_email,
        r.guest_count,
        r.status,
        rc.display_name as facility_name,
        rc.category_code as facility_category,
        tc.display_name as time_slot,
        COALESCE(r.total_amount, rc.price) as total_amount,
        r.special_requests,
        r.created_at,
        -- 계정 정보
        (cp.id IS NOT NULL) as has_customer_account,
        CASE 
            WHEN cp.password_hash IS NOT NULL THEN 'login_account'
            WHEN cp.id IS NOT NULL THEN 'simple_profile'
            ELSE 'no_account'
        END as account_type,
        cp.id as customer_profile_id,
        cp.last_login_at,
        -- 해당 고객의 총 예약 수
        COALESCE(customer_stats.total_count, 0) as total_reservations_count
    FROM reservations r
    LEFT JOIN sku_catalog sc ON r.sku_code = sc.sku_code
    LEFT JOIN resource_catalog rc ON sc.resource_code = rc.internal_code
    LEFT JOIN time_slot_catalog tc ON sc.time_slot_code = tc.slot_code
    LEFT JOIN customer_profiles cp ON r.customer_profile_id = cp.id
    LEFT JOIN (
        -- 고객별 예약 통계
        SELECT 
            customer_profile_id,
            COUNT(*) as total_count
        FROM reservations 
        WHERE customer_profile_id IS NOT NULL
        GROUP BY customer_profile_id
    ) customer_stats ON cp.id = customer_stats.customer_profile_id
    ORDER BY r.created_at DESC;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- 2. 관리자용 고객 프로필 요약 조회 함수
CREATE OR REPLACE FUNCTION get_customer_profiles_summary()
RETURNS TABLE(
    customer_id UUID,
    name TEXT,
    phone TEXT,
    email TEXT,
    account_type TEXT,
    total_reservations INTEGER,
    last_reservation_date DATE,
    last_login_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        cp.id as customer_id,
        cp.name,
        cp.phone,
        cp.email,
        CASE 
            WHEN cp.password_hash IS NOT NULL THEN 'login_account'
            ELSE 'simple_profile'
        END as account_type,
        COALESCE(stats.reservation_count, 0) as total_reservations,
        stats.last_reservation_date,
        cp.last_login_at,
        cp.created_at
    FROM customer_profiles cp
    LEFT JOIN (
        SELECT 
            customer_profile_id,
            COUNT(*) as reservation_count,
            MAX(reservation_date) as last_reservation_date
        FROM reservations 
        WHERE customer_profile_id IS NOT NULL
        GROUP BY customer_profile_id
    ) stats ON cp.id = stats.customer_profile_id
    ORDER BY cp.created_at DESC;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- 3. 계정 연결 상태 통계 함수
CREATE OR REPLACE FUNCTION get_customer_account_stats()
RETURNS TABLE(
    total_reservations INTEGER,
    reservations_with_account INTEGER,
    reservations_with_login_account INTEGER,
    reservations_without_account INTEGER,
    unique_customers INTEGER,
    customers_with_login_account INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) as total_reservations,
        COUNT(cp.id) as reservations_with_account,
        COUNT(CASE WHEN cp.password_hash IS NOT NULL THEN 1 END) as reservations_with_login_account,
        COUNT(*) - COUNT(cp.id) as reservations_without_account,
        COUNT(DISTINCT cp.id) as unique_customers,
        COUNT(DISTINCT CASE WHEN cp.password_hash IS NOT NULL THEN cp.id END) as customers_with_login_account
    FROM reservations r
    LEFT JOIN customer_profiles cp ON r.customer_profile_id = cp.id;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- 4. 인덱스 추가 (성능 최적화)
CREATE INDEX IF NOT EXISTS idx_reservations_customer_profile_created 
ON reservations(customer_profile_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_customer_profiles_created 
ON customer_profiles(created_at DESC);

-- 5. 테스트 쿼리
-- 관리자용 예약 조회 테스트
-- SELECT * FROM get_admin_reservations_with_customer() LIMIT 10;

-- 고객 계정 통계 테스트
-- SELECT * FROM get_customer_account_stats();

-- 6. 권한 설정 (필요시 관리자 전용으로 제한 가능)
-- GRANT EXECUTE ON FUNCTION get_admin_reservations_with_customer() TO authenticated;
-- GRANT EXECUTE ON FUNCTION get_customer_profiles_summary() TO authenticated;
-- GRANT EXECUTE ON FUNCTION get_customer_account_stats() TO authenticated;