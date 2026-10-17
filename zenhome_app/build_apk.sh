#!/usr/bin/env bash

# ==============================================================================
#  ZENHOME SMART HOME - AUTOMATED APK BUILD SCRIPT (zenhome_app)
# ==============================================================================

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${CYAN}${BOLD}"
echo "================================================================="
echo "       🚀 BẮT ĐẦU XUẤT FILE APK ZENHOME (RELEASE) 🚀            "
echo "================================================================="
echo -e "${NC}"

cd "$(dirname "$0")" || exit

RAW_VERSION=$(grep '^version:' pubspec.yaml | head -n1 | awk '{print $2}' | tr -d '\r')
if [ -z "$RAW_VERSION" ]; then
    RAW_VERSION="1.3.0+10"
fi
SAFE_VERSION=$(echo "$RAW_VERSION" | tr '+' '_')

echo -e "${YELLOW}📦 Phiên bản: v${RAW_VERSION}${NC}"

echo -e "${CYAN}[1/4] Đang dọn dẹp bộ nhớ đệm (flutter clean)...${NC}"
flutter clean > /dev/null 2>&1 || flutter clean

echo -e "${CYAN}[2/4] Đang tải lại thư viện (flutter pub get)...${NC}"
flutter pub get

echo -e "${CYAN}[3/4] Đang biên dịch bản địa hóa song ngữ (flutter gen-l10n)...${NC}"
flutter gen-l10n

echo -e "${CYAN}[4/4] Đang biên dịch mã nguồn thành APK (Release mode)...${NC}"
flutter build apk --release "$@"

SRC_APK="build/app/outputs/flutter-apk/app-release.apk"

if [ -f "$SRC_APK" ]; then
    cp "$SRC_APK" ./ZenHome_Release.apk
    cp "$SRC_APK" "./ZenHome_v${SAFE_VERSION}.apk"
    
    # Đồng bộ sang máy chủ nếu có
    if [ -d "../zenhome-server/public" ]; then
        mkdir -p "../zenhome-server/public/downloads"
        cp "$SRC_APK" "../zenhome-server/public/downloads/zenhome-app-release.apk"
        echo -e "${GREEN}🔗 Đã đồng bộ file APK vào máy chủ: zenhome-server/public/downloads/zenhome-app-release.apk${NC}"
    fi

    echo ""
    echo -e "${GREEN}${BOLD}=================================================================${NC}"
    echo -e "${GREEN}${BOLD}✅ XUẤT APK THÀNH CÔNG!${NC}"
    echo -e "👉 File sẵn sàng tại: ${CYAN}$(pwd)/ZenHome_Release.apk${NC}"
    echo -e "👉 File lưu trữ theo phiên bản: ${CYAN}$(pwd)/ZenHome_v${SAFE_VERSION}.apk${NC}"
    echo -e "=================================================================${NC}"
else
    echo -e "${RED}❌ XUẤT APK THẤT BẠI! Vui lòng kiểm tra log lỗi ở trên.${NC}"
    exit 1
fi
