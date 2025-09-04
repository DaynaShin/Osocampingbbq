const { test, expect } = require('@playwright/test');

test.describe('오소마케팅 예약 시스템', () => {
  test.beforeEach(async ({ page }) => {
    // 배포된 사이트로 이동
    await page.goto('/');
    
    // 페이지가 완전히 로드될 때까지 대기
    await page.waitForLoadState('networkidle');
    
    // Supabase 클라이언트 초기화 대기
    await page.waitForFunction(() => window.supabaseClient !== undefined);
  });

  test('홈페이지 기본 요소 확인', async ({ page }) => {
    // 페이지 제목 확인
    await expect(page).toHaveTitle(/오소마케팅/);
    
    // 주요 요소들이 존재하는지 확인
    await expect(page.locator('h1')).toContainText('예약 신청');
    await expect(page.locator('#reservationForm')).toBeVisible();
    await expect(page.locator('#datePickerBtn')).toBeVisible();
  });

  test('예약 폼 유효성 검사', async ({ page }) => {
    const form = page.locator('#reservationForm');
    const submitBtn = page.locator('#submitBtn');
    
    // 빈 폼 제출 시도
    await submitBtn.click();
    
    // 필수 필드 검증
    const nameField = page.locator('#name');
    const phoneField = page.locator('#phone');
    
    await expect(nameField).toHaveClass(/error/);
    await expect(phoneField).toHaveClass(/error/);
  });

  test('전화번호 자동 포맷팅', async ({ page }) => {
    const phoneField = page.locator('#phone');
    
    // 전화번호 입력
    await phoneField.fill('01012345678');
    await phoneField.blur();
    
    // 자동 포맷팅 확인
    await expect(phoneField).toHaveValue('010-1234-5678');
  });

  test('달력 기능 테스트', async ({ page }) => {
    // 날짜 선택 버튼 클릭
    await page.locator('#datePickerBtn').click();
    
    // 달력 팝업이 나타나는지 확인
    await expect(page.locator('#calendarPopup')).toBeVisible();
    
    // 미래 날짜 클릭 (오늘 기준 7일 후)
    const today = new Date();
    const futureDate = new Date(today.getTime() + 7 * 24 * 60 * 60 * 1000);
    const day = futureDate.getDate();
    
    // 해당 날짜 클릭
    await page.locator(`#calendarDays .calendar-day:not(.disabled):not(.other-month)`).first().click();
    
    // 선택된 날짜가 표시되는지 확인
    await expect(page.locator('#selectedDateText')).not.toBeEmpty();
  });

  test('관리자 페이지 접근', async ({ page }) => {
    // 관리자 페이지로 이동
    await page.goto('/admin.html');
    
    // 관리자 페이지 요소 확인
    await expect(page.locator('h1')).toContainText('관리');
    await expect(page.locator('.admin-nav')).toBeVisible();
    await expect(page.locator('#dashboard-section')).toBeVisible();
  });

  test('상품 등록 폼 테스트', async ({ page }) => {
    // 관리자 페이지로 이동
    await page.goto('/admin.html');
    
    // 상품 등록 섹션으로 이동
    await page.locator('button:has-text("상품 등록")').click();
    
    // 상품 등록 폼이 보이는지 확인
    await expect(page.locator('#productForm')).toBeVisible();
    
    // 필수 필드들이 있는지 확인
    await expect(page.locator('#product_name')).toBeVisible();
    await expect(page.locator('#display_name')).toBeVisible();
    await expect(page.locator('#product_code')).toBeVisible();
    await expect(page.locator('#product_date')).toBeVisible();
  });

  test('상품 등록 유효성 검사', async ({ page }) => {
    await page.goto('/admin.html');
    await page.locator('button:has-text("상품 등록")').click();
    
    // 빈 폼으로 제출 시도
    await page.locator('#productForm button[type="submit"]').click();
    
    // 에러 클래스가 추가되었는지 확인
    await expect(page.locator('#product_name.error')).toBeVisible();
    await expect(page.locator('#display_name.error')).toBeVisible();
    await expect(page.locator('#product_code.error')).toBeVisible();
  });

  test('반응형 디자인 테스트', async ({ page }) => {
    // 모바일 크기로 변경
    await page.setViewportSize({ width: 375, height: 812 });
    
    // 주요 요소들이 여전히 보이는지 확인
    await expect(page.locator('h1')).toBeVisible();
    await expect(page.locator('#reservationForm')).toBeVisible();
    
    // 관리자 페이지도 테스트
    await page.goto('/admin.html');
    await expect(page.locator('.admin-nav')).toBeVisible();
  });

  test('네비게이션 테스트', async ({ page }) => {
    await page.goto('/admin.html');
    
    // 대시보드가 기본으로 활성화되어 있는지 확인
    await expect(page.locator('#dashboard-section')).toBeVisible();
    
    // 예약 목록으로 이동
    await page.locator('button:has-text("예약 목록")').click();
    await expect(page.locator('#reservations-section')).toBeVisible();
    
    // 상품 등록으로 이동
    await page.locator('button:has-text("상품 등록")').click();
    await expect(page.locator('#products-section')).toBeVisible();
    
    // 예약 현황으로 이동
    await page.locator('button:has-text("예약현황")').click();
    await expect(page.locator('#bookings-section')).toBeVisible();
  });
});