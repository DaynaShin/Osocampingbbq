const { test, expect } = require('@playwright/test');

test.describe('오소마케팅 예약 시스템 기본 테스트', () => {
  test('홈페이지 로딩 테스트', async ({ page }) => {
    console.log('테스트 시작: 홈페이지 접속');
    
    // 배포된 사이트로 이동
    await page.goto('https://2develope-c4uqskpjx-daynashins-projects.vercel.app');
    
    // 페이지 제목 확인
    const title = await page.title();
    console.log('페이지 제목:', title);
    
    // 기본 요소 확인
    const h1 = page.locator('h1');
    await expect(h1).toBeVisible();
    
    const h1Text = await h1.textContent();
    console.log('H1 텍스트:', h1Text);
    
    console.log('홈페이지 테스트 완료');
  });

  test('예약 폼 존재 확인', async ({ page }) => {
    console.log('테스트 시작: 예약 폼 확인');
    
    await page.goto('https://2develope-c4uqskpjx-daynashins-projects.vercel.app');
    
    // 예약 폼이 존재하는지 확인
    const form = page.locator('#reservationForm');
    await expect(form).toBeVisible();
    
    // 필수 입력 필드들 확인
    await expect(page.locator('#name')).toBeVisible();
    await expect(page.locator('#phone')).toBeVisible();
    
    console.log('예약 폼 테스트 완료');
  });

  test('관리자 페이지 접속 테스트', async ({ page }) => {
    console.log('테스트 시작: 관리자 페이지 접속');
    
    await page.goto('https://2develope-c4uqskpjx-daynashins-projects.vercel.app/admin.html');
    
    // 관리자 페이지 요소 확인
    const adminTitle = page.locator('h1');
    await expect(adminTitle).toBeVisible();
    
    const titleText = await adminTitle.textContent();
    console.log('관리자 페이지 제목:', titleText);
    
    console.log('관리자 페이지 테스트 완료');
  });
});