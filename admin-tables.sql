-- 관리자 테이블 및 보안 함수 시스템 생성
-- 작성일: 2025-09-06

-- ==============================================
-- 1. 관리자 프로필 테이블 생성
-- ==============================================

-- 관리자 프로필 테이블 (Supabase Auth와 연동)
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
-- 2. RLS 정책 설정
-- ==============================================

-- admin_profiles 테이블에 RLS 활성화
ALTER TABLE admin_profiles ENABLE ROW LEVEL SECURITY;

-- 관리자만 자신의 프로필을 볼 수 있음
CREATE POLICY "Admins can view their own profile" ON admin_profiles
  FOR SELECT USING (auth.uid() = id);

-- 인덱스 생성 (성능 최적화)
CREATE INDEX IF NOT EXISTS idx_admin_profiles_email ON admin_profiles(email);
CREATE INDEX IF NOT EXISTS idx_admin_profiles_role ON admin_profiles(role);
CREATE INDEX IF NOT EXISTS idx_admin_profiles_is_active ON admin_profiles(is_active);

-- 테스트용 관리자 계정 생성 함수 (임시)
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
    updated_at = NOW();
  
  RETURN TRUE;
END;
$$;

-- 사용 예: SELECT create_test_admin('admin@osobbq.com', 'OSO Admin', 'super_admin');
