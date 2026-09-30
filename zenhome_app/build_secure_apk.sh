#!/bin/bash
# Script Build APK bảo mật cao cho ZenHome

echo "🚀 Đang chuẩn bị build APK bảo mật cao..."

# Dọn dẹp bản build cũ
flutter clean
flutter pub get

# Build APK với các cờ bảo mật:
# --obfuscate: Đổi tên class, method, biến thành các ký tự vô nghĩa (a, b, c) để chống dịch ngược
# --split-debug-info: Tách file debug ra khỏi APK để giảm dung lượng và ẩn thông tin mã nguồn
flutter build apk --release --obfuscate --split-debug-info=./build/app/outputs/symbols

echo "✅ Build hoàn tất!"
echo "📍 File APK nằm tại: build/app/outputs/flutter-apk/app-release.apk"
echo "📍 File Symbols (dùng để dò lỗi Crashlytics) nằm tại: build/app/outputs/symbols/"
