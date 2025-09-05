-- =====================================================
-- Phase 2.3: 관리자 로그인 시스템
-- 작성일: 2025년
-- 설명: Supabase Auth 기반 관리자 인증 및 권한 관리 시스템
-- =====================================================

-- =====================================================
-- 1. 관리자 프로필 테이블 생성
-- =====================================================

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

-- =====================================================
-- 2. 관리자 세션 및 활동 로그 테이블
-- =====================================================

-- 관리자 로그인 세션 추적 테이블
CREATE TABLE IF NOT EXISTS admin_sessions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    admin_id UUID REFERENCES admin_profiles(id) ON DELETE CASCADE NOT NULL,
    session_token TEXT UNIQUE,
    login_ip TEXT,
    user_agent TEXT,
    login_at TIMESTAMPTZ DEFAULT NOW(),
    logout_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '24 hours'),
    is_active BOOLEAN DEFAULT true,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 관리자 활동 로그 테이블 (보안 추적)
CREATE TABLE IF NOT EXISTS admin_activity_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    admin_id UUID REFERENCES admin_profiles(id) ON DELETE CASCADE NOT NULL,
    session_id UUID REFERENCES admin_sessions(id) ON DELETE SET NULL,
    action_type TEXT NOT NULL, -- login, logout, create, update, delete, view
    resource_type TEXT, -- reservations, bookings, catalog, etc.
    resource_id TEXT, -- 해당 리소스의 ID
    action_details JSONB DEFAULT '{}',
    ip_address TEXT,
    user_agent TEXT,
    success BOOLEAN DEFAULT true,
    error_message TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- 3. 인덱스 생성 (성능 최적화)
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_admin_profiles_email ON admin_profiles(email);
CREATE INDEX IF NOT EXISTS idx_admin_profiles_role ON admin_profiles(role);
CREATE INDEX IF NOT EXISTS idx_admin_profiles_is_active ON admin_profiles(is_active);

CREATE INDEX IF NOT EXISTS idx_admin_sessions_admin_id ON admin_sessions(admin_id);
CREATE INDEX IF NOT EXISTS idx_admin_sessions_token ON admin_sessions(session_token);
CREATE INDEX IF NOT EXISTS idx_admin_sessions_active ON admin_sessions(is_active);
CREATE INDEX IF NOT EXISTS idx_admin_sessions_expires ON admin_sessions(expires_at);

CREATE INDEX IF NOT EXISTS idx_admin_activity_admin_id ON admin_activity_logs(admin_id);
CREATE INDEX IF NOT EXISTS idx_admin_activity_session_id ON admin_activity_logs(session_id);
CREATE INDEX IF NOT EXISTS idx_admin_activity_type ON admin_activity_logs(action_type);
CREATE INDEX IF NOT EXISTS idx_admin_activity_resource ON admin_activity_logs(resource_type);
CREATE INDEX IF NOT EXISTS idx_admin_activity_created ON admin_activity_logs(created_at);

-- =====================================================
-- 4. Row Level Security (RLS) 정책
-- =====================================================

-- RLS 활성화
ALTER TABLE admin_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_activity_logs ENABLE ROW LEVEL SECURITY;

-- admin_profiles RLS 정책
-- 정책 1: 관리자는 자신의 프로필 조회 가능
CREATE POLICY "관리자 자신의 프로필 조회" ON admin_profiles
    FOR SELECT
    USING (auth.uid() = id);

-- 정책 2: super_admin은 모든 관리자 프로필 조회 가능
CREATE POLICY "super_admin 전체 관리자 조회" ON admin_profiles
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM admin_profiles ap
            WHERE ap.id = auth.uid() 
            AND ap.role = 'super_admin' 
            AND ap.is_active = true
        )
    );

-- 정책 3: super_admin은 관리자 프로필 생성/수정 가능
CREATE POLICY "super_admin 관리자 관리" ON admin_profiles
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM admin_profiles ap
            WHERE ap.id = auth.uid() 
            AND ap.role = 'super_admin' 
            AND ap.is_active = true
        )
    );

