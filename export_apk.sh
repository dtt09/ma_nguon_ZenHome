#!/usr/bin/env bash

# ==============================================================================
#  ZENHOME SMART HOME - AUTOMATED APK BUILD & EXPORT SCRIPT
# ==============================================================================
#  Tự động dọn dẹp, đồng bộ đa ngôn ngữ, biên dịch bản phát hành và xuất file APK
#  Hỗ trợ cập nhật OTA tự động qua máy chủ ZenHome REST API
# ==============================================================================

set -e # Dừng ngay lập tức nếu gặp lỗi

# Định dạng màu cho terminal
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${CYAN}${BOLD}"
echo "================================================================="
echo "       🏠 ZENHOME SMART HOME - XUẤT BẢN PHÁT HÀNH APK 🚀       "
echo "================================================================="
echo -e "${NC}"

# 1. Xác định thư mục dự án
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -d "$SCRIPT_DIR/zenhome_app" ]; then
    APP_DIR="$SCRIPT_DIR/zenhome_app"
    ROOT_DIR="$SCRIPT_DIR"
elif [ -f "$SCRIPT_DIR/pubspec.yaml" ]; then
    APP_DIR="$SCRIPT_DIR"
    ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
else
    echo -e "${RED}❌ LỖI: Không tìm thấy thư mục dự án zenhome_app!${NC}"
    exit 1
fi

# 2. Kiểm tra Flutter SDK
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}❌ LỖI: Lệnh 'flutter' không được tìm thấy trong PATH hệ thống!${NC}"
    echo -e "${YELLOW}👉 Hãy chắc chắn bạn đã cài đặt Flutter SDK và thêm vào biến môi trường PATH.${NC}"
    exit 1
fi

# 3. Đọc phiên bản từ pubspec.yaml
cd "$APP_DIR"
RAW_VERSION=$(grep '^version:' pubspec.yaml | head -n1 | awk '{print $2}' | tr -d '\r')
if [ -z "$RAW_VERSION" ]; then
    RAW_VERSION="1.3.0+10"
fi

SAFE_VERSION=$(echo "$RAW_VERSION" | tr '+' '_')

echo -e "${BLUE}📦 Phiên bản ứng dụng:${NC} ${BOLD}v${RAW_VERSION}${NC}"
echo -e "${BLUE}📂 Thư mục mã nguồn App:${NC} ${APP_DIR}"
echo ""

# 4. Phân tích các tham số dòng lệnh
BUILD_FLAGS=""
MODE_DESC="Bản chuẩn Release (Universal APK)"

for arg in "$@"; do
    case $arg in
        --split-per-abi)
            BUILD_FLAGS="$BUILD_FLAGS --split-per-abi"
            MODE_DESC="Chia nhỏ APK theo kiến trúc CPU (Split per ABI)"
            ;;
        --obfuscate)
            BUILD_FLAGS="$BUILD_FLAGS --obfuscate --split-debug-info=./build/app/outputs/symbols"
            MODE_DESC="Bảo mật cao (Obfuscated & Tách Debug Symbols)"
            ;;
        --no-clean)
            SKIP_CLEAN=true
            ;;
        *)
            ;;
    esac
done

echo -e "${PURPLE}⚙️  Chế độ biên dịch:${NC} ${BOLD}${MODE_DESC}${NC}"
echo "-----------------------------------------------------------------"

# Giải phóng Gradle Daemon cũ
if [ -f "android/gradlew" ]; then
    chmod +x android/gradlew 2>/dev/null || true
    bash android/gradlew --stop > /dev/null 2>&1 || true
fi

# [Bước 1/4] Dọn dẹp cache
if [ "$SKIP_CLEAN" = true ]; then
    echo -e "${YELLOW}[1/4] Bỏ qua bước flutter clean theo yêu cầu...${NC}"
else
    echo -e "${CYAN}[1/4] Đang dọn dẹp bộ nhớ đệm (flutter clean)...${NC}"
    flutter clean > /dev/null 2>&1 || true
fi

# [Bước 2/4] Tải thư viện
echo -e "${CYAN}[2/4] Đang cập nhật thư viện (flutter pub get)...${NC}"
flutter pub get

# [Bước 3/4] Biên dịch đa ngôn ngữ
echo -e "${CYAN}[3/4] Đang biên dịch bản địa hóa song ngữ (flutter gen-l10n)...${NC}"
flutter gen-l10n

# [Bước 4/4] Biên dịch APK
echo -e "${CYAN}[4/4] Đang tiến hành biên dịch APK (Release mode)...${NC}"
echo -e "${YELLOW}⏳ Quá trình này có thể mất từ 1 - 3 phút tùy cấu hình máy...${NC}"

BUILD_START_TIME=$(date +%s)
flutter build apk --release $BUILD_FLAGS
BUILD_END_TIME=$(date +%s)
BUILD_DURATION=$((BUILD_END_TIME - BUILD_START_TIME))

