-- 완전한 관리자 시스템 수정 (의존성 해결)
-- 작성일: 2025-09-06
-- 목표: final-admin-permissions-fix.sql의 모든 의존성 해결 및 완전한 시스템 구축

-- ==============================================
-- 1. 기존 충돌 테이블 정리
-- ==============================================

DROP TABLE IF EXISTS admin_activity_log CASCADE;
DROP TABLE IF EXISTS admin_activity_logs CASCADE;

-- ==============================================
-- 2. admin_profiles 테이블 생성 (핵심 의존성 해결)
-- ==============================================

CREATE TABLE IF NOT EXISTS admin_profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    full_name TEXT,
    role TEXT DEFAULT 'admin' CHECK (role IN ('super_admin', 'admin', 'viewer')),
    is_active BOOLEAN DEFAULT true,
    permissions JSONB DEFAULT '{
        "reservations": {"read": true, "write": true, "delete": false},
        "bookings": {"read": true, "write": true, "delete": false},
        "catalog": {"read": true, "write": true, "delete": false},
        "availability": {"read": true, "write": true, "delete": false},
        "modifications": {"read": true, "write": true, "delete": false},
        "messages": {"read": true, "write": true, "delete": false},
        "users": {"read": false, "write": false, "delete": false}
    }'::jsonb,
    last_login_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES auth.users(id),
    
    PRIMARY KEY (id),
    UNIQUE(email)
);

-- 인덱스 생성 (성능 최적화)
CREATE INDEX IF NOT EXISTS idx_admin_profiles_email ON admin_profiles(email);
CREATE INDEX IF NOT EXISTS idx_admin_profiles_role ON admin_profiles(role);
CREATE INDEX IF NOT EXISTS idx_admin_profiles_is_active ON admin_profiles(is_active);

-- ==============================================
-- 3. create_test_admin 함수 생성 (HTML 호출용)
-- ==============================================

CREATE OR REPLACE FUNCTION create_test_admin(
  admin_email TEXT,
  admin_name TEXT DEFAULT 'Test Admin',
  admin_role TEXT DEFAULT 'admin'
) RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- 현재 인증된 사용자의 ID를 가져와서 관리자 프로필 생성
  INSERT INTO admin_profiles (id, email, full_name, role, is_active)
  VALUES (
    auth.uid(),
    admin_email,
    admin_name,
    admin_role,
    true
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    full_name = EXCLUDED.full_name,
    role = EXCLUDED.role,
    is_active = EXCLUDED.is_active,
    updated_at = NOW();
  
  RETURN true;
EXCEPTION
  WHEN OTHERS THEN
    RETURN false;
END;
$$;

-- ==============================================
-- 4. verify_admin_by_email 함수 생성 (관리자 로그인용)
-- ==============================================

CREATE OR REPLACE FUNCTION verify_admin_by_email(p_email TEXT)
RETURNS TABLE (
    is_admin BOOLEAN,
    role TEXT,
    permissions JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        true::BOOLEAN as is_admin,
        ap.role,
        ap.permissions
    FROM admin_profiles ap
    WHERE LOWER(TRIM(ap.email)) = LOWER(TRIM(p_email))
      AND ap.is_active = true
    LIMIT 1;
    
    -- 결과가 없으면 false 반환
    IF NOT FOUND THEN
        RETURN QUERY SELECT false::BOOLEAN, NULL::TEXT, NULL::JSONB;
    END IF;
END;
$$;

-- ==============================================
-- 5. admin_profiles RLS 정책 설정 (보안)
-- ==============================================

ALTER TABLE admin_profiles ENABLE ROW LEVEL SECURITY;

-- 관리자는 자신의 프로필 조회 가능
CREATE POLICY "Admins can view their own profile" ON admin_profiles
  FOR SELECT USING (auth.uid() = id);

-- super_admin은 모든 관리자 프로필 조회/관리 가능
CREATE POLICY "Super admins can manage all profiles" ON admin_profiles
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM admin_profiles ap
      WHERE ap.id = auth.uid() 
        AND ap.role = 'super_admin' 
        AND ap.is_active = true
    )
  );

-- ==============================================
-- 6. 함수 권한 설정
-- ==============================================

GRANT EXECUTE ON FUNCTION create_test_admin TO authenticated;
GRANT EXECUTE ON FUNCTION verify_admin_by_email TO authenticated;

-- ==============================================
-- 7. super_admin 권한 설정 (초기 설정)
-- ==============================================

-- super_admin 권한 설정
UPDATE admin_profiles 
SET permissions = '{
    "reservations": {"read": true, "write": true, "delete": true},
    "bookings": {"read": true, "write": true, "delete": true},
    "catalog": {"read": true, "write": true, "delete": true},
    "availability": {"read": true, "write": true, "delete": true},
    "modifications": {"read": true, "write": true, "delete": true},
    "messages": {"read": true, "write": true, "delete": true},
    "users": {"read": true, "write": true, "delete": true}
}'::jsonb
WHERE role = 'super_admin';

-- viewer 권한 설정  
UPDATE admin_profiles 
SET permissions = '{
    "reservations": {"read": true, "write": false, "delete": false},
    "bookings": {"read": true, "write": false, "delete": false},
    "catalog": {"read": true, "write": false, "delete": false},
    "availability": {"read": true, "write": false, "delete": false},
    "modifications": {"read": true, "write": false, "delete": false},
    "messages": {"read": true, "write": false, "delete": false},
    "users": {"read": false, "write": false, "delete": false}
}'::jsonb
WHERE role = 'viewer';

-- ==============================================
-- 8. 검증 쿼리
-- ==============================================

-- 생성된 테이블 확인
SELECT 
    'Table Check' as test_type,
    table_name,
    column_name,
    data_type
FROM information_schema.columns 
WHERE table_name = 'admin_profiles'
ORDER BY ordinal_position;

-- 생성된 함수 확인
SELECT 
    'Function Check' as test_type,
    proname as function_name,
    pg_get_function_arguments(oid) as arguments
FROM pg_proc 
WHERE proname IN ('create_test_admin', 'verify_admin_by_email')
ORDER BY proname;

-- ==============================================
-- 9. 성공 메시지
-- ==============================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🎉 관리자 시스템 의존성 해결 완료!';
    RAISE NOTICE '=====================================';
    RAISE NOTICE '✅ admin_profiles 테이블 생성 완료';
    RAISE NOTICE '✅ create_test_admin() 함수 생성 완료';
    RAISE NOTICE '✅ verify_admin_by_email() 함수 생성 완료';
    RAISE NOTICE '✅ RLS 정책 설정 완료';
    RAISE NOTICE '✅ 함수 권한 설정 완료';
    RAISE NOTICE '';
    RAISE NOTICE '🚀 이제 final-admin-permissions-fix.sql을 실행할 준비가 되었습니다!';
    RAISE NOTICE '=====================================';
END;
$$;