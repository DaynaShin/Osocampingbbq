# OSO Camping BBQ 예약 시스템

OSO 캠핑 BBQ를 위한 간편한 예약 신청 및 관리 시스템입니다.

## 🎯 주요 기능

- ✅ **예약 신청 시스템**: 고객이 쉽게 예약을 신청할 수 있습니다
- ✅ **관리자 시스템**: 예약 승인, 취소, 삭제 기능
- ✅ **실시간 알림**: Supabase 기반 실시간 데이터 동기화
- ✅ **보안 시스템**: RLS 정책 기반 안전한 데이터 관리
- ✅ **다중 플랫폼 지원**: 웹, 모바일 호환

## 🚀 배포 URL

**운영 사이트**: [https://osocampingbbq.vercel.app](https://osocampingbbq.vercel.app)

## 📋 시스템 구성

### Frontend
- **HTML5 + Vanilla JavaScript**: 가볍고 빠른 웹 인터페이스
- **Supabase-js**: 실시간 데이터베이스 연동
- **Responsive Design**: 모바일 친화적 디자인

### Backend
- **Supabase**: PostgreSQL 데이터베이스 + 실시간 기능
- **RLS (Row Level Security)**: 보안 정책 적용
- **SECURITY DEFINER Functions**: 관리자 권한 시스템

### 배포
- **Vercel**: 자동 배포 및 CDN
- **GitHub Actions**: CI/CD 파이프라인

## 🛠️ 개발 환경 설정

### 1. 저장소 클론
```bash
git clone https://github.com/Dami-Shin-01/Osocampingbbq.git
cd Osocampingbbq
```

### 2. 환경 변수 설정
```bash
cp env.example.js env.js
# env.js에 Supabase URL과 ANON KEY 입력
```

### 3. 로컬 서버 실행
```bash
# Python 3 사용 시
python -m http.server 8080

# Node.js 사용 시  
npx serve -p 8080
```

### 4. 브라우저에서 접속
```
http://localhost:8080
```

## 📚 P1 테스트 가이드

P1 관리자 보안 시스템 테스트를 위한 완전한 가이드가 준비되어 있습니다:

- **P1_FINAL_EXECUTION_GUIDE.md**: 단계별 실행 가이드
- **ULTIMATE_FINAL_ANALYSIS.md**: 종합 분석 보고서

### 테스트 순서
1. **예약 생성**: `create-test-reservation.html`
2. **관리자 로그인**: `admin-login.html`  
3. **보안 시스템 테스트**: `test-admin-security.html`

## 🔧 기술 스택

- **Database**: Supabase PostgreSQL
- **Frontend**: HTML5, JavaScript ES6+
- **Authentication**: Supabase Auth
- **Real-time**: Supabase Realtime
- **Deployment**: Vercel
- **Version Control**: Git + GitHub

## 📊 프로젝트 구조

```
├── home.html              # 메인 페이지
├── about.html             # 소개 페이지  
├── contact.html           # 연락처 페이지
├── create-test-reservation.html  # 예약 생성 (테스트용)
├── admin-login.html       # 관리자 로그인
├── test-admin-security.html      # 관리자 보안 테스트
├── supabase/              # 데이터베이스 스키마 및 함수
│   ├── complete-admin-system-fix.sql
│   ├── final-admin-permissions-fix.sql
│   └── ...
├── supabase-config-v2.js  # Supabase 클라이언트 설정
├── admin-functions.js     # 관리자 기능
└── env.js                 # 환경 변수 (gitignore)
```

## 🎉 최근 업데이트

### 2025-09-06: P1 관리자 보안 시스템 완전 수정
- ✅ admin_profiles 테이블 의존성 문제 해결
- ✅ create_test_admin, verify_admin_by_email 함수 추가
- ✅ UUID 타입 처리 오류 수정 (parseInt 제거)
- ✅ 종합 분석 문서 6개 생성
- ✅ 불필요한 fix 파일 정리

## 👥 기여자

- **개발**: Dami-Shin-01
- **분석 및 최적화**: Claude Code Assistant

## 📄 라이선스

ISC License

---

**🚀 OSO Camping BBQ와 함께 멋진 캠핑을 즐겨보세요!**