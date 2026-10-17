export function renderSwaggerHtml(): string {
  return `<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="UTF-8">
  <title>ZenHome API Documentation & Interactive Explorer</title>
  <link rel="stylesheet" type="text/css" href="https://cdnjs.cloudflare.com/ajax/libs/swagger-ui/5.11.0/swagger-ui.min.css" />
  <link rel="icon" type="image/png" href="/public/zenhome_logo.png" />
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    :root {
      --bg-primary: #0b0f19;
      --bg-card: #131b2e;
      --border-color: #243049;
      --text-primary: #f8fafc;
      --text-secondary: #94a3b8;
    }
    body {
      margin: 0;
      padding: 0;
      background: var(--bg-primary);
      color: var(--text-primary);
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
      -webkit-font-smoothing: antialiased;
    }

    /* Tự động ẩn banner và tối ưu giao diện khi nhúng trong iframe */
    body.is-embedded .custom-header {
      display: none !important;
    }
    body.is-embedded {
      background: transparent !important;
    }
    body.is-embedded .swagger-ui {
      padding: 12px 16px !important;
    }

    /* Header độc lập khi mở trực tiếp tab riêng */
    .custom-header {
      background: linear-gradient(135deg, #131b2e 0%, #0b0f19 100%);
      padding: 16px 28px;
      border-bottom: 1px solid var(--border-color);
      display: flex;
      align-items: center;
      justify-content: space-between;
      flex-wrap: wrap;
      gap: 16px;
    }
    .header-left {
      display: flex;
      align-items: center;
      gap: 14px;
    }
    .header-logo {
      width: 42px;
      height: 42px;
      border-radius: 12px;
      background: linear-gradient(135deg, #3b82f6 0%, #1d4ed8 100%);
      display: flex;
      align-items: center;
      justify-content: center;
      font-weight: 800;
      font-size: 18px;
      color: white;
      box-shadow: 0 4px 14px rgba(59, 130, 246, 0.35);
    }
    .header-title h1 {
      margin: 0;
      font-size: 18px;
      font-weight: 700;
      color: #f8fafc;
      letter-spacing: -0.3px;
    }
    .header-title p {
      margin: 3px 0 0;
      font-size: 12.5px;
      color: #94a3b8;
    }
    .header-badges {
      display: flex;
      gap: 8px;
      align-items: center;
      flex-wrap: wrap;
    }
    .badge {
      font-size: 11px;
      font-weight: 600;
      padding: 4px 10px;
      border-radius: 20px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    .badge-blue { background: rgba(59, 130, 246, 0.15); color: #60a5fa; border: 1px solid rgba(59, 130, 246, 0.3); }
    .badge-green { background: rgba(16, 185, 129, 0.15); color: #34d399; border: 1px solid rgba(16, 185, 129, 0.3); }
    .badge-purple { background: rgba(139, 92, 246, 0.15); color: #a78bfa; border: 1px solid rgba(139, 92, 246, 0.3); }
    .btn-web {
      background: #2563eb;
      color: white;
      text-decoration: none;
      padding: 7px 16px;
      border-radius: 8px;
      font-size: 12.5px;
      font-weight: 600;
      transition: all 0.2s;
      border: none;
      display: inline-flex;
      align-items: center;
      gap: 6px;
    }
    .btn-web:hover {
      background: #1d4ed8;
      box-shadow: 0 4px 12px rgba(37, 99, 235, 0.3);
    }

    /* ========================================================
       TÙY BIẾN TOÀN BỘ GIAO DIỆN SWAGGER UI SANG DARK THEME CHUẨN
       ======================================================== */
    .swagger-ui {
      max-width: 1360px;
      margin: 0 auto;
      padding: 24px 20px;
      color: var(--text-primary) !important;
    }

    /* Thông tin chung hệ thống */
    .swagger-ui .info {
      margin: 16px 0 24px 0;
      padding: 20px;
      background: var(--bg-card);
      border: 1px solid var(--border-color);
      border-radius: 14px;
    }
    .swagger-ui .info .title {
      color: #f8fafc !important;
      font-size: 22px !important;
      font-weight: 700 !important;
    }
    .swagger-ui .info .title small {
      background: #3b82f6 !important;
      border-radius: 6px !important;
      font-size: 12px !important;
      padding: 3px 8px !important;
      vertical-align: middle;
    }
    .swagger-ui .info p, .swagger-ui .info li {
      color: #cbd5e1 !important;
      font-size: 13.5px !important;
      line-height: 1.6 !important;
    }
    .swagger-ui .info a {
      color: #60a5fa !important;
    }

    /* Thanh chọn Server */
    .swagger-ui .scheme-container {
      background: var(--bg-card) !important;
      box-shadow: none !important;
      border-radius: 12px !important;
      padding: 14px 20px !important;
      border: 1px solid var(--border-color) !important;
      margin-bottom: 20px !important;
    }
    .swagger-ui .schemes > label {
      color: #94a3b8 !important;
      font-size: 13px !important;
      font-weight: 600 !important;
    }
    .swagger-ui select {
      background: #0b0f19 !important;
      color: #f8fafc !important;
      border: 1px solid var(--border-color) !important;
      border-radius: 8px !important;
      padding: 6px 12px !important;
      font-size: 13px !important;
    }
    .swagger-ui select option {
      background: #0f172a !important;
      color: #f8fafc !important;
    }

    /* TIÊU ĐỀ SECTION / TAG (KHẮC PHỤC TRIỆT ĐỂ CHỮ BỊ TỐI MỜ) */
    .swagger-ui .opblock-tag {
      color: #f8fafc !important;
      font-size: 17px !important;
      font-weight: 700 !important;
      border-bottom: 1px solid var(--border-color) !important;
      margin: 28px 0 14px 0 !important;
      padding-bottom: 8px !important;
      letter-spacing: -0.3px;
    }
    .swagger-ui .opblock-tag:hover {
      color: #60a5fa !important;
    }
    .swagger-ui .opblock-tag small {
      color: #94a3b8 !important;
      font-size: 13px !important;
      font-weight: 400 !important;
      padding-left: 10px !important;
    }
    .swagger-ui .opblock-tag svg {
      fill: #94a3b8 !important;
    }

    /* Thẻ Endpoint (Opblock) */
    .swagger-ui .opblock {
      border-radius: 12px !important;
      margin-bottom: 12px !important;
      border: 1px solid var(--border-color) !important;
      background: var(--bg-card) !important;
      box-shadow: 0 2px 4px rgba(0, 0, 0, 0.15) !important;
      transition: all 0.2s ease !important;
    }
    .swagger-ui .opblock:hover {
      border-color: #3b82f6 !important;
    }
    .swagger-ui .opblock .opblock-summary {
      padding: 10px 16px !important;
    }
    .swagger-ui .opblock .opblock-summary-method {
      border-radius: 8px !important;
      font-weight: 800 !important;
      font-size: 12px !important;
      min-width: 70px !important;
      text-align: center !important;
      padding: 6px 10px !important;
      box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2) !important;
    }
    .swagger-ui .opblock .opblock-summary-path {
      color: #f1f5f9 !important;
      font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace !important;
      font-weight: 600 !important;
      font-size: 13.5px !important;
    }
    .swagger-ui .opblock .opblock-summary-description {
      color: #94a3b8 !important;
      font-size: 13px !important;
    }
    .swagger-ui .opblock .opblock-summary svg {
      fill: #94a3b8 !important;
    }

    /* Màu theo từng phương thức */
    .swagger-ui .opblock.opblock-get {
      background: rgba(59, 130, 246, 0.05) !important;
      border-color: rgba(59, 130, 246, 0.3) !important;
    }
    .swagger-ui .opblock.opblock-get .opblock-summary-method {
      background: #2563eb !important;
      color: #ffffff !important;
    }

    .swagger-ui .opblock.opblock-post {
      background: rgba(16, 185, 129, 0.05) !important;
      border-color: rgba(16, 185, 129, 0.3) !important;
    }
    .swagger-ui .opblock.opblock-post .opblock-summary-method {
      background: #059669 !important;
      color: #ffffff !important;
    }

    .swagger-ui .opblock.opblock-put {
      background: rgba(245, 158, 11, 0.05) !important;
      border-color: rgba(245, 158, 11, 0.3) !important;
    }
    .swagger-ui .opblock.opblock-put .opblock-summary-method {
      background: #d97706 !important;
      color: #ffffff !important;
    }

    .swagger-ui .opblock.opblock-delete {
      background: rgba(239, 68, 68, 0.05) !important;
      border-color: rgba(239, 68, 68, 0.3) !important;
    }
    .swagger-ui .opblock.opblock-delete .opblock-summary-method {
      background: #dc2626 !important;
      color: #ffffff !important;
    }

    /* Thân chi tiết endpoint khi click mở rộng */
    .swagger-ui .opblock-body {
      background: #0c1220 !important;
      border-top: 1px solid var(--border-color) !important;
      padding: 16px 20px !important;
    }
    .swagger-ui .opblock-description-wrapper,
    .swagger-ui .opblock-description-wrapper p,
    .swagger-ui .opblock-external-docs-wrapper p {
      color: #cbd5e1 !important;
      font-size: 13.5px !important;
    }

    /* Bảng tham số & Models */
    .swagger-ui .opblock-section-header {
      background: #131b2e !important;
      border: 1px solid var(--border-color) !important;
      border-radius: 8px !important;
      padding: 8px 14px !important;
    }
    .swagger-ui .opblock-section-header h4 {
      color: #f8fafc !important;
      font-size: 13px !important;
    }
    .swagger-ui table {
      color: #cbd5e1 !important;
    }
    .swagger-ui table thead tr td,
    .swagger-ui table thead tr th {
      color: #94a3b8 !important;
      border-bottom: 1px solid var(--border-color) !important;
      font-size: 12px !important;
      font-weight: 600 !important;
      text-transform: uppercase !important;
      letter-spacing: 0.5px !important;
    }
    .swagger-ui table tbody tr td {
      border-color: var(--border-color) !important;
      color: #cbd5e1 !important;
      font-size: 13px !important;
    }
    .swagger-ui .parameter__name {
      color: #38bdf8 !important;
      font-family: ui-monospace, monospace !important;
      font-weight: 700 !important;
    }
    .swagger-ui .parameter__type {
      color: #a78bfa !important;
      font-family: ui-monospace, monospace !important;
    }
    .swagger-ui .parameter__in {
      color: #94a3b8 !important;
      font-style: italic !important;
    }
    .swagger-ui .parameter__deprecated {
      color: #f87171 !important;
    }

    /* Trường nhập text và textareas */
    .swagger-ui input[type=text],
    .swagger-ui textarea {
      background: #050811 !important;
      color: #f8fafc !important;
      border: 1px solid #334155 !important;
      border-radius: 8px !important;
      padding: 8px 12px !important;
      font-family: ui-monospace, monospace !important;
      font-size: 12.5px !important;
    }
    .swagger-ui input[type=text]:focus,
    .swagger-ui textarea:focus {
      border-color: #3b82f6 !important;
      outline: none !important;
    }

    /* Các nút bấm Swagger */
    .swagger-ui .btn {
      border-radius: 8px !important;
      color: #f8fafc !important;
      border-color: #334155 !important;
      background: #1e293b !important;
      font-weight: 600 !important;
      font-size: 12px !important;
      transition: all 0.2s !important;
    }
    .swagger-ui .btn:hover {
      background: #334155 !important;
    }
    .swagger-ui .btn.execute {
      background-color: #2563eb !important;
      border-color: #2563eb !important;
      color: #fff !important;
    }
    .swagger-ui .btn.execute:hover {
      background-color: #1d4ed8 !important;
    }
    .swagger-ui .btn.cancel {
      background-color: #dc2626 !important;
      border-color: #dc2626 !important;
      color: #fff !important;
    }

    /* Phản hồi (Responses) */
    .swagger-ui .responses-inner h4,
    .swagger-ui .responses-inner h5 {
      color: #f8fafc !important;
    }
    .swagger-ui .response-col_status {
      color: #34d399 !important;
      font-family: ui-monospace, monospace !important;
      font-weight: 700 !important;
    }
    .swagger-ui .response-col_description {
      color: #cbd5e1 !important;
    }
    .swagger-ui .response-col_description__inner div.markdown p {
      color: #94a3b8 !important;
    }
    .swagger-ui .highlight-code pre {
      background: #050811 !important;
      color: #38bdf8 !important;
      border: 1px solid var(--border-color) !important;
      border-radius: 10px !important;
      padding: 12px 16px !important;
    }
    .swagger-ui .microlight {
      background: #050811 !important;
      color: #e2e8f0 !important;
    }

    /* Phần Models ở cuối trang */
    .swagger-ui section.models {
      background: var(--bg-card) !important;
      border: 1px solid var(--border-color) !important;
      border-radius: 14px !important;
      margin-top: 36px !important;
    }
    .swagger-ui section.models h4 {
      color: #f8fafc !important;
      font-size: 15px !important;
    }
    .swagger-ui section.models h4 svg {
      fill: #94a3b8 !important;
    }
    .swagger-ui .model-container {
      background: #0b0f19 !important;
      border-radius: 10px !important;
      margin: 8px 0 !important;
      padding: 12px !important;
    }
    .swagger-ui .model-title {
      color: #f8fafc !important;
    }
    .swagger-ui .model {
      color: #cbd5e1 !important;
    }
    .swagger-ui .prop-type {
      color: #38bdf8 !important;
    }
    .swagger-ui .prop-format {
      color: #94a3b8 !important;
    }
  </style>
</head>
<body>
  <div class="custom-header">
    <div class="header-left">
      <div class="header-logo">ZH</div>
      <div class="header-title">
        <h1>ZenHome RESTful API System</h1>
        <p>Hệ thống API tương tác thời gian thực cho Nhà thông minh & Máy chủ Backup</p>
      </div>
    </div>
    <div class="header-badges">
      <span class="badge badge-blue">REST API v1</span>
      <span class="badge badge-green">MQTT TLS 8883</span>
      <span class="badge badge-purple">ESP32 RTOS</span>
      <a href="/" class="btn-web">Mở Web Dashboard ↗</a>
    </div>
  </div>

  <div id="swagger-ui"></div>

  <script src="https://cdnjs.cloudflare.com/ajax/libs/swagger-ui/5.11.0/swagger-ui-bundle.min.js"></script>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/swagger-ui/5.11.0/swagger-ui-standalone-preset.min.js"></script>
  <script>
    window.onload = function() {
      // Tự động kiểm tra nếu đang được nhúng trong iframe của Web Dashboard
      const urlParams = new URLSearchParams(window.location.search);
      const isEmbedded = urlParams.get('embedded') === 'true' || (window.self !== window.top);
      if (isEmbedded) {
        document.body.classList.add('is-embedded');
      }

      const ui = SwaggerUIBundle({
        url: "/api/v1/openapi.json",
        dom_id: '#swagger-ui',
        deepLinking: true,
        presets: [
          SwaggerUIBundle.presets.apis,
          SwaggerUIStandalonePreset
        ],
        plugins: [
          SwaggerUIBundle.plugins.DownloadUrl
        ],
        layout: "BaseLayout",
        defaultModelsExpandDepth: -1,
        docExpansion: "list"
      });
      window.ui = ui;
    };
  </script>
</body>
</html>`;
}
