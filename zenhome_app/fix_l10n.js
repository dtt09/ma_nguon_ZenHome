const fs = require('fs');
const path = require('path');

const projectPath = __dirname;
const enPath = path.join(projectPath, 'lib/l10n/app_en.arb');
const viPath = path.join(projectPath, 'lib/l10n/app_vi.arb');

let enData = JSON.parse(fs.readFileSync(enPath, 'utf8'));
let viData = JSON.parse(fs.readFileSync(viPath, 'utf8'));

// Keys to add
const newKeys = {
  'msg_confirm_leave_home': {
    en: 'Are you sure you want to leave this home? You will lose all control.',
    vi: 'Bạn có chắc chắn muốn rời khỏi nhà này không? Bạn sẽ mất toàn quyền điều khiển.'
  },
  'btn_leave_home': {
    en: 'Leave this home',
    vi: 'Rời khỏi nhà này'
  },
  'leave_home_title': {
    en: 'ACCESS MANAGEMENT',
    vi: 'QUẢN LÝ QUYỀN TRUY CẬP'
  },
  'msg_leave_home_success': {
    en: 'Successfully left the virtual home.',
    vi: 'Đã rời khỏi nhà ảo thành công.'
  },
  'google_register_hint': {
    en: 'Google authenticated. Please set up a Password to secure your account.',
    vi: 'Đã xác thực Google. Vui lòng thiết lập thêm Mật khẩu để bảo vệ tài khoản.'
  }
};

for (const [key, values] of Object.entries(newKeys)) {
  enData[key] = values.en;
  viData[key] = values.vi;
}

fs.writeFileSync(enPath, JSON.stringify(enData, null, 2));
fs.writeFileSync(viPath, JSON.stringify(viData, null, 2));

console.log('Updated .arb files.');

const allKeys = Object.keys(enData).filter(k => !k.startsWith('@'));

let extensionCode = `import 'package:flutter/material.dart';
import 'package:zenhome_app/l10n/app_localizations.dart';

extension LocalizationContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
  
  String tr(String key) {
    final l = AppLocalizations.of(this);
    if (l == null) return key;
    
    switch (key) {
`;

for (const key of allKeys) {
  extensionCode += `      case '${key}': return l.${key};\n`;
}

extensionCode += `      default: return key;
    }
  }
}
`;

const extPath = path.join(projectPath, 'lib/utils/localization_extension.dart');
fs.writeFileSync(extPath, extensionCode);
console.log('Updated localization_extension.dart');