# 5. Xử lý file đầu ra
SRC_APK="$APP_DIR/build/app/outputs/flutter-apk/app-release.apk"

if [ -f "$SRC_APK" ]; then
    OUT_DIR="$ROOT_DIR/build_output"
    mkdir -p "$OUT_DIR"

    # Điểm đến 1: Thư mục build_output lưu trữ theo phiên bản
    TARGET_VERSIONED_APK="$OUT_DIR/ZenHome_v${SAFE_VERSION}.apk"
    cp "$SRC_APK" "$TARGET_VERSIONED_APK"

    # Điểm đến 2: File tiện lợi ngay tại thư mục gốc workspace
    TARGET_ROOT_APK="$ROOT_DIR/ZenHome_Release.apk"
    cp "$SRC_APK" "$TARGET_ROOT_APK"

    # Điểm đến 3: Đồng bộ vào thư mục tĩnh của máy chủ Backend để phục vụ cập nhật OTA
    SERVER_DOWNLOADS="$ROOT_DIR/zenhome-server/public/downloads"
    if [ -d "$ROOT_DIR/zenhome-server" ]; then
        mkdir -p "$SERVER_DOWNLOADS"
        cp "$SRC_APK" "$SERVER_DOWNLOADS/zenhome-app-release.apk"
        SERVER_SYNCED=true
    fi

    # Tính dung lượng file
    if command -v du &> /dev/null; then
        FILE_SIZE=$(du -h "$TARGET_ROOT_APK" | cut -f1)
    elif [ -f "$TARGET_ROOT_APK" ]; then
        FILE_SIZE="$(($(wc -c < "$TARGET_ROOT_APK") / 1048576)) MB"
    else
        FILE_SIZE="N/A"
    fi

    # Tính mã SHA-256 Checksum
    CHECKSUM="N/A"
    if command -v sha256sum &> /dev/null; then
        CHECKSUM=$(sha256sum "$TARGET_ROOT_APK" | awk '{print $1}')
    elif command -v shasum &> /dev/null; then
        CHECKSUM=$(shasum -a 256 "$TARGET_ROOT_APK" | awk '{print $1}')
    fi

    echo ""
    echo -e "${GREEN}${BOLD}=================================================================${NC}"
    echo -e "${GREEN}${BOLD}             🎉 XUẤT BẢN APK THÀNH CÔNG RỰC RỠ! 🎉              ${NC}"
    echo -e "${GREEN}${BOLD}=================================================================${NC}"
    echo -e "${BOLD}⏱️  Thời gian biên dịch:${NC} ${BUILD_DURATION} giây"
    echo -e "${BOLD}📦 Kích thước file:${NC}     ${FILE_SIZE}"
    echo -e "${BOLD}🔑 SHA-256 Checksum:${NC}    ${CHECKSUM}"
    echo ""
    echo -e "${BOLD}📍 Các vị trí file đã được tạo:${NC}"
    echo -e "   1. File gốc dự án:     ${CYAN}${TARGET_ROOT_APK}${NC}"
    echo -e "   2. File lưu trữ bản:   ${CYAN}${TARGET_VERSIONED_APK}${NC}"
    
    if [ "$SERVER_SYNCED" = true ]; then
        echo -e "   3. Máy chủ OTA Update: ${GREEN}${SERVER_DOWNLOADS}/zenhome-app-release.apk${NC}"
        echo -e "      👉 Link tải OTA trực tiếp: ${YELLOW}http://localhost:5000/public/downloads/zenhome-app-release.apk${NC}"
    fi

    echo ""
    echo -e "${PURPLE}💡 Mẹo cài đặt nhanh qua cáp USB:${NC}"
    echo -e "   ${BOLD}adb install -r ZenHome_Release.apk${NC}"
    echo "================================================================="
    echo ""
    read -p "🚀 Bạn có muốn đẩy thông tin phát hành phiên bản mới này lên Cloud ngay bây giờ không? (y/N): " DO_PUSH
    if [[ "$DO_PUSH" =~ ^[Yy]$ ]]; then
        if command -v node &> /dev/null; then
            node "$ROOT_DIR/scripts/push_update.cjs"
        else
            echo "❌ Không tìm thấy node để chạy push_update.cjs"
        fi
    fi
    exit 0
else
    echo ""
    echo -e "${RED}${BOLD}=================================================================${NC}"
    echo -e "${RED}${BOLD}             ❌ XUẤT APK THẤT BẠI! VUI LÒNG KIỂM TRA LỖI        ${NC}"
    echo -e "${RED}${BOLD}=================================================================${NC}"
    echo -e "${YELLOW}Vui lòng xem thông báo lỗi chi tiết phía trên để khắc phục.${NC}"
    exit 1
fi
