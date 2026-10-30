@echo off
chcp 65001 >nul
echo ===================================================
echo 🚀 Kafa Sayımı - Flutter Web GitHub Pages Derleyici
echo ===================================================
echo.
set /p REPO="GitHub Repository adınızı girin (Varsayılan: KafaSayimi): "
if "%REPO%"=="" set REPO=KafaSayimi

echo.
echo Derleme başlatılıyor: Base Href = /%REPO%/
call flutter build web --release --base-href "/%REPO%/"

if %errorlevel% neq 0 (
    echo.
    echo ❌ Derleme sırasında bir hata oluştu!
    pause
    exit /b %errorlevel%
)

echo.
echo 📄 SPA (Sayfa yenileme) desteği için 404.html kopyalanıyor...
copy build\web\index.html build\web\404.html >nul

echo.
echo ===================================================
echo ✅ Web derlemesi başarıyla tamamlandı!
echo 📂 Çıktı klasörü: build\web
echo ===================================================
pause

