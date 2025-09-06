### **프로젝트 개선을 위한 상세 실행 계획 (v2)**

이 계획은 시스템을 안정적이고 안전하며 유지보수 가능한 상태로 만들기 위한 구체적인 작업 절차를 정의합니다.

#### **1단계: 긴급 조치 및 환경 정상화 (P0)**

**목표:** 애플리케이션을 즉시 실행 가능한 상태로 복구하고 가장 기본적인 설정 오류를 수정합니다.

1.  **`env.js` 파일 생성 (즉시 실행)**
    *   **대상 파일:** `G:\내 드라이브\5.오소마케팅\2.develope\env.js` (신규 생성)
    *   **수행 작업:**
        1.  `env.example.js` 파일을 복사하여 `env.js` 파일을 생성합니다.
        2.  `env.js` 파일의 내용을 아래와 같이 실제 Supabase 프로젝트 정보로 수정합니다. (이 키들은 Supabase 대시보드의 `Project Settings > API` 에서 확인 가능합니다.)
            ```javascript
            // G:\내 드라이브\5.오소마케팅\2.develope\env.js

            (function() {
              window.__ENV = {
                SUPABASE_URL: "https://[YOUR_SUPABASE_PROJECT_ID].supabase.co", // 실제 URL로 교체
                SUPABASE_ANON_KEY: "[YOUR_SUPABASE_ANON_KEY]", // 실제 Anon Key로 교체
              };
            })();
            ```
    *   **검증:** 브라우저에서 `index.html`과 `admin-login.html`을 열었을 때, 개발자 도구(F12)의 콘솔 탭에 Supabase 연결 오류가 더 이상 나타나지 않는지 확인합니다.

2.  **`package.json` 설정 수정**
    *   **대상 파일:** `G:\내 드라이브\5.오소마케팅\2.develope\package.json`
    *   **수행 작업:** 파일의 8번째 줄을 아래와 같이 수정합니다.
        *   **변경 전:** `"main": "supabase-config.js",`
        *   **변경 후:** `"main": "supabase-config-v2.js",`
        *   **(권장)** 또는, 해당 라인을 완전히 삭제합니다. 이 프로젝트는 Node.js 런타임 환경이 아니므로 이 필드는 무의미합니다.

#### **2단계: 핵심 아키텍처 결함 수정 (P1)**

**목표:** 시스템의 가장 심각한 취약점인 중복 예약 문제와 관리자 기능의 보안 허점을 해결합니다.

1.  **중복 예약 방지를 위한 원자적 예약 함수(RPC) 생성**
    *   **대상:** Supabase 대시보드의 `Database > Functions` 메뉴
    *   **수행 작업:** 아래 내용으로 `create_reservation_atomic` 함수를 새로 생성합니다. 이 함수는 재고 확인과 예약을 한 번에 처리하여 동시성 문제를 해결합니다.
        ```sql
        -- 함수 이름: create_reservation_atomic
        -- 파라미터: p_sku_code TEXT, p_reservation_date DATE, p_guest_count INT, p_name TEXT, p_phone TEXT, p_email TEXT, p_special_requests TEXT
        -- 반환 타입: JSON

        DECLARE
          v_availability RECORD;
          v_new_reservation reservations%ROWTYPE;
          v_total_price INT;
        BEGIN
          -- 1. 가용성 확인 및 행 잠금 (동시 접근 방지)
          SELECT * INTO v_availability
          FROM availability
          WHERE sku_code = p_sku_code AND date = p_reservation_date
          FOR UPDATE;

          -- 2. 재고가 없으면 예외 처리
          IF v_availability IS NULL OR v_availability.available_slots <= v_availability.booked_slots THEN
            RAISE EXCEPTION '죄송합니다. 해당 슬롯의 예약이 방금 마감되었습니다.';
          END IF;

          -- 3. 가격 계산 (기존 함수 재사용)
          SELECT (price_info->>'finalPrice')::INT INTO v_total_price
          FROM calculate_total_price_with_guests(
            (SELECT resource_code FROM sku_catalog WHERE sku_code = p_sku_code),
            (SELECT time_slot_code FROM sku_catalog WHERE sku_code = p_sku_code),
            p_reservation_date,
            p_guest_count
          ) as price_info;

          -- 4. 예약 테이블에 삽입
          INSERT INTO reservations (sku_code, reservation_date, guest_count, name, phone, email, special_requests, total_amount, status)
          VALUES (p_sku_code, p_reservation_date, p_guest_count, p_name, p_phone, p_email, p_special_requests, v_total_price, 'pending')
          RETURNING * INTO v_new_reservation;

          -- 5. 가용성 테이블 업데이트 (예약된 슬롯 수 증가)
          UPDATE availability
          SET booked_slots = booked_slots + 1
          WHERE id = v_availability.id;

          -- 6. 성공 결과 반환
          RETURN json_build_object('success', true, 'reservation', row_to_json(v_new_reservation));
        END;
        ```
    *   **프론트엔드 수정:**
        *   `supabase-config-v2.js`의 `createReservation` 함수를 위 RPC를 호출하도록 변경합니다.
        *   `oso-reservation.js`의 `handleFormSubmit` 함수에서 RPC 호출 결과에 따라 성공/실패 메시지를 표시하도록 수정합니다.

