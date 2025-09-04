# 오소마케팅 예약 시스템

간편한 예약 신청과 관리를 위한 정적(Static) 웹 앱입니다. Supabase를 백엔드로 사용합니다.

## 주요 기능
- 예약 신청: 고객이 이름/연락처/날짜/시간/서비스를 입력해 예약 요청
- 예약 캘린더: 커스텀 달력으로 날짜 선택, 해당 날짜의 예약 가능 상품 조회/선택
- 관리자 대시보드: 통계, 최근 예약, 예약 목록 필터/상세/상태 변경, 상품 등록/목록, 예약 현황 관리

## 프로젝트 구조
```
index.html              # 고객 예약 페이지
admin.html              # 관리자 페이지
styles.css              # 스타일 시트
script.js               # 고객측 스크립트 (예약/캘린더 연계)
admin-functions.js      # 관리자측 보조 스크립트 (표시/모달/메시지)
calendar.js             # 커스텀 캘린더 위젯
supabase-config.js      # Supabase 클라이언트 및 API 래퍼
env.example.js          # env.js 템플릿 (복사해 사용)
scripts/                # 배포용 env.js 생성 스크립트
supabase/               # 테이블 스키마 및 RLS 정책 샘플
```

## 환경 변수 설정 (중요)
Supabase 키를 코드에 직접 하드코딩하지 않고 `env.js`로 분리했습니다.

1) 템플릿 복사 후 값 설정
```
cp env.example.js env.js
# env.js 내 값 입력
window.__ENV = {
  SUPABASE_URL: "https://YOUR_PROJECT.supabase.co",
  SUPABASE_ANON_KEY: "YOUR_ANON_KEY"
};
```
2) `env.js`는 `.gitignore`에 포함되어 커밋되지 않습니다.

### 배포 시 env.js 자동 생성
다음 중 하나를 사용하세요.
- Node 스크립트
  ```bash
  SUPABASE_URL=... SUPABASE_ANON_KEY=... node scripts/generate-env.js
  ```
- Bash 스크립트 (Linux/macOS)
  ```bash
  export SUPABASE_URL=...
  export SUPABASE_ANON_KEY=...
  bash scripts/generate-env.sh
  ```
- PowerShell (Windows/CI)
  ```powershell
  $env:SUPABASE_URL="..."; $env:SUPABASE_ANON_KEY="..."; ./scripts/generate-env.ps1
  ```

## Supabase 스키마와 정책
폴더 `supabase/` 포함 파일을 Supabase SQL Editor에서 실행하세요.

- `supabase/schema.sql`: 테이블 생성
  - `reservations`(예약), `products`(상품), `bookings`(예약현황)
- `supabase/policies.dev.sql`: 개발 편의용(브라우저 anon에서도 전체 CRUD 가능)
- `supabase/policies.secure.sql`: 보안 권장안(서비스 롤 필요, SPA만으로는 관리자 기능 동작 불가)

권장: 개발 환경에서는 dev 정책, 운영 환경에서는 secure 정책 + 서버 사이드(Admin API)로 관리자 기능 처리.

## 로컬 실행
정적 호스트로 띄우면 됩니다.
```
python -m http.server 8000
# http://localhost:8000 접속
```

### 가상 데이터(Seed) 생성
- SQL로 생성: Supabase SQL Editor에서 다음 파일 실행
  - `supabase/seed.sql` (샘플 상품/예약/예약현황)
- 브라우저로 생성: `seed.html` 페이지 열기 → 버튼 클릭으로 생성/초기화
  - 주의: 운영 보안 정책(`policies.secure.sql`) 사용 시 브라우저에서 시드/삭제가 제한될 수 있습니다.

## 빌드/배포 가이드 (Vercel 예시)
- 프로젝트 생성 → Framework: Other(Static)
- 빌드 커맨드: (없음)
- Output: 루트(`/`)
- Environment Variables 설정: `SUPABASE_URL`, `SUPABASE_ANON_KEY`
- Deploy Hook에서 배포 전 `env.js` 생성(빌드 스텝에 추가)
  - Example: `SUPABASE_URL=$SUPABASE_URL SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY node scripts/generate-env.js`

## 보안 참고
- 현재 저장소는 프론트엔드에서 anon key를 사용합니다. 운영 환경에서는 RLS를 강화하고 관리자 기능은 서버(서비스 롤)로 위임하는 것을 권장합니다.
- 고객 개인정보(이름/연락처/이메일)는 PII입니다. 접근 정책을 엄격히 설정하세요.

## 텍스트/복구 노트
이번 커밋에서 손상된 한글/템플릿 문법을 복구했고, 원래 위치에 `orig:` 주석으로 원문(손상본) 힌트를 남겼습니다. 추후 브랜드 어조에 맞게 문구만 재조정하면 됩니다.
