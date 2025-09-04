// Node.js로 Supabase 연결 테스트
const fs = require('fs');

// env.js에서 환경변수 읽기
const envContent = fs.readFileSync('./env.js', 'utf8');
const urlMatch = envContent.match(/SUPABASE_URL:\s*"([^"]+)"/);
const keyMatch = envContent.match(/SUPABASE_ANON_KEY:\s*"([^"]+)"/);

if (!urlMatch || !keyMatch) {
    console.log('❌ env.js에서 Supabase 설정을 찾을 수 없습니다.');
    process.exit(1);
}

const SUPABASE_URL = urlMatch[1];
const SUPABASE_ANON_KEY = keyMatch[1];

console.log('🔍 Supabase 연결 정보:');
console.log('URL:', SUPABASE_URL);
console.log('Key 길이:', SUPABASE_ANON_KEY.length, '자');

// REST API로 간단한 쿼리 테스트
async function testConnection() {
    try {
        console.log('\n📡 Supabase 연결 테스트 중...');
        
        const response = await fetch(`${SUPABASE_URL}/rest/v1/reservations`, {
            method: 'GET',
            headers: {
                'apikey': SUPABASE_ANON_KEY,
                'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
                'Content-Type': 'application/json',
                'Prefer': 'count=exact'
            }
        });

        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }

        const data = await response.json();
        const count = response.headers.get('Content-Range')?.split('/')[1] || '0';
        
        console.log('✅ 연결 성공!');
        console.log('📊 예약 테이블 레코드 수:', count);
        
        // 상품 테이블도 확인
        const productsResponse = await fetch(`${SUPABASE_URL}/rest/v1/products?select=count`, {
            method: 'GET',
            headers: {
                'apikey': SUPABASE_ANON_KEY,
                'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
                'Prefer': 'count=exact'
            }
        });
        
        if (productsResponse.ok) {
            const productsCount = productsResponse.headers.get('Content-Range')?.split('/')[1] || '0';
            console.log('📦 상품 테이블 레코드 수:', productsCount);
        }
        
        // 예약현황 테이블도 확인
        const bookingsResponse = await fetch(`${SUPABASE_URL}/rest/v1/bookings?select=count`, {
            method: 'GET',
            headers: {
                'apikey': SUPABASE_ANON_KEY,
                'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
                'Prefer': 'count=exact'
            }
        });
        
        if (bookingsResponse.ok) {
            const bookingsCount = bookingsResponse.headers.get('Content-Range')?.split('/')[1] || '0';
            console.log('📋 예약현황 테이블 레코드 수:', bookingsCount);
        }

        // OSO 카탈로그 테이블들도 확인
        const resourceResponse = await fetch(`${SUPABASE_URL}/rest/v1/resource_catalog?select=count`, {
            method: 'GET',
            headers: {
                'apikey': SUPABASE_ANON_KEY,
                'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
                'Prefer': 'count=exact'
            }
        });
        
        if (resourceResponse.ok) {
            const resourceCount = resourceResponse.headers.get('Content-Range')?.split('/')[1] || '0';
            console.log('🏠 자원 카탈로그 레코드 수:', resourceCount);
        }

        const skuResponse = await fetch(`${SUPABASE_URL}/rest/v1/sku_catalog?select=count`, {
            method: 'GET',
            headers: {
                'apikey': SUPABASE_ANON_KEY,
                'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
                'Prefer': 'count=exact'
            }
        });
        
        if (skuResponse.ok) {
            const skuCount = skuResponse.headers.get('Content-Range')?.split('/')[1] || '0';
            console.log('🎯 SKU 카탈로그 레코드 수:', skuCount);
        }
        
    } catch (error) {
        console.log('❌ 연결 실패:', error.message);
    }
}

testConnection();