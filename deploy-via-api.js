/**
 * Supabase Management API를 통한 SQL 실행
 */

const https = require('https');
const fs = require('fs');

const PROJECT_REF = 'nrblnfmknolgsqpcqite';
const ACCESS_TOKEN = 'sbp_5937e4603025968117b059421277a9d213762213';

function executeSQL(sqlQuery, description) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify({ query: sqlQuery });
    
    const options = {
      hostname: 'api.supabase.com',
      port: 443,
      path: `/v1/projects/${PROJECT_REF}/database/query`,
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${ACCESS_TOKEN}`,
        'Content-Type': 'application/json',
        'Content-Length': data.length
      }
    };

    const req = https.request(options, (res) => {
      let responseData = '';
      
      res.on('data', (chunk) => {
        responseData += chunk;
      });
      
      res.on('end', () => {
        try {
          const result = JSON.parse(responseData);
          if (res.statusCode === 200) {
            console.log(`✅ ${description} 성공`);
            resolve(result);
          } else {
            console.error(`❌ ${description} 실패:`, result);
            reject(new Error(result.message || 'Unknown error'));
          }
        } catch (e) {
          console.error(`❌ ${description} 응답 파싱 실패:`, responseData);
          reject(e);
        }
      });
    });

    req.on('error', (error) => {
      console.error(`💥 ${description} 요청 오류:`, error);
      reject(error);
    });

    req.write(data);
    req.end();
  });
}

async function deployAdminSystem() {
  try {
    console.log('🚀 관리자 시스템 배포 시작...\n');

    // 1단계: admin_profiles 테이블 생성
    console.log('📋 1단계: admin_profiles 테이블 생성...');
    const createTableSQL = `
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

-- 관리자만 자신의 프로필을 볼 수 있음  
CREATE POLICY "Admins can view their own profile" ON admin_profiles
  FOR SELECT USING (auth.uid() = id);

-- 인덱스 생성
CREATE INDEX IF NOT EXISTS idx_admin_profiles_email ON admin_profiles(email);
CREATE INDEX IF NOT EXISTS idx_admin_profiles_role ON admin_profiles(role);
CREATE INDEX IF NOT EXISTS idx_admin_profiles_is_active ON admin_profiles(is_active);
    `;
    
    await executeSQL(createTableSQL, 'admin_profiles 테이블 생성');

    // 2단계: admin-security-functions.sql 실행
    console.log('\n🔐 2단계: 보안 함수들 생성...');
    const securityFunctionsSQL = fs.readFileSync('./supabase/admin-security-functions.sql', 'utf8');
    await executeSQL(securityFunctionsSQL, '관리자 보안 함수들 생성');

    console.log('\n🎉 관리자 시스템 배포 완료!');
    
    // 검증
    console.log('\n🔍 배포 검증 중...');
    const verifySQL = `
SELECT 
  routine_name, 
  routine_type 
FROM information_schema.routines 
WHERE routine_name LIKE 'admin_%' OR routine_name = 'get_admin_permissions'
ORDER BY routine_name;
    `;
    
    const result = await executeSQL(verifySQL, '생성된 함수들 확인');
    console.log('생성된 함수들:');
    if (result && result.result) {
      result.result.forEach(func => {
        console.log(`  - ${func.routine_name} (${func.routine_type})`);
      });
    }

  } catch (error) {
    console.error('💥 배포 실패:', error.message);
    process.exit(1);
  }
}

// 실행
deployAdminSystem();