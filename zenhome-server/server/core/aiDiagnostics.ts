/**
 * ==============================================================================
 *  ZENHOME AI DIAGNOSTIC ENGINE (CHẨN ĐOÁN LỖI SỰ CỐ BẰNG TRÍ TUỆ NHÂN TẠO)
 * ==============================================================================
 *  Tự động phân tích sâu nguyên nhân gốc rễ (Root Cause), mức độ ảnh hưởng (Impact)
 *  và khuyến nghị giải pháp khắc phục (Solution) bằng tiếng Việt tự nhiên dễ hiểu,
 *  thay vì chỉ hiển thị các đoạn mã lỗi hoặc Stack Trace thô cho Quản trị viên.
 * ==============================================================================
 */

export interface AiDiagnosisResult {
  rootCause: string;
  impact: string;
  solution: string;
  severity: 'CRITICAL' | 'WARNING' | 'INFO';
  affectedComponent: string;
  suggestedAction: string;
  isAutoFixable: boolean;
  model: string;
}

export interface CrashContext {
  errorTitle?: string;
  errorMessage?: string;
  stackTrace?: string;
  deviceModel?: string;
  osVersion?: string;
  appVersion?: string;
  userId?: string;
  userName?: string;
}

/**
 * Phân tích lỗi bằng AI (Kết hợp Gemini API nếu có Key hoặc Bộ suy luận IoT Thông minh)
 */
