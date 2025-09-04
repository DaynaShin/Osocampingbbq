const { chromium } = require('playwright');

async function runTest() {
  console.log('🚀 Playwright 테스트 시작');
  
  try {
    console.log('브라우저 실행 중...');
    const browser = await chromium.launch({ headless: false });
    const page = await browser.newPage();
    
    console.log('페이지 이동 중...');
    await page.goto('https://2develope-c4uqskpjx-daynashins-projects.vercel.app');
    
    console.log('페이지 제목 가져오는 중...');
    const title = await page.title();
    console.log('✅ 페이지 제목:', title);
    
    console.log('H1 요소 확인 중...');
    const h1Text = await page.locator('h1').textContent();
    console.log('✅ H1 텍스트:', h1Text);
    
    console.log('예약 폼 확인 중...');
    const formExists = await page.locator('#reservationForm').isVisible();
    console.log('✅ 예약 폼 존재:', formExists);
    
    console.log('전화번호 입력 테스트...');
    await page.fill('#phone', '01012345678');
    await page.locator('#phone').blur();
    const phoneValue = await page.inputValue('#phone');
    console.log('✅ 전화번호 포맷팅:', phoneValue);
    
    console.log('관리자 페이지 테스트...');
    await page.goto('https://2develope-c4uqskpjx-daynashins-projects.vercel.app/admin.html');
    const adminTitle = await page.locator('h1').textContent();
    console.log('✅ 관리자 페이지 제목:', adminTitle);
    
    console.log('브라우저 종료 중...');
    await browser.close();
    
    console.log('🎉 모든 테스트 완료!');
    
  } catch (error) {
    console.error('❌ 테스트 실패:', error.message);
  }
}

runTest();