-- admin_sessions RLS 정책
-- 정책 1: 관리자는 자신의 세션 조회 가능
CREATE POLICY "관리자 자신의 세션 조회" ON admin_sessions
    FOR SELECT
    USING (admin_id = auth.uid());

-- 정책 2: super_admin은 모든 세션 조회 가능
CREATE POLICY "super_admin 전체 세션 조회" ON admin_sessions
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM admin_profiles ap
            WHERE ap.id = auth.uid() 
            AND ap.role = 'super_admin' 
            AND ap.is_active = true
        )
    );

-- 정책 3: 관리자는 자신의 세션 생성/수정 가능
CREATE POLICY "관리자 자신의 세션 관리" ON admin_sessions
    FOR ALL
    USING (admin_id = auth.uid());

-- admin_activity_logs RLS 정책
-- 정책 1: 관리자는 자신의 활동 로그 조회 가능
CREATE POLICY "관리자 자신의 활동 로그 조회" ON admin_activity_logs
    FOR SELECT
    USING (admin_id = auth.uid());

-- 정책 2: super_admin은 모든 활동 로그 조회 가능
CREATE POLICY "super_admin 전체 활동 로그 조회" ON admin_activity_logs
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM admin_profiles ap
            WHERE ap.id = auth.uid() 
            AND ap.role = 'super_admin' 
            AND ap.is_active = true
        )
    );

-- 정책 3: 모든 관리자는 활동 로그 생성 가능 (자동 로깅용)
CREATE POLICY "관리자 활동 로그 생성" ON admin_activity_logs
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM admin_profiles ap
            WHERE ap.id = auth.uid() 
            AND ap.is_active = true
        )
    );

-- =====================================================
-- 5. 기존 테이블에 RLS 정책 추가 (관리자 전용)
-- =====================================================

-- reservations 테이블 관리자 접근 정책
CREATE POLICY "관리자 예약 신청 관리" ON reservations
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM admin_profiles ap
            WHERE ap.id = auth.uid() 
            AND ap.is_active = true
            AND (ap.permissions->>'reservations')::jsonb->>'read' = 'true'
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM admin_profiles ap
            WHERE ap.id = auth.uid() 
            AND ap.is_active = true
            AND (ap.permissions->>'reservations')::jsonb->>'write' = 'true'
        )
    );

-- bookings 테이블 관리자 접근 정책
CREATE POLICY "관리자 확정 예약 관리" ON bookings
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM admin_profiles ap
            WHERE ap.id = auth.uid() 
            AND ap.is_active = true
            AND (ap.permissions->>'bookings')::jsonb->>'read' = 'true'
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM admin_profiles ap
            WHERE ap.id = auth.uid() 
            AND ap.is_active = true
            AND (ap.permissions->>'bookings')::jsonb->>'write' = 'true'
        )
    );

-- resource_catalog 테이블 관리자 접근 정책
CREATE POLICY "관리자 시설 카탈로그 관리" ON resource_catalog
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM admin_profiles ap
            WHERE ap.id = auth.uid() 
            AND ap.is_active = true
            AND (ap.permissions->>'catalog')::jsonb->>'read' = 'true'
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM admin_profiles ap
            WHERE ap.id = auth.uid() 
            AND ap.is_active = true
            AND (ap.permissions->>'catalog')::jsonb->>'write' = 'true'
        )
    );

-- =====================================================
-- 6. 관리자 인증 및 권한 확인 함수들
-- =====================================================

-- 관리자 인증 상태 확인 함수
CREATE OR REPLACE FUNCTION is_admin_authenticated()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM admin_profiles
        WHERE id = auth.uid() 
        AND is_active = true
    );
END;
$$;