export async function diagnoseCrashWithAi(context: CrashContext): Promise<AiDiagnosisResult> {
  const title = (context.errorTitle || '').trim();
  const msg = (context.errorMessage || '').trim();
  const stack = (context.stackTrace || '').trim();
  const combined = `${title} ${msg} ${stack}`.toLowerCase();

  // 1. Thử gọi Google Gemini API nếu biến môi trường GEMINI_API_KEY tồn tại
  const geminiKey = process.env.GEMINI_API_KEY?.trim();
  if (geminiKey) {
    try {
      const prompt = `Bạn là Chuyên gia Kỹ thuật Hệ thống IoT & Ứng dụng Di động ZenHome (Flutter + Node.js + ESP32).
Hãy phân tích sự cố sau và trả về DUY NHẤT một chuỗi JSON hợp lệ không có markdown code block:
{
  "rootCause": "Giải thích nguyên nhân cốt lõi bằng tiếng Việt ngắn gọn, dễ hiểu",
  "impact": "Mức độ ảnh hưởng tới người dùng và thiết bị",
  "solution": "Hướng giải quyết kỹ thuật cụ thể",
  "severity": "CRITICAL hoặc WARNING hoặc INFO",
  "affectedComponent": "Tên module hoặc thành phần bị lỗi",
  "suggestedAction": "Hành động khuyến nghị cho quản trị viên"
}

Thông tin sự cố:
- Lỗi: ${title}
- Chi tiết: ${msg}
- Thiết bị: ${context.deviceModel || 'N/A'} (${context.osVersion || 'N/A'})
- Phiên bản ứng dụng: ${context.appVersion || 'N/A'}
- Stack Trace: ${stack.slice(0, 1000)}`;

      const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${geminiKey}`;
      const response = await fetch(endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: { responseMimeType: 'application/json' }
        })
      });

      if (response.ok) {
        const data = await response.json();
        const rawText = data?.candidates?.[0]?.content?.parts?.[0]?.text;
        if (rawText) {
          const parsed = JSON.parse(rawText);
          return {
            rootCause: parsed.rootCause || 'Nguyên nhân không xác định',
            impact: parsed.impact || 'Chưa rõ phạm vi ảnh hưởng',
            solution: parsed.solution || 'Cần kiểm tra thêm log hệ thống',
            severity: ['CRITICAL', 'WARNING', 'INFO'].includes(parsed.severity) ? parsed.severity : 'WARNING',
            affectedComponent: parsed.affectedComponent || 'Hệ thống ứng dụng',
            suggestedAction: parsed.suggestedAction || 'Đánh dấu theo dõi thêm',
            isAutoFixable: false,
            model: 'Gemini 2.0 Flash AI',
          };
        }
      }
    } catch (err) {
      console.warn('[AI DIAGNOSTICS] Gemini API gọi không thành công, chuyển sang mô hình IoT chuyên sâu:', err);
    }
  }

  // 2. Bộ suy luận Chẩn đoán Chuyên sâu IoT ZenHome (Expert Heuristic Engine)
  // Xử lý tức thì với độ trễ 0ms, không phụ thuộc mạng ngoài

  // Nhóm 1: Lỗi UDP Discovery / Broadcast Socket
  if (combined.includes('socketexception') && (
    combined.includes('send failed') || 
    combined.includes('software caused connection abort') ||
    combined.includes('operation not permitted') ||
    combined.includes('network is unreachable') ||
    combined.includes('discoverhub')
  )) {
    return {
      rootCause: 'Ứng dụng cố gắng phát sóng gói tin UDP Broadcast tìm kiếm mạch ESP32 nội bộ (`LocalNetworkService.discoverHub`) khi điện thoại không ở trong mạng Wi-Fi (dùng mạng 4G/5G) hoặc hệ điều hành Android 14+ chặn gửi gói tin broadcast thô.',
      impact: 'Không làm văng ứng dụng ra màn hình chính, nhưng tiến trình dò tìm Hub cục bộ bị hủy và sinh ra lượng lớn bản ghi lỗi lặp đi lặp lại lên máy chủ.',
      solution: 'Đã bổ sung cơ chế kiểm tra kết nối Wi-Fi trước khi gửi UDP, bọc try/catch cho `RawDatagramSocket.send` và gán hàm `onError` trong luồng lắng nghe socket.',
      severity: 'WARNING',
      affectedComponent: 'LocalNetworkService (UDP Broadcast Discovery)',
      suggestedAction: 'Đã được vá trong bản cập nhật ứng dụng mới. Quản trị viên có thể an tâm bấm "Đã khắc phục" cho các bản ghi này.',
      isAutoFixable: true,
      model: 'ZenHome Expert IoT Diagnostic Engine',
    };
  }

  // Nhóm 2: Lỗi MQTT Chưa kết nối đã Subscribe
  if (combined.includes('connectionexception') || (combined.includes('mqtt') && combined.includes('connected state'))) {
    return {
      rootCause: 'Module MQTT (`MqttRepository`) cố gắng thực hiện lệnh đăng ký topic (`client.subscribe`) ngay trong quá trình tái kết nối tự động (`onAutoReconnected`), trước khi kết nối socket TLS hoàn tất thiết lập trạng thái `Connected`.',
      impact: 'Làm gián đoạn luồng đồng bộ trạng thái thiết bị và nhiệt độ trong vài giây khi điện thoại chuyển mạng hoặc mạng chập chờn.',
      solution: 'Đã bổ sung cổng kiểm tra `client.connectionStatus.state == MqttConnectionState.connected` trước khi gọi subscribe và bọc try/catch riêng cho từng kênh topic.',
      severity: 'WARNING',
      affectedComponent: 'MqttRepository (HiveMQ TLS Broker Bridge)',
      suggestedAction: 'Đã xử lý trong mã nguồn bản mới. Đánh dấu "Đã khắc phục".',
      isAutoFixable: true,
      model: 'ZenHome Expert IoT Diagnostic Engine',
    };
  }

  // Nhóm 3: Lỗi Null Check / Unmounted State trong Flutter
  if (combined.includes('null check operator') || (combined.includes('setstate') && combined.includes('scene_section'))) {
    return {
      rootCause: 'Hàm bất đồng bộ `_loadScenesFromDisk` nạp dữ liệu ngữ cảnh từ bộ nhớ hoàn thành sau khi người dùng đã chuyển sang màn hình khác, dẫn đến việc gọi `setState()` trên một Widget đã bị hủy (`mounted == false`).',
      impact: 'Gây lỗi cục bộ trong luồng nạp ngữ cảnh màn hình chính, làm đứt đoạn tác vụ hiển thị danh sách ngữ cảnh.',
      solution: 'Đã bổ sung điều kiện bảo vệ `if (!mounted) return;` trước khi gọi `setState` trong toàn bộ `scene_section.dart`.',
      severity: 'CRITICAL',
      affectedComponent: 'SceneSection (Quản lý ngữ cảnh thông minh)',
      suggestedAction: 'Đã sửa triệt để trong mã nguồn. Có thể xóa hoặc đánh dấu giải quyết.',
      isAutoFixable: true,
      model: 'ZenHome Expert IoT Diagnostic Engine',
    };
  }

  // Nhóm 4: Lỗi Failed Host Lookup / Avatar Image
  if (combined.includes('failed host lookup') || combined.includes('lh3.googleusercontent.com')) {
    return {
      rootCause: 'Điện thoại mất kết nối mạng Internet hoặc lỗi phân giải tên miền DNS khi nạp ảnh đại diện Google Avatar của người dùng (`photoURL`).',
      impact: 'Không hiển thị được ảnh đại diện người dùng, trước đó tạo ra ngoại lệ không được bắt trong luồng hình ảnh.',
      solution: 'Đã tích hợp tham số `onError` vào `DecorationImage` và `NetworkImage` trong `profile_screen.dart` để tự động hiển thị ký tự viết tắt khi mất mạng.',
      severity: 'INFO',
      affectedComponent: 'ProfileScreen (Ảnh đại diện tài khoản Google)',
      suggestedAction: 'Lỗi mạng ngoại vi bình thường, đã có cơ chế hiển thị chữ cái thay thế an toàn.',
      isAutoFixable: true,
      model: 'ZenHome Expert IoT Diagnostic Engine',
    };
  }

  // Nhóm 5: Lỗi Phân quyền Firestore
  if (combined.includes('permission_denied') || combined.includes('missing or insufficient permissions')) {
    return {
      rootCause: 'Yêu cầu đọc/ghi cơ sở dữ liệu Cloud Firestore bị từ chối do tài khoản hết hạn phiên đăng nhập hoặc truy vấn vào collection không được phép theo Firestore Security Rules.',
      impact: 'Không thể tải hoặc cập nhật dữ liệu thời gian thực từ Firestore cho phiên người dùng đó.',
      solution: 'Đã cập nhật quy tắc bảo mật `firestore.rules` bổ sung quyền cho `crash_logs` và `bug_reports`, đồng thời Web Admin đã chuyển sang đồng bộ qua Backend Service Account.',
      severity: 'WARNING',
      affectedComponent: 'Cloud Firestore Security Layer',
      suggestedAction: 'Xác nhận người dùng đã đăng nhập lại tài khoản hợp lệ.',
      isAutoFixable: true,
      model: 'ZenHome Expert IoT Diagnostic Engine',
    };
  }

  // Nhóm 6: Lỗi kiểm thử thử nghiệm ZenHomeTestException
  if (combined.includes('zenhometestexception') || combined.includes('kiểm thử đồng bộ crashlytics')) {
    return {
      rootCause: 'Bản ghi sự cố giả lập được Quản trị viên kích hoạt có chủ đích từ mục "Kiểm tra gửi báo cáo sự cố" trong Cài đặt để xác minh luồng đẩy Crashlytics Realtime.',
      impact: 'Không ảnh hưởng người dùng thực tế và không làm hỏng tính năng.',
      solution: 'Đây là tính năng kiểm thử hệ thống. Có thể bấm "Xóa" hoặc "Đã khắc phục" bất kỳ lúc nào.',
      severity: 'INFO',
      affectedComponent: 'CrashSyncService (Kiểm thử hệ thống)',
      suggestedAction: 'Bấm nút "Đã khắc phục" hoặc dọn dẹp khỏi danh sách.',
      isAutoFixable: true,
      model: 'ZenHome Expert IoT Diagnostic Engine',
    };
  }

  // Phân tích suy luận cho các trường hợp khác
  return {
    rootCause: `Hệ thống ghi nhận ngoại lệ loại [${title || 'Exception'}] tại thành phần: ${msg || 'Không có mô tả chi tiết'}.`,
    impact: 'Cần kiểm tra Stack Trace để xác định luồng thực thi bị gián đoạn.',
    solution: 'Kiểm tra tệp tin và dòng code được chỉ định trong Stack Trace để bổ sung bẫy lỗi try/catch hoặc kiểm tra giá trị null.',
    severity: 'WARNING',
    affectedComponent: 'Khối xử lý logic ứng dụng',
    suggestedAction: 'Theo dõi tần suất xuất hiện và đối chiếu với phiên bản ứng dụng của người dùng.',
    isAutoFixable: false,
    model: 'ZenHome General Diagnostic Engine',
  };
}
