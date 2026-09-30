#!/bin/bash

# =========================================================
# SCRIPT BUILD APK CHO DỰ ÁN ZENHOME
# =========================================================

echo "==============================================="
echo "    🚀 BẮT ĐẦU XUẤT FILE APK (RELEASE) 🚀"
echo "==============================================="

# Chuyển đến thư mục chứa script (zenhome_app)
cd "$(dirname "$0")" || exit

echo "[1/3] Đang dọn dẹp bộ nhớ đệm (flutter clean)..."
flutter clean

echo "[2/3] Đang tải lại thư viện (flutter pub get)..."
flutter pub get

echo "[3/3] Đang biên dịch mã nguồn thành APK..."
# Biên dịch ra file APK (bản Release cho hiệu năng tốt nhất)
flutter build apk --release

# Kiểm tra xem lệnh build có thành công không (mã lỗi = 0)
if [ $? -eq 0 ]; then
    echo "==============================================="
    echo "✅ XUẤT APK THÀNH CÔNG!"
    echo "Đường dẫn gốc: build/app/outputs/flutter-apk/app-release.apk"
    
    # Copy file APK ra ngay thư mục dự án cho dễ lấy
    cp build/app/outputs/flutter-apk/app-release.apk ./ZenHome_Release.apk
    
    echo "👉 File APK của bạn đã sẵn sàng tại: $(pwd)/ZenHome_Release.apk"
    echo "==============================================="
else
    echo "==============================================="
    echo "❌ XUẤT APK THẤT BẠI!"
    echo "Vui lòng đọc dòng lỗi (error) ở phía trên để sửa."
    echo "==============================================="
fi
