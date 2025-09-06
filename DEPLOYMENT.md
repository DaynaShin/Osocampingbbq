# 🚀 OSO Camping BBQ 웹사이트 배포 가이드

## 📋 배포 준비사항

### 필수 설정
- [x] Supabase 데이터베이스 설정 완료
- [x] 환경 변수 (`env.js`) 구성 완료  
- [x] 배포 설정 파일 준비 완료

### 배포 가능한 플랫폼
1. **Vercel** (추천) - 무료, 빠른 글로벌 CDN
2. **Netlify** - 무료, 쉬운 설정
3. **GitHub Pages** - 무료, GitHub 통합
4. **Firebase Hosting** - Google 플랫폼

---

## 🔥 Vercel 배포 (추천)

### 1. Vercel 계정 준비
1. [Vercel](https://vercel.com) 가입
2. GitHub 계정 연결

### 2. 배포 방법
#### 옵션 A: Vercel CLI 사용
```bash
# Vercel CLI 설치
npm i -g vercel

# 프로젝트 디렉토리에서 실행
vercel

# 프로젝트 설정
? Set up and deploy? [Y/n] y
? Which scope? Your Username
? Link to existing project? [y/N] n
? What's your project's name? oso-camping-bbq
? In which directory is your code located? ./
```

#### 옵션 B: GitHub 연결
1. Vercel 대시보드에서 "New Project" 클릭
2. GitHub repository 선택: `Osocampingbbq`
3. 배포 설정:
   - **Framework Preset**: Other
   - **Root Directory**: `./`
   - **Build Command**: (비워두기)
   - **Output Directory**: `./`

### 3. 환경 변수 설정
Vercel 대시보드 → Settings → Environment Variables:
```
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key
```

---

## 🎯 Netlify 배포

### 1. Netlify 계정 준비
1. [Netlify](https://netlify.com) 가입
2. GitHub 계정 연결

### 2. 배포 방법
#### 옵션 A: 드래그 앤 드롭
1. 프로젝트 폴더를 ZIP으로 압축
2. Netlify 대시보드에서 드래그 앤 드롭

#### 옵션 B: GitHub 연결
1. Netlify 대시보드에서 "New site from Git" 클릭
2. GitHub repository 선택: `Osocampingbbq`
3. 배포 설정:
   - **Branch**: `main`
   - **Build command**: (비워두기)
   - **Publish directory**: `./`

### 3. 환경 변수 설정
Netlify 대시보드 → Site settings → Environment variables

---

## 📁 GitHub Pages 배포

### 1. GitHub Repository 설정
1. Repository Settings → Pages
2. Source: Deploy from a branch
3. Branch: `main` / `/ (root)`

### 2. 홈페이지 설정
`home.html`이 메인 페이지이므로 다음 중 하나 선택:
- `home.html` → `index.html`로 이름 변경
- 또는 GitHub Pages 설정에서 커스텀 인덱스 페이지 설정

---

## ⚡ Firebase Hosting 배포

### 1. Firebase 프로젝트 설정
```bash
# Firebase CLI 설치
npm install -g firebase-tools

# Firebase 로그인
firebase login

# 프로젝트 초기화
firebase init hosting
```

### 2. `firebase.json` 설정
```json
{
  "hosting": {
    "public": "./",
    "ignore": [
      "firebase.json",
      "**/.*",
      "**/node_modules/**"
    ],
    "rewrites": [
      {
        "source": "/",
        "destination": "/home.html"
      }
    ]
  }
}
```

### 3. 배포
```bash
firebase deploy
```

---

## 🛠 배포 전 체크리스트

### 환경 변수 확인
- [ ] `env.js` 파일에 올바른 Supabase URL과 API Key 설정
- [ ] 배포 플랫폼에서 환경 변수 설정 완료

### 파일 확인
- [ ] 모든 HTML 파일이 정상적으로 연결되어 있음
- [ ] CSS, JS 파일 경로가 올바름
- [ ] 이미지 및 아이콘 리소스 접근 가능

### 기능 테스트
- [ ] 네비게이션 메뉴 작동
- [ ] 예약 시스템 정상 작동
- [ ] 관리자 페이지 접근 가능
- [ ] 반응형 디자인 확인

---

## 🔧 배포 후 설정

### 1. 도메인 설정 (선택사항)
각 플랫폼에서 커스텀 도메인 연결 가능:
- `osocampingbbq.com`
- `www.osocampingbbq.com`

### 2. SSL 인증서
모든 플랫폼에서 자동으로 SSL 인증서 제공

### 3. 성능 모니터링
- Google Analytics 연결
- 성능 측정 도구 설정

---

## 📞 문제 해결

### 일반적인 문제
1. **404 에러**: 파일 경로 및 라우팅 설정 확인
2. **환경 변수 오류**: Supabase 연결 설정 확인
3. **CSS/JS 로딩 실패**: 파일 경로 및 권한 확인

### 지원
문제가 발생하면 각 플랫폼의 공식 문서를 참조하거나, GitHub Issues에 문의하세요.

---

## 🎉 배포 완료!

배포가 완료되면:
1. 제공된 URL로 웹사이트 접속 확인
2. 모든 페이지 기능 테스트
3. 모바일 반응형 확인
4. 예약 시스템 테스트

**축하합니다! OSO Camping BBQ 웹사이트가 성공적으로 배포되었습니다! 🎊**