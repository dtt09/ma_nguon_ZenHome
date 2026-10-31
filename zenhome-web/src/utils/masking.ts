/**
 * Data Masking Utility (SEC-05: PII Protection)
 * Tự động làm mờ các trường dữ liệu nhạy cảm của khách hàng (Số điện thoại, Email, Token)
 * khi hiển thị trên màn hình Quản trị viên để tránh lộ thông tin khi livestream / trình chiếu.
 */

/**
 * Làm mờ số điện thoại:
 * Ví dụ: "0987654321" -> "098***321"
 *        "09123456"   -> "09***56"
 */
export const maskPhone = (phone: string | null | undefined): string => {
  if (!phone) return '—';
  const clean = phone.trim();
  if (clean.length <= 4) return '***';
  if (clean.length <= 7) {
    return `${clean.slice(0, 2)}***${clean.slice(-2)}`;
  }
  return `${clean.slice(0, 3)}***${clean.slice(-3)}`;
};

/**
 * Làm mờ email:
 * Ví dụ: "user.name@domain.com" -> "us***e@domain.com"
 *        "a@b.com"              -> "a***@b.com"
 */
export const maskEmail = (email: string | null | undefined): string => {
  if (!email || !email.includes('@')) return email || '—';
  const [user, domain] = email.split('@');
  if (user.length <= 2) {
    return `${user[0] || '*'}***@${domain}`;
  }
  return `${user.slice(0, 2)}***${user.slice(-1)}@${domain}`;
};

/**
 * Làm mờ Token, Secret hoặc UID dài
 * Ví dụ: "admin_secret_token_abc123" -> "admin_...abc123"
 */
export const maskToken = (token: string | null | undefined, visible = 6): string => {
  if (!token) return '—';
  if (token.length <= visible * 2) return '******';
  return `${token.slice(0, visible)}...${token.slice(-visible)}`;
};
