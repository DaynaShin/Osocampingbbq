// 수동 브라우저 테스트 스크립트
console.log('🚀 오소마케팅 예약 시스템 수동 테스트 시작\n');

const testUrl = 'https://2develope-c4uqskpjx-daynashins-projects.vercel.app';

console.log('📋 테스트 체크리스트:');
console.log(`
1. 📱 브라우저에서 다음 URL 접속:
   ${testUrl}

2. ✅ 홈페이지 기본 확인:
   - 페이지 제목에 "오소마케팅" 포함
   - "예약 신청" 제목 표시
   - 예약 폼이 보임
   - 달력 선택 버튼이 보임

3. ✅ 예약 폼 테스트:
   - 이름, 전화번호 등 필수 필드 입력
   - 전화번호 자동 포맷팅 (010-1234-5678)
   - 빈 폼 제출 시 유효성 검사

4. ✅ 달력 기능 테스트:
   - 날짜 선택 버튼 클릭
   - 달력 팝업 표시
   - 미래 날짜 선택 가능
   - 과거 날짜 비활성화

5. ✅ 관리자 페이지 테스트:
   ${testUrl}/admin.html
   - 대시보드 표시
   - 예약 목록, 상품 등록, 예약현황 네비게이션
   - 상품 등록 폼 동작

6. ✅ 반응형 디자인:
   - 모바일 크기로 브라우저 조정
   - 레이아웃이 적절히 조정되는지 확인

7. ✅ 상품명/상품코드 분리 기능:
   - 관리자에서 상품 등록 시 관리용 상품명과 고객용 표시명 분리
   - 고객 페이지에서 고객용 표시명으로 표시
`);

console.log('\n🔧 브라우저 개발자 도구로 확인할 항목:');
console.log(`
1. Console 탭:
   - JavaScript 에러 없음
   - Supabase 연결 성공 메시지

2. Network 탭:
   - 리소스 로딩 상태 확인
   - API 요청/응답 확인

3. Application 탭:
   - Supabase 설정 확인
`);

console.log('\n✨ 테스트 완료 후 보고:');
console.log('- 모든 기능이 정상 작동하면 ✅');
console.log('- 문제가 있으면 구체적인 오류 내용 보고');

console.log('\n🎯 자동화된 테스트는 Playwright 환경 설정 완료 후 실행 가능');
console.log('현재는 Windows 경로 문제로 인해 수동 테스트를 권장합니다.');