export const openApiSpec = {
  openapi: "3.0.0",
  info: {
    title: "ZenHome Smart IoT & Automation Ecosystem API",
    version: "2.5.0-stem",
    description: "Hệ thống RESTful API toàn diện kết nối trực tiếp với cơ sở dữ liệu Google Cloud Firestore và Broker MQTT HiveMQ Cloud TLS (Port 8883). Xử lý thông tin chính xác 100%, không sử dụng dữ liệu ảo, hỗ trợ quản lý người dùng, thiết bị phần cứng, ngữ cảnh tự động, lịch trình tập trung chống trôi giờ và giám sát an toàn cháy nổ.",
    contact: {
      name: "Đinh Tử Thuật - THPT Trần Hưng Đạo",
      email: "dinhtuthuat2103@gmail.com",
      url: "https://zenhome.io"
    },
    license: {
      name: "MIT",
      url: "https://opensource.org/licenses/MIT"
    }
  },
  servers: [
    {
      url: "/",
      description: "ZenHome Unified Server (Port 5000)"
    }
  ],
  tags: [
    { name: "Người Dùng (Users)", description: "Quản lý tài khoản, hồ sơ chủ nhà và phiên đăng nhập di động thực tế từ Firestore" },
    { name: "Thiết Bị (Devices)", description: "CRUD thiết bị thực tế trong Firestore và điều khiển phần cứng qua MQTT Retry Engine" },
    { name: "Ngữ Cảnh (Scenes)", description: "Khai báo và kích hoạt các kịch bản tự động hóa thông minh lưu trực tiếp trong Firestore" },
    { name: "Lịch Trình (Schedules)", description: "Quản lý lịch trình tự động bật/tắt (Centralized Cron) đồng bộ Firestore và RAM" },
    { name: "Hẹn Giờ (Timers)", description: "Hẹn giờ đếm ngược tự động tắt/bật thiết bị sau số phút xác định" },
    { name: "An Toàn & Lịch Sử (Alerts & History)", description: "Cảnh báo cháy nổ (nhiệt độ >= 50°C), cảnh báo mất điện và nhật ký đóng cắt tải từ Firestore" },
    { name: "Hub ESP32 (Hardware Fleet)", description: "Liên kết phần cứng, giám sát kết nối thực tế, nạp bản đồ chân LittleFS và Factory Reset" },
    { name: "Máy Chủ Backup (Backup Server)", description: "Quản lý sao lưu dữ liệu Firestore và xử lý xóa tài khoản GDPR" },
    { name: "Hệ Thống (System)", description: "Kiểm tra nhịp tim (Health check), trạng thái bộ đệm RAM và nhật ký sự kiện thời gian thực" }
  ],
  paths: {
    "/api/v1/users": {
      get: {
        tags: ["Người Dùng (Users)"],
        summary: "Lấy danh sách tất cả tài khoản thực tế từ Firestore",
        responses: {
          "200": { description: "Thành công" }
        }
      }
    },
    "/api/v1/users/{userId}": {
      get: {
        tags: ["Người Dùng (Users)"],
        summary: "Lấy chi tiết hồ sơ người dùng và các phiên đăng nhập di động (sessions)",
        parameters: [
          { name: "userId", in: "path", required: true, schema: { type: "string" }, description: "Mã người dùng (vd: dtthuat)" }
        ],
        responses: {
          "200": { description: "Thành công" },
          "404": { description: "Không tìm thấy người dùng" }
        }
      },
      put: {
        tags: ["Người Dùng (Users)"],
        summary: "Cập nhật thông tin hồ sơ người dùng trong Firestore",
        parameters: [
          { name: "userId", in: "path", required: true, schema: { type: "string" } }
        ],
        requestBody: {
          content: {
            "application/json": {
              schema: {
                type: "object",
                properties: {
                  displayName: { type: "string" },
                  phoneNumber: { type: "string" },
                  macAddress: { type: "string" },
                  birthday: { type: "string" }
                }
              }
            }
          }
        },
        responses: {
          "200": { description: "Cập nhật thành công" }
        }
      }
    },
    "/api/v1/devices": {
      get: {
        tags: ["Thiết Bị (Devices)"],
        summary: "Lấy danh sách thiết bị THỰC TẾ từ Firestore",
        description: "Truy vấn danh sách thiết bị thực tế của chủ nhà từ Firestore database (không tạo dữ liệu ảo).",
        parameters: [
          { name: "userId", in: "query", schema: { type: "string" }, description: "Mã người dùng (tùy chọn, mặc định lấy người dùng đầu tiên)" }
        ],
        responses: {
          "200": { description: "Thành công" }
        }
      },
      post: {
        tags: ["Thiết Bị (Devices)"],
        summary: "Thêm thiết bị mới vào cơ sở dữ liệu Firestore",
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["name", "room", "pin"],
                properties: {
                  userId: { type: "string", description: "ID người dùng (tùy chọn)" },
                  id: { type: "string", example: "den_phong_khach", description: "Mã định danh duy nhất của thiết bị" },
                  name: { type: "string", example: "Đèn Trần Phòng Khách", description: "Tên hiển thị" },
                  room: { type: "string", example: "phong_khach", description: "Khu vực / Phòng" },
                  pin: { type: "integer", example: 0, description: "Chân relay (0-7)" },
                  icon: { type: "string", example: "light", description: "Biểu tượng giao diện" }
                }
              }
            }
          }
        },
        responses: {
          "201": { description: "Đã thêm thiết bị thành công" },
          "400": { description: "Chân pin bị trùng hoặc thiếu dữ liệu" },
          "409": { description: "Mã ID thiết bị đã tồn tại" }
        }
      }
    },
    "/api/v1/devices/{id}": {
      get: {
        tags: ["Thiết Bị (Devices)"],
        summary: "Lấy chi tiết một thiết bị thực tế",
        parameters: [
          { name: "id", in: "path", required: true, schema: { type: "string" }, description: "Mã thiết bị" },
          { name: "userId", in: "query", schema: { type: "string" } }
        ],
        responses: {
          "200": { description: "Thành công" },
          "404": { description: "Không tìm thấy thiết bị" }
        }
      },
      put: {
        tags: ["Thiết Bị (Devices)"],
        summary: "Cập nhật thiết bị trong Firestore",
        parameters: [
          { name: "id", in: "path", required: true, schema: { type: "string" } }
        ],
        requestBody: {
          content: {
            "application/json": {
              schema: {
                type: "object",
                properties: {
                  userId: { type: "string" },
                  name: { type: "string" },
                  room: { type: "string" },
                  pin: { type: "integer" },
                  icon: { type: "string" }
                }
              }
            }
          }
        },
        responses: {
          "200": { description: "Cập nhật thành công" }
        }
      },
      delete: {
        tags: ["Thiết Bị (Devices)"],
        summary: "Xóa thiết bị khỏi cơ sở dữ liệu Firestore",
        parameters: [
          { name: "id", in: "path", required: true, schema: { type: "string" } },
          { name: "userId", in: "query", schema: { type: "string" } }
        ],
        responses: {
          "200": { description: "Đã xóa thiết bị" }
        }
      }
    },
    "/api/v1/devices/{id}/control": {
      post: {
        tags: ["Thiết Bị (Devices)"],
        summary: "Điều khiển Bật/Tắt thiết bị thực tế (MQTT Retry Engine)",
        description: "Kiểm tra sự tồn tại của thiết bị trong Firestore trước khi gửi tín hiệu qua MQTT TLS.",
        parameters: [
          { name: "id", in: "path", required: true, schema: { type: "string" }, description: "Mã thiết bị" }
        ],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["state"],
                properties: {
                  state: { type: "string", enum: ["1", "0"], description: "'1' là BẬT, '0' là TẮT" },
                  userId: { type: "string" },
                  source: { type: "string", default: "api_client" }
                }
              }
            }
          }
        },
        responses: {
          "200": { description: "Đã phát lệnh thành công" },
          "404": { description: "Thiết bị không tồn tại trong database" }
        }
      }
    },
    "/api/v1/devices/bulk": {
      post: {
        tags: ["Thiết Bị (Devices)"],
        summary: "Điều khiển hàng loạt thiết bị thực tế (Tất cả Bật/Tắt, hoặc theo phòng)",
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["action"],
                properties: {
                  action: { type: "string", enum: ["all_on", "all_off", "room_on", "room_off"] },
                  room: { type: "string", description: "Tên phòng nếu action là room_on hoặc room_off" },
                  userId: { type: "string" }
                }
              }
            }
          }
        },
        responses: {
          "200": { description: "Thành công" }
        }
      }
    },
    "/api/v1/devices/telemetry/status": {
      get: {
        tags: ["Thiết Bị (Devices)"],
        summary: "Lấy chỉ số cảm biến thời gian thực CHÍNH XÁC (không số ảo)",
        description: "Trả về nhiệt độ phòng nhận trực tiếp từ cảm biến DHT11 qua MQTT. Nếu chưa có dữ liệu sẽ trả về null và trạng thái WAITING_FOR_DATA.",
        parameters: [
          { name: "userId", in: "query", schema: { type: "string" } }
        ],
        responses: {
          "200": { description: "Thành công" }
        }
      }
    },
    "/api/v1/scenes": {
      get: {
        tags: ["Ngữ Cảnh (Scenes)"],
        summary: "Lấy danh sách các ngữ cảnh thông minh THỰC TẾ từ Firestore",
        parameters: [
          { name: "userId", in: "query", schema: { type: "string" } }
        ],
        responses: {
          "200": { description: "Thành công" }
        }
      },
      post: {
        tags: ["Ngữ Cảnh (Scenes)"],
        summary: "Tạo ngữ cảnh thông minh mới vào Firestore",
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["name", "actions"],
                properties: {
                  userId: { type: "string" },
                  id: { type: "string", example: "ve_nha" },
                  name: { type: "string", example: "Về Nhà" },
                  description: { type: "string", example: "Bật đèn phòng khách và quạt" },
                  icon: { type: "string", example: "home" },
                  color: { type: "string", example: "#10B981" },
                  actions: {
                    type: "array",
                    items: {
                      type: "object",
                      required: ["deviceId", "room", "state"],
                      properties: {
                        deviceId: { type: "string" },
                        room: { type: "string" },
                        state: { type: "string", enum: ["1", "0"] }
                      }
                    }
                  }
                }
              }
            }
          }
        },
        responses: {
          "201": { description: "Tạo kịch bản thành công" }
        }
      }
    },
    "/api/v1/scenes/{sceneId}": {
      get: {
        tags: ["Ngữ Cảnh (Scenes)"],
        summary: "Lấy chi tiết một ngữ cảnh thông minh",
        parameters: [
          { name: "sceneId", in: "path", required: true, schema: { type: "string" } },
          { name: "userId", in: "query", schema: { type: "string" } }
        ],
        responses: {
          "200": { description: "Thành công" },
          "404": { description: "Không tìm thấy" }
        }
      },
      put: {
        tags: ["Ngữ Cảnh (Scenes)"],
        summary: "Cập nhật ngữ cảnh trong Firestore",
        parameters: [
          { name: "sceneId", in: "path", required: true, schema: { type: "string" } }
        ],
        responses: {
          "200": { description: "Thành công" }
        }
      },
      delete: {
        tags: ["Ngữ Cảnh (Scenes)"],
        summary: "Xóa ngữ cảnh khỏi Firestore",
        parameters: [
          { name: "sceneId", in: "path", required: true, schema: { type: "string" } }
        ],
        responses: {
          "200": { description: "Đã xóa" }
        }
      }
    },
    "/api/v1/scenes/{sceneId}/execute": {
      post: {
        tags: ["Ngữ Cảnh (Scenes)"],
        summary: "Kích hoạt kịch bản ngữ cảnh thông minh từ Firestore",
        parameters: [
          { name: "sceneId", in: "path", required: true, schema: { type: "string" } }
        ],
        requestBody: {
          content: {
            "application/json": {
              schema: {
                type: "object",
                properties: {
                  userId: { type: "string" }
                }
              }
            }
          }
        },
        responses: {
          "200": { description: "Thành công" }
        }
      }
    },
    "/api/v1/schedules": {
      get: {
        tags: ["Lịch Trình (Schedules)"],
        summary: "Lấy danh sách lịch trình tự động từ Firestore và RAM",
        responses: {
          "200": { description: "Thành công" }
        }
      },
      post: {
        tags: ["Lịch Trình (Schedules)"],
        summary: "Tạo lịch trình tự động mới",
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["baseTopic"],
                properties: {
                  baseTopic: { type: "string", example: "dtthuat/ESP32_MAC/phong_khach/den_tran" },
                  timeOn: { type: "string", example: "18:00" },
                  timeOff: { type: "string", example: "22:30" },
                  days: { type: "string", example: "0,1,2,3,4,5,6" }
                }
              }
            }
          }
        },
        responses: {
          "200": { description: "Thành công" }
        }
      }
    },
    "/api/v1/schedules/query": {
      get: {
        tags: ["Lịch Trình (Schedules)"],
        summary: "Cơ chế Hỏi - Trả Lời: Hỏi tình trạng lịch trình tại thời điểm bất kỳ",
        parameters: [
          { name: "time", in: "query", schema: { type: "string", example: "18:00" }, description: "Giờ cần hỏi (HH:mm). Mặc định là giờ VN hiện tại." },
          { name: "day", in: "query", schema: { type: "integer", example: 0 }, description: "Thứ trong tuần (0=Thứ 2 ... 6=Chủ nhật)." },
          { name: "topic", in: "query", schema: { type: "string" }, description: "Lọc theo topic thiết bị." }
        ],
        responses: {
          "200": { description: "Trả lời câu hỏi kiểm tra lịch trình kèm lịch trình tiếp theo" }
        }
      }
    },
    "/api/v1/schedules/query-check": {
      post: {
        tags: ["Lịch Trình (Schedules)"],
        summary: "Cơ chế Hỏi - Trả Lời tương tác (Tùy chọn kích hoạt ngay nếu có lịch khớp)",
        requestBody: {
          required: false,
          content: {
            "application/json": {
              schema: {
                type: "object",
                properties: {
                  time: { type: "string", example: "18:00" },
                  day: { type: "integer", example: 0 },
                  topic: { type: "string" },
                  execute: { type: "boolean", default: false }
                }
              }
            }
          }
        },
        responses: {
          "200": { description: "Kết quả đối chiếu và thực thi tương ứng" }
        }
      }
    },
    "/api/v1/schedules/next": {
      get: {
        tags: ["Lịch Trình (Schedules)"],
        summary: "Lấy thời gian đếm ngược đến lịch trình kế tiếp trên toàn hệ thống",
        responses: {
          "200": { description: "Thông tin lịch trình gần nhất sắp tới" }
        }
      }
    },
    "/api/v1/schedules/{id}": {
      delete: {
        tags: ["Lịch Trình (Schedules)"],
        summary: "Xóa lịch trình khỏi Firestore và RAM",
        parameters: [
          { name: "id", in: "path", required: true, schema: { type: "string" } }
        ],
        responses: {
          "200": { description: "Thành công" }
        }
      }
    },
    "/api/v1/timers": {
      get: {
        tags: ["Hẹn Giờ (Timers)"],
        summary: "Lấy danh sách hẹn giờ đếm ngược",
        responses: {
          "200": { description: "Thành công" }
        }
      },
      post: {
        tags: ["Hẹn Giờ (Timers)"],
        summary: "Tạo hẹn giờ đếm ngược",
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["baseTopic", "minutes"],
                properties: {
                  baseTopic: { type: "string", example: "dtthuat/ESP32_MAC/phong_khach/quat_tran" },
                  action: { type: "string", enum: ["0", "1"], default: "0", description: "'0' là TẮT, '1' là BẬT" },
                  minutes: { type: "integer", example: 30 }
                }
              }
            }
          }
        },
        responses: {
          "200": { description: "Thành công" }
        }
      }
    },
    "/api/v1/timers/{timerKey}": {
      delete: {
        tags: ["Hẹn Giờ (Timers)"],
        summary: "Hủy hẹn giờ đếm ngược",
        parameters: [
          { name: "timerKey", in: "path", required: true, schema: { type: "string" } }
        ],
        responses: {
          "200": { description: "Thành công" }
        }
      }
    },
    "/api/v1/alerts": {
      get: {
        tags: ["An Toàn & Lịch Sử (Alerts & History)"],
        summary: "Lấy danh sách cảnh báo an toàn hỏa hoạn và mạng THỰC TẾ từ Firestore",
        parameters: [
          { name: "userId", in: "query", schema: { type: "string" } },
          { name: "limit", in: "query", schema: { type: "integer", default: 50 } }
        ],
        responses: {
          "200": { description: "Thành công" }
        }
      },
      post: {
        tags: ["An Toàn & Lịch Sử (Alerts & History)"],
        summary: "Tạo bản ghi cảnh báo an toàn mới vào Firestore",
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["title", "message"],
                properties: {
                  userId: { type: "string" },
                  type: { type: "string", example: "SECURITY_FIRE" },
                  title: { type: "string", example: "Cảnh báo nhiệt độ cao" },
                  message: { type: "string", example: "Nhiệt độ phòng vượt ngưỡng 50°C" },
                  level: { type: "string", enum: ["info", "warning", "danger"] }
                }
              }
            }
          }
        },
        responses: {
          "201": { description: "Thành công" }
        }
      }
    },
    "/api/v1/alerts/{id}": {
      delete: {
        tags: ["An Toàn & Lịch Sử (Alerts & History)"],
        summary: "Xóa bản ghi cảnh báo khỏi Firestore",
        parameters: [
          { name: "id", in: "path", required: true, schema: { type: "string" } }
        ],
        responses: {
          "200": { description: "Đã xóa" }
        }
      }
    },
    "/api/v1/alerts/history": {
      get: {
        tags: ["An Toàn & Lịch Sử (Alerts & History)"],
        summary: "Lấy nhật ký lịch sử bật/tắt thiết bị THỰC TẾ từ Firestore",
        parameters: [
          { name: "userId", in: "query", schema: { type: "string" } },
          { name: "limit", in: "query", schema: { type: "integer", default: 50 } }
        ],
        responses: {
          "200": { description: "Thành công" }
        }
      }
    },
    "/api/v1/hub/status": {
      get: {
        tags: ["Hub ESP32 (Hardware Fleet)"],
        summary: "Lấy trạng thái kết nối THỰC TẾ của Hub ESP32",
        description: "Truy vấn MAC thực tế của tài khoản và đối chiếu trạng thái MQTT online/offline trực tiếp.",
        parameters: [
          { name: "userId", in: "query", schema: { type: "string" } }
        ],
        responses: {
          "200": { description: "Thành công" }
        }
      }
    },
    "/api/v1/hub/link": {
      post: {
        tags: ["Hub ESP32 (Hardware Fleet)"],
        summary: "Liên kết địa chỉ MAC của phần cứng ESP32 vào tài khoản người dùng",
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["macAddress"],
                properties: {
                  userId: { type: "string" },
                  macAddress: { type: "string", example: "ESP32_WROOM_32_4C75" }
                }
              }
            }
          }
        },
        responses: {
          "200": { description: "Liên kết thành công" }
        }
      }
    },
    "/api/v1/hub/unlink": {
      post: {
        tags: ["Hub ESP32 (Hardware Fleet)"],
        summary: "Hủy liên kết Hub ESP32 khỏi tài khoản người dùng",
        responses: {
          "200": { description: "Hủy liên kết thành công" }
        }
      }
    },
    "/api/v1/hub/reset": {
      post: {
        tags: ["Hub ESP32 (Hardware Fleet)"],
        summary: "Gửi lệnh Factory Reset từ xa tới ESP32 qua MQTT",
        responses: {
          "200": { description: "Thành công" }
        }
      }
    },
    "/api/v1/hub/config": {
      post: {
        tags: ["Hub ESP32 (Hardware Fleet)"],
        summary: "Nạp sơ đồ chân động (Dynamic Pin Mapping) xuống LittleFS của ESP32",
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["devices"],
                properties: {
                  userId: { type: "string" },
                  devices: {
                    type: "array",
                    items: {
                      type: "object",
                      properties: {
                        id: { type: "string", example: "den_san" },
                        pin: { type: "integer", example: 6 }
                      }
                    }
                  }
                }
              }
            }
          }
        },
        responses: {
          "200": { description: "Thành công" }
        }
      }
    },
    "/api/v1/backup/status": {
      get: {
        tags: ["Máy Chủ Backup (Backup Server)"],
        summary: "Trạng thái hoạt động của Máy chủ Backup độc lập",
        responses: {
          "200": { description: "Thành công" }
        }
      }
    },
    "/api/v1/backup/trigger": {
      post: {
        tags: ["Máy Chủ Backup (Backup Server)"],
        summary: "Tạo bản Snapshot sao lưu Firestore mới",
        responses: {
          "200": { description: "Thành công" }
        }
      }
    },
    "/api/v1/backup/list": {
      get: {
        tags: ["Máy Chủ Backup (Backup Server)"],
        summary: "Danh sách các bản sao lưu đã tạo",
        responses: {
          "200": { description: "Thành công" }
        }
      }
    },
    "/api/v1/system/health": {
      get: {
        tags: ["Hệ Thống (System)"],
        summary: "Kiểm tra nhịp tim của máy chủ",
        responses: {
          "200": { description: "Thành công" }
        }
      }
    },
    "/api/v1/system/state": {
      get: {
        tags: ["Hệ Thống (System)"],
        summary: "Trạng thái bộ đệm nội bộ máy chủ",
        responses: {
          "200": { description: "Thành công" }
        }
      }
    },
    "/api/v1/system/logs": {
      get: {
        tags: ["Hệ Thống (System)"],
        summary: "Nhật ký sự kiện thời gian thực",
        responses: {
          "200": { description: "Thành công" }
        }
      }
    },
    "/api/v1/system/app-version": {
      get: {
        tags: ["Hệ Thống (System)"],
        summary: "Lấy thông tin phiên bản mới nhất của ứng dụng di động Flutter (OTA)",
        responses: {
          "200": { description: "Thành công" }
        }
      },
      post: {
        tags: ["Hệ Thống (System)"],
        summary: "Cập nhật và phát hành thông tin phiên bản ứng dụng mới từ Web Admin",
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                properties: {
                  latestVersion: { type: "string", example: "1.4.0" },
                  latestBuildNumber: { type: "integer", example: 140 },
                  minVersion: { type: "string", example: "1.3.0" },
                  minBuildNumber: { type: "integer", example: 130 },
                  titleVi: { type: "string", example: "Bản Cập Nhật ZenHome v1.4.0" },
                  releaseNotesVi: { type: "string", example: "• Đồng bộ Firestore realtime 100%\n• Đăng nhập mượt mà" },
                  downloadUrl: { type: "string", example: "https://github.com/dtthuat/zenhome/releases/latest" },
                  isForceUpdate: { type: "boolean", example: false }
                }
              }
            }
          }
        },
        responses: {
          "200": { description: "Cập nhật thành công" }
        }
      }
    }
  }
};
