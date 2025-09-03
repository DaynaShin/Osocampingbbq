# 오소마케팅 예약 시스템

간편한 예약 신청 및 관리 시스템입니다.

## 🚀 기능

### 고객용 기능
- 📅 달력을 통한 직관적인 날짜 선택
- 🛍️ 날짜별 예약 가능한 상품 조회
- ⚡ 원클릭 예약 신청
- 📱 반응형 디자인 (모바일 지원)

### 관리자용 기능
- 📊 예약 현황 대시보드
- 🎯 상품 등록 및 관리
- 📋 예약 목록 조회 및 관리
- 📈 통계 및 분석

## 🛠️ 기술 스택

- **Frontend**: HTML5, CSS3, JavaScript (ES6+)
- **Backend**: Supabase
- **Database**: PostgreSQL (Supabase)
- **Deployment**: Vercel

## 📁 프로젝트 구조

```
├── index.html              # 고객용 예약 페이지
├── admin.html              # 관리자 페이지
├── styles.css              # 통합 스타일시트
├── script.js               # 고객용 자바스크립트
├── admin-functions.js      # 관리자용 자바스크립트
├── calendar.js             # 달력 위젯
├── supabase-config.js      # Supabase 설정 및 API
└── README.md              # 프로젝트 문서
```

## 🔧 설치 및 실행

1. 프로젝트 클론
```bash
git clone [repository-url]
cd [project-directory]
```

2. Supabase 설정
   - `supabase-config.js`에서 본인의 Supabase URL과 API Key 설정
   - 데이터베이스 스키마 설정 (`database-schema.sql` 참조)

3. 로컬 서버 실행
   - Live Server 확장 프로그램 사용하거나
   - Python: `python -m http.server 8000`
   - Node.js: `npx http-server`

## 🔐 환경 설정

Supabase 프로젝트 설정이 필요합니다:
1. [Supabase](https://supabase.com)에서 새 프로젝트 생성
2. 데이터베이스 스키마 실행
3. API 키 설정

## 📱 주요 페이지

- `/` - 고객용 예약 신청 페이지
- `/admin.html` - 관리자 대시보드

## 🎯 주요 기능

### 달력 기반 예약 시스템
- 사용자가 달력에서 날짜 클릭
- 해당 날짜의 예약 가능한 상품 자동 표시
- 상품 선택 후 즉시 예약 처리

### 실시간 상품 관리
- 관리자가 등록한 상품이 실시간으로 고객에게 표시
- 예약된 상품은 자동으로 목록에서 제외
- 상품별 상세 정보 및 가격 표시

## 🤝 기여하기

1. Fork 프로젝트
2. Feature 브랜치 생성
3. 변경사항 커밋
4. 브랜치에 Push
5. Pull Request 생성

## 📄 라이선스

MIT License

---

© 2025 오소마케팅. All rights reserved.