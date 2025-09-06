// Supabase에 원자적 예약 시스템 배포 스크립트
const fs = require('fs');
const path = require('path');

// env.js 파일 읽기
const envPath = path.join(__dirname, 'env.js');
const envContent = fs.readFileSync(envPath, 'utf8');

// 환경변수 추출
const urlMatch = envContent.match(/SUPABASE_URL:\s*["']([^"']+)["']/);
const keyMatch = envContent.match(/SUPABASE_ANON_KEY:\s*["']([^"']+)["']/);

if (!urlMatch || !keyMatch) {
  console.error('❌ env.js에서 Supabase 설정을 찾을 수 없습니다.');
  process.exit(1);
}

const SUPABASE_URL = urlMatch[1];
const SUPABASE_ANON_KEY = keyMatch[1];

console.log('🚀 Supabase 원자적 예약 시스템 배포를 시작합니다...');
console.log('📍 URL:', SUPABASE_URL);

// SQL 스크립트 읽기
const sqlPath = path.join(__dirname, 'supabase', 'atomic-reservation-system.sql');
const sqlContent = fs.readFileSync(sqlPath, 'utf8');

// Supabase REST API를 통해 SQL 실행
async function deployToSupabase() {
  try {
    const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/exec_sql`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
        'apikey': SUPABASE_ANON_KEY,
      },
      body: JSON.stringify({
        sql: sqlContent
      })
    });

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }

    const result = await response.text();
    console.log('✅ SQL 스크립트가 성공적으로 배포되었습니다!');
    console.log('📋 결과:', result);
    
  } catch (error) {
    console.error('❌ 배포 실패:', error.message);
    console.log('');
    console.log('💡 대안 방법:');
    console.log('1. Supabase 대시보드 → SQL Editor에서 직접 실행');
    console.log('2. supabase/atomic-reservation-system.sql 파일 내용을 복사하여 실행');
    console.log('');
    console.log('📝 실행할 SQL:');
    console.log('---');
    console.log(sqlContent);
  }
}

// Node.js 환경에서 fetch 사용을 위한 폴리필
if (typeof fetch === 'undefined') {
  console.log('⚠️  Node.js에서 fetch를 사용할 수 없습니다.');
  console.log('💡 수동으로 Supabase 대시보드에서 다음 SQL을 실행해주세요:');
  console.log('');
  console.log('📝 실행할 SQL:');
  console.log('---');
  console.log(sqlContent);
  console.log('---');
  console.log('');
  console.log('✅ SQL 실행 후 3단계로 진행할 수 있습니다.');
} else {
  deployToSupabase();
}