2.  **안전한 관리자 기능(예약 확정/취소) 구현**
    *   **대상:** Supabase 대시보드의 `Database > Functions` 메뉴
    *   **수행 작업:** 예약 확정, 취소 등 관리자 작업을 위한 별도의 RPC 함수를 생성합니다.
        ```sql
        -- 함수 이름: confirm_reservation_admin
        -- 파라미터: p_reservation_id INT
        -- 반환 타입: BOOLEAN

        BEGIN
          -- 현재 사용자가 관리자인지 확인 (보안 강화)
          IF NOT is_admin_authenticated() OR NOT has_admin_permission('reservations', 'write') THEN
            RAISE EXCEPTION '권한이 없습니다.';
          END IF;

          -- 예약 상태를 'confirmed'로 변경
          UPDATE reservations
          SET status = 'confirmed'
          WHERE id = p_reservation_id AND status = 'pending';

          RETURN FOUND; -- 업데이트 성공 여부 반환
        END;
        ```
        *   `cancel_reservation_admin` 함수도 위와 유사하게 생성합니다.
    *   **프론트엔드 수정:**
        *   `admin.html`의 `confirmReservation`, `cancelReservation` 함수에서 `updateReservation`을 직접 호출하는 대신, 새로 만든 `confirm_reservation_admin`, `cancel_reservation_admin` RPC를 호출하도록 `admin-functions.js`와 `supabase-config-v2.js`를 수정합니다.

#### **3단계: 코드 품질 및 구조 개선 (P2)**

**목표:** 중복 코드를 제거하고 비효율적인 로직을 개선하여 유지보수성을 높입니다.

1.  **가격 계산 로직 DB로 통합**
    *   **대상 파일:** `oso-reservation.js`
    *   **수행 작업:**
        1.  `oso-reservation.js` 파일 내의 `calculateDynamicPrice` JavaScript 함수를 삭제합니다.
        2.  `updateVenueSelection` 함수 내에서 가격을 표시하는 부분을 `calculate_total_price_with_guests` RPC를 호출하여 받아온 가격 정보로 대체합니다.

2.  **오래된 '상품(Products)' 기능 완전 제거**
    *   **대상 파일:** `admin.html`, `admin-functions.js`, `supabase/` 폴더
    *   **수행 작업:**
        1.  `admin.html`에서 `id="products-section"`, `id="product-list-section"`을 포함한 모든 관련 HTML 블록과 메뉴 버튼을 삭제합니다.
        2.  `admin-functions.js`에서 `handleProductSubmit`, `loadProducts`, `displayProducts` 등 'product'와 관련된 모든 JavaScript 함수를 삭제합니다.
        3.  `supabase/schema.sql`, `supabase/schema-fixed.sql`, `supabase/seed.sql` 파일들을 `supabase/archive/` 와 같은 백업 폴더로 이동시켜 현재 빌드에서 제외시킵니다.

3.  **DB 호출 최적화 (가용성 초기화)**
    *   **대상:** Supabase 대시보드 및 `oso-reservation.js`
    *   **수행 작업:**
        1.  `oso-reservation.js`의 `updateVenueSelection` 함수에서 `initializeAvailability(date)` 호출 코드를 삭제합니다.
        2.  Supabase 대시보드의 `Database > Cron Jobs`에서 매일 자정에 `initializeAvailability(CURRENT_DATE + INTERVAL '7 day')` 와 같이 미래의 특정 날짜 가용성을 미리 생성하는 스케줄링 작업을 설정합니다.

#### **4단계: 최종 정리 및 리팩토링 (P3)**

**목표:** 코드의 가독성을 높이고 자잘한 오류들을 수정하여 프로젝트 완성도를 높입니다.

1.  **전역 스코프 오염 방지 (모듈화)**
    *   **대상 파일:** `supabase-config-v2.js`, `admin-functions.js` 및 모든 HTML 파일
    *   **수행 작업:**
        *   `supabase-config-v2.js`의 모든 `window.functionName = ...` 라인을 삭제하고, 파일 하단에 아래와 같이 하나의 객체로 묶어 노출합니다.
            ```javascript
            window.OSO_API = {
              getResourceCatalog,
              getTimeSlotCatalog,
              createReservation: createReservationAtomic, // 새로 만든 RPC 호출 함수로 교체
              // ... 다른 모든 함수들
            };
            ```
        *   `index.html`, `admin.html` 등에서 기존에 `createReservation(...)`으로 호출하던 부분을 `OSO_API.createReservation(...)`으로 수정합니다.

2.  **자잘한 오류 및 UI 수정**
    *   **대상 파일:** 모든 `.html` 파일, `backup_old_files` 디렉터리
    *   **수행 작업:**
        1.  `index.html`, `admin.html` 등에서 `<!-- orig: ?함 -->` 과 같이 깨진 한글 주석을 모두 찾아 삭제하거나 올바른 내용으로 수정합니다.
        2.  `G:\내 드라이브\5.오소마케팅\2.develope\backup_old_files` 디렉터리를 프로젝트에서 완전히 삭제합니다.
