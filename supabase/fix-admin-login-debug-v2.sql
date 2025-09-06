-- 관리자 로그인 문제 디버깅 및 수정 (컬럼명 모호성 해결)
-- 작성일: 2025-09-06
-- 목표: 관리자 권한 확인 문제 해결

-- =======================================================
-- 1단계: 현재 상황 디버깅
-- =======================================================

-- Supabase Auth 사용자 확인
SELECT 
    id as auth_user_id,
    email,
    created_at as auth_created_at
FROM auth.users 
WHERE email = 'admin@osobbq.com';

-- admin_profiles 테이블 확인
SELECT 
    id as profile_id,
    email,
    is_active,
    role,
    created_at as profile_created_at
FROM admin_profiles 
WHERE email = 'admin@osobbq.com';

-- =======================================================
-- 2단계: 수정된 관리자 계정 확인 및 수정 함수
-- =======================================================

-- 컬럼명 모호성 문제를 해결한 함수
CREATE OR REPLACE FUNCTION fix_admin_account()
RETURNS TABLE (
    message TEXT,
    auth_user_id UUID,
    profile_exists BOOLEAN,
    is_active BOOLEAN
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_auth_user_id UUID;
    v_profile_exists BOOLEAN := false;
    v_profile_active BOOLEAN := false;
BEGIN
    -- 1. Supabase Auth에서 사용자 ID 조회
    SELECT u.id INTO v_auth_user_id 
    FROM auth.users u
    WHERE u.email = 'admin@osobbq.com';
    
    IF v_auth_user_id IS NULL THEN
        RETURN QUERY SELECT 
            '❌ auth.users에 admin@osobbq.com 계정이 없습니다.'::TEXT,
            NULL::UUID,
            false,
            false;
        RETURN;
    END IF;
    
    -- 2. admin_profiles 테이블에서 확인 (컬럼명 명시적으로 지정)
    SELECT true, ap.is_active INTO v_profile_exists, v_profile_active
    FROM admin_profiles ap
    WHERE ap.email = 'admin@osobbq.com'
    LIMIT 1;
    
    IF NOT v_profile_exists THEN
        -- 3. admin_profiles에 없으면 생성
        INSERT INTO admin_profiles (id, email, full_name, role, is_active, permissions)
        VALUES (
            v_auth_user_id,  -- Auth 사용자 ID와 일치시킴
            'admin@osobbq.com',
            'OSO Admin',
            'super_admin',
            true,
            '{"reservations": {"read": true, "write": true, "delete": true}, "users": {"read": true, "write": true}, "system": {"read": true, "write": true}}'::jsonb
        )
        ON CONFLICT (email) DO UPDATE SET
            id = v_auth_user_id,  -- ID를 Auth 사용자 ID로 업데이트
            is_active = true,
            updated_at = NOW();
            
        RETURN QUERY SELECT 
            '✅ admin_profiles에 계정이 생성/업데이트되었습니다.'::TEXT,
            v_auth_user_id,
            true,
            true;
    ELSIF NOT v_profile_active THEN
        -- 4. 계정이 비활성화되어 있으면 활성화
        UPDATE admin_profiles 
        SET is_active = true, id = v_auth_user_id, updated_at = NOW()
        WHERE email = 'admin@osobbq.com';
        
        RETURN QUERY SELECT 
            '✅ 관리자 계정이 활성화되었습니다.'::TEXT,
            v_auth_user_id,
            true,
            true;
    ELSE
        -- 5. ID가 다르면 업데이트
        UPDATE admin_profiles 
        SET id = v_auth_user_id, updated_at = NOW()
        WHERE email = 'admin@osobbq.com' AND id != v_auth_user_id;
        
        RETURN QUERY SELECT 
            '✅ 관리자 계정이 정상입니다.'::TEXT,
            v_auth_user_id,
            true,
            true;
    END IF;
END;
$$;

-- 함수 실행하여 계정 수정
SELECT * FROM fix_admin_account();

-- =======================================================
-- 3단계: 이메일 기반 관리자 권한 확인 함수
-- =======================================================

-- 이메일 기반 관리자 권한 확인 함수 (안전한 방식)
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
        true as is_admin,
        ap.role,
        ap.permissions
    FROM admin_profiles ap
    WHERE ap.email = p_email 
      AND ap.is_active = true
    LIMIT 1;
    
    -- 결과가 없으면 false 반환
    IF NOT FOUND THEN
        RETURN QUERY SELECT false, NULL::TEXT, NULL::JSONB;
    END IF;
END;
$$;

-- 함수 권한 부여
GRANT EXECUTE ON FUNCTION verify_admin_by_email TO anon;
GRANT EXECUTE ON FUNCTION verify_admin_by_email TO authenticated;

-- =======================================================
-- 4단계: 테스트 및 확인
-- =======================================================

-- 이메일 기반 권한 확인 테스트
SELECT 
    '이메일 기반 권한 확인 테스트' as test_name,
    * 
FROM verify_admin_by_email('admin@osobbq.com');

-- 최종 상태 확인
SELECT 
    'Final Check' as status,
    'auth.users' as source,
    u.id,
    u.email,
    u.created_at
FROM auth.users u
WHERE u.email = 'admin@osobbq.com'
UNION ALL
SELECT 
    'Final Check' as status,
    'admin_profiles' as source,
    ap.id,
    ap.email,
    ap.created_at
FROM admin_profiles ap
WHERE ap.email = 'admin@osobbq.com';

-- ID 매칭 확인
SELECT 
    'ID 매칭 확인' as check_type,
    u.id = ap.id as ids_match,
    u.id as auth_id,
    ap.id as profile_id,
    ap.is_active,
    ap.role
FROM auth.users u
JOIN admin_profiles ap ON u.email = ap.email
WHERE u.email = 'admin@osobbq.com';

-- =======================================================
-- 5단계: 성공 메시지 및 다음 단계 안내
-- =======================================================

DO $$
BEGIN
    RAISE NOTICE '🎯 관리자 로그인 문제 해결 SQL 실행 완료!';
    RAISE NOTICE '✅ 1. fix_admin_account() - ID 매칭 문제 해결';
    RAISE NOTICE '✅ 2. verify_admin_by_email() - 이메일 기반 권한 확인';
    RAISE NOTICE '';
    RAISE NOTICE '📋 다음 단계: admin-login.html 파일 수정';
    RAISE NOTICE '🔧 verifyAdminPermissions 함수를 다음과 같이 변경하세요:';
    RAISE NOTICE '';
    RAISE NOTICE 'async verifyAdminPermissions(user) {';
    RAISE NOTICE '    try {';
    RAISE NOTICE '        const { data, error } = await this.supabaseClient.rpc(''verify_admin_by_email'', {';
    RAISE NOTICE '            p_email: user.email';
    RAISE NOTICE '        });';
    RAISE NOTICE '        if (error) return false;';
    RAISE NOTICE '        return data && data.length > 0 && data[0].is_admin === true;';
    RAISE NOTICE '    } catch (error) {';
    RAISE NOTICE '        return false;';
    RAISE NOTICE '    }';
    RAISE NOTICE '}';
    RAISE NOTICE '';
    RAISE NOTICE '🚀 수정 후 관리자 로그인을 다시 시도하세요!';
END;
$$;