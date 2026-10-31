import { Response } from 'express';

/**
 * Kiểm tra định dạng địa chỉ MAC hoặc mã định danh phần cứng ESP32
 */
export function validateMacAddress(mac: any): { valid: boolean; normalized?: string; error?: string } {
  if (!mac || typeof mac !== 'string') {
    return { valid: false, error: 'Địa chỉ MAC hoặc Hardware ID phải là chuỗi ký tự hợp lệ.' };
  }
  const clean = mac.trim();
  // Chấp nhận chuẩn IEEE 802 MAC (AA:BB:CC:DD:EE:FF hoặc AA-BB-CC-DD-EE-FF) hoặc tiền tố ESP32_
  const macRegex = /^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$/;
  const isEsp32Prefix = clean.toUpperCase().startsWith('ESP32');

  if (macRegex.test(clean) || isEsp32Prefix) {
    return { valid: true, normalized: clean };
  }
  return { 
    valid: false, 
    error: "Định dạng MAC không hợp lệ. Vui lòng nhập định dạng 'AA:BB:CC:DD:EE:FF' hoặc mã 'ESP32_...'" 
  };
}

/**
 * Kiểm tra giá trị chân GPIO / Rơ-le của ESP32
 */
export function validatePin(pin: any): { valid: boolean; pinNum?: number; error?: string } {
  if (pin === undefined || pin === null || pin === '') {
    return { valid: false, error: "Chân pin rơ-le (GPIO) là bắt buộc." };
  }
  const num = Number(pin);
  if (isNaN(num) || !Number.isInteger(num)) {
    return { valid: false, error: "Chân pin rơ-le phải là số nguyên hợp lệ." };
  }
  // Giới hạn chân GPIO hợp lệ trên vi điều khiển ESP32 (0 đến 39)
  if (num < 0 || num > 39) {
    return { valid: false, error: "Chân pin rơ-le không nằm trong dải GPIO hợp lệ của ESP32 (0 - 39)." };
  }
  return { valid: true, pinNum: num };
}

/**
 * Chuẩn hóa phản hồi API thành công (Standard Success Envelope)
 */
export function sendSuccess(
  res: Response, 
  data: any, 
  status = 200, 
  extraMeta: Record<string, any> = {}
) {
  return res.status(status).json({
    success: true,
    data,
    meta: {
      timestamp: new Date().toISOString(),
      version: 'v1',
      ...extraMeta
    }
  });
}

/**
 * Chuẩn hóa phản hồi API thất bại (Standard Error Envelope)
 */
export function sendError(
  res: Response, 
  status: number, 
  message: string, 
  code?: string
) {
  return res.status(status).json({
    success: false,
    error: message,
    code: code || `ERR_${status}`,
    timestamp: new Date().toISOString()
  });
}