-- 관리자 권한 확인 함수
CREATE OR REPLACE FUNCTION has_admin_permission(
    resource_type TEXT,
    permission_type TEXT -- read, write, delete
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    admin_permissions JSONB;
BEGIN
    SELECT permissions INTO admin_permissions
    FROM admin_profiles
    WHERE id = auth.uid() 
    AND is_active = true;
    
    IF admin_permissions IS NULL THEN
        RETURN FALSE;
    END IF;
    
    -- 해당 리소스 타입의 권한 확인
    RETURN COALESCE(
        (admin_permissions->>resource_type)::jsonb->>permission_type = 'true',
        FALSE
    );
END;
$$;

-- 관리자 프로필 조회 함수
CREATE OR REPLACE FUNCTION get_admin_profile()
RETURNS TABLE (
    id UUID,
    email TEXT,
    full_name TEXT,
    role TEXT,
    permissions JSONB,
    last_login_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF NOT is_admin_authenticated() THEN
        RAISE EXCEPTION '관리자 인증이 필요합니다.';
    END IF;
    
    RETURN QUERY
    SELECT 
        ap.id,
        ap.email,
        ap.full_name,
        ap.role,
        ap.permissions,
        ap.last_login_at,
        ap.created_at
    FROM admin_profiles ap
    WHERE ap.id = auth.uid();
END;
$$;

-- 관리자 활동 로그 기록 함수
CREATE OR REPLACE FUNCTION log_admin_activity(
    p_action_type TEXT,
    p_resource_type TEXT DEFAULT NULL,
    p_resource_id TEXT DEFAULT NULL,
    p_action_details JSONB DEFAULT '{}'::jsonb,
    p_success BOOLEAN DEFAULT TRUE,
    p_error_message TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    log_id UUID;
    current_session_id UUID;
BEGIN
    -- 현재 활성 세션 ID 찾기
    SELECT id INTO current_session_id
    FROM admin_sessions
    WHERE admin_id = auth.uid() 
    AND is_active = true
    AND expires_at > NOW()
    ORDER BY login_at DESC
    LIMIT 1;
    
    -- 활동 로그 삽입
    INSERT INTO admin_activity_logs (
        admin_id,
        session_id,
        action_type,
        resource_type,
        resource_id,
        action_details,
        success,
        error_message
    ) VALUES (
        auth.uid(),
        current_session_id,
        p_action_type,
        p_resource_type,
        p_resource_id,
        p_action_details,
        p_success,
        p_error_message
    ) RETURNING id INTO log_id;
    
    RETURN log_id;
END;
$$;

-- 관리자 로그인 처리 함수
CREATE OR REPLACE FUNCTION admin_login(
    p_session_token TEXT DEFAULT NULL,
    p_ip_address TEXT DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    admin_profile RECORD;
    session_id UUID;
    result JSONB;
BEGIN
    -- 관리자 프로필 확인
    SELECT * INTO admin_profile
    FROM admin_profiles
    WHERE id = auth.uid() 
    AND is_active = true;
    
    IF admin_profile IS NULL THEN
        RAISE EXCEPTION '유효하지 않은 관리자 계정입니다.';
    END IF;
    
    -- 기존 활성 세션 비활성화
    UPDATE admin_sessions 
    SET is_active = false, logout_at = NOW()
    WHERE admin_id = auth.uid() 
    AND is_active = true;
    
    -- 새 세션 생성
    INSERT INTO admin_sessions (
        admin_id,
        session_token,
        login_ip,
        user_agent
    ) VALUES (
        auth.uid(),
        p_session_token,
        p_ip_address,
        p_user_agent
    ) RETURNING id INTO session_id;
    
    -- 마지막 로그인 시간 업데이트
    UPDATE admin_profiles
    SET last_login_at = NOW(),
        updated_at = NOW()
    WHERE id = auth.uid();
    
    -- 로그인 활동 기록
    PERFORM log_admin_activity(
        'login',
        'auth',
        session_id::text,
        jsonb_build_object(
            'ip_address', p_ip_address,
            'user_agent', p_user_agent
        )
    );
    
    -- 결과 반환
    result := jsonb_build_object(
        'success', true,
        'session_id', session_id,
        'admin', jsonb_build_object(
            'id', admin_profile.id,
            'email', admin_profile.email,
            'full_name', admin_profile.full_name,
            'role', admin_profile.role,
            'permissions', admin_profile.permissions
        )
    );
    
    RETURN result;
END;
$$;

-- 관리자 로그아웃 처리 함수
CREATE OR REPLACE FUNCTION admin_logout(
    p_session_id UUID DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    target_session_id UUID;
BEGIN
    -- 세션 ID가 제공되지 않으면 현재 활성 세션 찾기
    IF p_session_id IS NULL THEN
        SELECT id INTO target_session_id
        FROM admin_sessions
        WHERE admin_id = auth.uid() 
        AND is_active = true
        ORDER BY login_at DESC
        LIMIT 1;
    ELSE
        target_session_id := p_session_id;
    END IF;
    
    -- 세션 비활성화
    UPDATE admin_sessions
    SET is_active = false,
        logout_at = NOW()
    WHERE id = target_session_id
    AND admin_id = auth.uid();
    
    -- 로그아웃 활동 기록
    PERFORM log_admin_activity(
        'logout',
        'auth',
        target_session_id::text
    );
    
    RETURN TRUE;
END;
$$;

-- 관리자 세션 정리 함수 (만료된 세션 제거)
CREATE OR REPLACE FUNCTION cleanup_expired_admin_sessions()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    cleaned_count INTEGER;
BEGIN
    -- 만료된 세션 비활성화
    UPDATE admin_sessions
    SET is_active = false,
        logout_at = NOW()
    WHERE expires_at < NOW()
    AND is_active = true;
    
    GET DIAGNOSTICS cleaned_count = ROW_COUNT;
    
    RETURN cleaned_count;
END;
$$;

-- =====================================================
-- 7. 초기 관리자 계정 생성 (개발/테스트용)
-- =====================================================

-- 주의: 실제 운영 환경에서는 이 부분을 제거하고 수동으로 관리자 계정을 생성하세요.

-- 초기 super_admin 계정 생성 함수
CREATE OR REPLACE FUNCTION create_initial_admin(
    p_email TEXT,
    p_full_name TEXT DEFAULT 'Super Admin',
    p_user_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    admin_id UUID;
    result JSONB;
BEGIN
    -- 이미 관리자가 존재하는 경우 체크
    IF EXISTS (SELECT 1 FROM admin_profiles WHERE role = 'super_admin') THEN
        RAISE EXCEPTION '이미 super_admin 계정이 존재합니다.';
    END IF;
    
    -- 사용자 ID가 제공되지 않으면 현재 인증된 사용자 사용
    IF p_user_id IS NULL THEN
        admin_id := auth.uid();
    ELSE
        admin_id := p_user_id;
    END IF;
    
    IF admin_id IS NULL THEN
        RAISE EXCEPTION '유효한 사용자 ID가 필요합니다.';
    END IF;
    
    -- 관리자 프로필 생성
    INSERT INTO admin_profiles (
        id,
        email,
        full_name,
        role,
        permissions,
        created_by
    ) VALUES (
        admin_id,
        p_email,
        p_full_name,
        'super_admin',
        '{
            "reservations": {"read": true, "write": true, "delete": true},
            "bookings": {"read": true, "write": true, "delete": true},
            "catalog": {"read": true, "write": true, "delete": true},
            "availability": {"read": true, "write": true, "delete": true},
            "modifications": {"read": true, "write": true, "delete": true},
            "messages": {"read": true, "write": true, "delete": true},
            "users": {"read": true, "write": true, "delete": true}
        }'::jsonb,
        admin_id
    ) ON CONFLICT (id) DO UPDATE SET
        role = 'super_admin',
        permissions = EXCLUDED.permissions,
        updated_at = NOW();
    
    result := jsonb_build_object(
        'success', true,
        'admin_id', admin_id,
        'email', p_email,
        'role', 'super_admin'
    );
    
    RETURN result;
END;
$$;

-- =====================================================
-- 8. 트리거 및 자동화 함수
-- =====================================================

-- 관리자 프로필 업데이트 시간 자동 갱신 트리거
CREATE OR REPLACE FUNCTION update_admin_profile_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

CREATE TRIGGER trigger_update_admin_profile_updated_at
    BEFORE UPDATE ON admin_profiles
    FOR EACH ROW EXECUTE FUNCTION update_admin_profile_updated_at();

-- 세션 만료 알림 함수 (선택적 - 별도 크론 잡에서 실행)
CREATE OR REPLACE FUNCTION notify_expiring_admin_sessions()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    expiring_count INTEGER;
BEGIN
    -- 1시간 내에 만료될 활성 세션 수 확인
    SELECT COUNT(*) INTO expiring_count
    FROM admin_sessions
    WHERE is_active = true
    AND expires_at BETWEEN NOW() AND NOW() + INTERVAL '1 hour';
    
    -- 실제 알림 로직은 애플리케이션 레벨에서 구현
    -- 여기서는 카운트만 반환
    
    RETURN expiring_count;
END;
$$;

-- =====================================================
-- 9. 권한 및 보안 설정
-- =====================================================

-- 함수들에 대한 실행 권한 부여 (인증된 사용자만)
GRANT EXECUTE ON FUNCTION is_admin_authenticated() TO authenticated;
GRANT EXECUTE ON FUNCTION has_admin_permission(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_admin_profile() TO authenticated;
GRANT EXECUTE ON FUNCTION log_admin_activity(TEXT, TEXT, TEXT, JSONB, BOOLEAN, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_login(TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_logout(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION cleanup_expired_admin_sessions() TO authenticated;
GRANT EXECUTE ON FUNCTION create_initial_admin(TEXT, TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION notify_expiring_admin_sessions() TO authenticated;

-- 테이블에 대한 기본 권한 설정
GRANT SELECT ON admin_profiles TO authenticated;
GRANT SELECT ON admin_sessions TO authenticated;
GRANT SELECT ON admin_activity_logs TO authenticated;

-- =====================================================
-- 10. 개발/테스트용 데이터 (선택적)
-- =====================================================

-- 주의: 실제 운영 환경에서는 이 부분을 주석 처리하세요.

/*
-- 테스트용 관리자 계정 (실제 Supabase Auth 계정 생성 후 사용)
-- 이 부분은 실제 사용자가 Supabase Auth를 통해 가입한 후 실행하세요.

-- 예시:
-- SELECT create_initial_admin('admin@osocamping.com', 'OSO Admin', '실제-사용자-UUID');

-- 테스트용 활동 로그 (개발 중 확인용)
-- INSERT INTO admin_activity_logs (admin_id, action_type, resource_type, success)
-- VALUES (
--     '실제-관리자-UUID',
--     'test',
--     'system', 
--     true
-- );
*/

-- =====================================================
-- 완료 메시지
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '=====================================================';
    RAISE NOTICE 'Phase 2.3: 관리자 로그인 시스템 설치 완료';
    RAISE NOTICE '';
    RAISE NOTICE '다음 단계:';
    RAISE NOTICE '1. Supabase Dashboard에서 Auth 설정 확인';
    RAISE NOTICE '2. 관리자 계정 생성 (이메일/비밀번호)';
    RAISE NOTICE '3. create_initial_admin() 함수로 권한 부여';
    RAISE NOTICE '4. 프론트엔드 로그인 페이지 구현';
    RAISE NOTICE '5. 기존 admin.html에 인증 미들웨어 추가';
    RAISE NOTICE '';
    RAISE NOTICE '보안 주의사항:';
    RAISE NOTICE '- 운영 환경에서는 create_initial_admin() 신중히 사용';
    RAISE NOTICE '- 정기적으로 만료된 세션 정리 실행';
    RAISE NOTICE '- admin_activity_logs 모니터링 필수';
    RAISE NOTICE '=====================================================';
END $$;