@echo off
echo ============================================
echo OSO Camping BBQ 웹사이트 배포 스크립트
echo ============================================
echo.

echo 1. Vercel CLI 설치 확인 중...
where vercel >nul 2>nul
if %errorlevel% neq 0 (
    echo Vercel CLI가 설치되어 있지 않습니다. 설치를 진행합니다...
    npm install -g vercel
    if %errorlevel% neq 0 (
        echo 오류: Vercel CLI 설치에 실패했습니다.
        pause
        exit /b 1
    )
) else (
    echo ✅ Vercel CLI가 이미 설치되어 있습니다.
)

echo.
echo 2. 프로젝트 배포 시작...
echo 📋 배포 진행 중 다음과 같이 설정해주세요:
echo    - Set up and deploy? Y
echo    - Project name: oso-camping-bbq
echo    - Directory: ./
echo.

vercel --prod

if %errorlevel% eq 0 (
    echo.
    echo 🎉 배포가 성공적으로 완료되었습니다!
    echo.
    echo 📝 다음 단계:
    echo 1. 제공된 URL로 웹사이트 접속 확인
    echo 2. Supabase 환경 변수가 올바르게 설정되었는지 확인
    echo 3. 모든 페이지와 기능이 정상 작동하는지 테스트
    echo.
    echo 💡 추가 설정이 필요한 경우 DEPLOYMENT.md를 참조하세요.
) else (
    echo ❌ 배포에 실패했습니다.
    echo DEPLOYMENT.md를 참조하여 수동으로 배포를 진행해주세요.
)

echo.
pause