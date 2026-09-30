# Script Build APK bảo mật cao cho ZenHome trên Windows (PowerShell)
Write-Host "🚀 Đang chuẩn bị build APK bảo mật cao..." -ForegroundColor Cyan

# Dọn dẹp bản build cũ
Write-Host "🧹 Chạy flutter clean..." -ForegroundColor Yellow
flutter clean

Write-Host "📦 Chạy flutter pub get..." -ForegroundColor Yellow
flutter pub get

# Build APK với các cờ bảo mật:
# --obfuscate: Đổi tên class, method, biến thành các ký tự vô nghĩa (a, b, c) để chống dịch ngược
# --split-debug-info: Tách file debug ra khỏi APK để giảm dung lượng và ẩn thông tin mã nguồn
Write-Host "🔨 Đang biên dịch APK release..." -ForegroundColor Green
flutter build apk --release --obfuscate --split-debug-info=./build/app/outputs/symbols

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Build hoàn tất!" -ForegroundColor Green
    Write-Host "📍 File APK nằm tại: build/app/outputs/flutter-apk/app-release.apk" -ForegroundColor Cyan
    Write-Host "📍 File Symbols nằm tại: build/app/outputs/symbols/" -ForegroundColor Cyan
} else {
    Write-Host "❌ Quá trình build gặp lỗi!" -ForegroundColor Red
}
