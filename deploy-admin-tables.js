/**
 * 관리자 테이블 및 보안 함수 배포 스크립트
 * Node.js에서 실행하여 Supabase에 SQL을 직접 실행합니다.
 */

const { createClient } = require('@supabase/supabase-js');
const fs = require('fs').promises;
const path = require('path');

// env.js에서 설정 로드 (브라우저용이므로 수동으로 파싱)
const SUPABASE_URL = "https://nrblnfmknolgsqpcqite.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5yYmxuZm1rbm9sZ3NxcGNxaXRlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY4Nzg3NDEsImV4cCI6MjA3MjQ1NDc0MX0.8zy753R0nLtzr7a4UdpD1JjVUnNzikSfQTbO2sqnrUo";

// Supabase 클라이언트 생성
const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function deployAdminTables() {
  try {
    console.log('🚀 관리자 테이블 배포 시작...');
    
    // 1단계: admin_profiles 테이블 생성
    console.log('📋 1단계: admin_profiles 테이블 생성 중...');
    const { data: tableResult, error: tableError } = await supabase.rpc('sql', {
      query: `
        -- 관리자 프로필 테이블 생성
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
        
        -- RLS 활성화
        ALTER TABLE admin_profiles ENABLE ROW LEVEL SECURITY;
        
        -- 인덱스 생성
        CREATE INDEX IF NOT EXISTS idx_admin_profiles_email ON admin_profiles(email);
        CREATE INDEX IF NOT EXISTS idx_admin_profiles_role ON admin_profiles(role);
        CREATE INDEX IF NOT EXISTS idx_admin_profiles_is_active ON admin_profiles(is_active);
      `
    });

    if (tableError) {
      console.error('❌ 테이블 생성 실패:', tableError);
      return false;
    }
    
    console.log('✅ admin_profiles 테이블 생성 완료');

    // 2단계: 보안 함수들 생성
    console.log('🔐 2단계: 보안 함수들 생성 중...');
    
    // admin-security-functions.sql 파일 읽기
    const sqlPath = path.join(__dirname, 'supabase', 'admin-security-functions.sql');
    const sqlContent = await fs.readFile(sqlPath, 'utf8');
    
    const { data: functionResult, error: functionError } = await supabase.rpc('sql', {
      query: sqlContent
    });

    if (functionError) {
      console.error('❌ 보안 함수 생성 실패:', functionError);
      return false;
    }
    
    console.log('✅ 보안 함수들 생성 완료');

    // 3단계: 함수 존재 확인
    console.log('🔍 3단계: 생성된 함수들 확인 중...');
    const { data: functions, error: checkError } = await supabase.rpc('sql', {
      query: `
        SELECT routine_name, routine_type 
        FROM information_schema.routines 
        WHERE routine_name LIKE 'admin_%' OR routine_name = 'get_admin_permissions'
        ORDER BY routine_name;
      `
    });

    if (checkError) {
      console.error('❌ 함수 확인 실패:', checkError);
    } else {
      console.log('📋 생성된 함수들:');
      functions?.forEach(func => {
        console.log(`  - ${func.routine_name} (${func.routine_type})`);
      });
    }

    console.log('🎉 관리자 보안 시스템 배포 완료!');
    return true;

  } catch (error) {
    console.error('💥 배포 중 오류 발생:', error);
    return false;
  }
}

// 스크립트 실행
if (require.main === module) {
  deployAdminTables()
    .then(success => {
      process.exit(success ? 0 : 1);
    })
    .catch(error => {
      console.error('실행 오류:', error);
      process.exit(1);
    });
}

module.exports = { deployAdminTables };