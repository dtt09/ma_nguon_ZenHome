import os
import re

files_to_check = [
    'lib/utils/reauth_helper.dart',
    'lib/screens/setup/wifi_setup_screen.dart',
    'lib/screens/auth/change_password_screen.dart',
    'lib/screens/auth/logged_devices_screen.dart',
    'lib/screens/auth/update_email_phone_screen.dart',
    'lib/screens/auth/account_info_screen.dart',
    'lib/screens/auth/login_screen.dart',
    'lib/screens/auth/register_screen.dart',
    'lib/screens/admin/device_mapping_screen.dart',
    'lib/screens/settings/member_screen.dart',
]

def add_import(content, import_statement):
    if import_statement in content:
        return content
    # find last import
    matches = list(re.finditer(r'^import .*;$', content, re.MULTILINE))
    if matches:
        last_match = matches[-1]
        insert_pos = last_match.end()
        return content[:insert_pos] + '\n' + import_statement + content[insert_pos:]
    else:
        return import_statement + '\n' + content

for f in files_to_check:
    if not os.path.exists(f):
        continue
    with open(f, 'r', encoding='utf-8') as file:
        content = file.read()
        
    original = content
    
    # 1. CircularProgressIndicator(strokeWidth: 2, color: textColor) -> LogoLoadingIndicator(color: textColor, size: 24)
    # We need to capture color if present.
    # Pattern: CircularProgressIndicator(strokeWidth: \d+, color: (.*?))
    content = re.sub(r'CircularProgressIndicator\(\s*strokeWidth:\s*\d+,\s*color:\s*([^)]+)\)', r'LogoLoadingIndicator(color: \1, size: 24)', content)
    
    # Pattern: CircularProgressIndicator(color: (.*?),\s*strokeWidth:\s*\d+)
    content = re.sub(r'CircularProgressIndicator\(\s*color:\s*([^,]+),\s*strokeWidth:\s*\d+\)', r'LogoLoadingIndicator(color: \1, size: 24)', content)
    
    # Pattern: CircularProgressIndicator(color: (.*?))
    content = re.sub(r'CircularProgressIndicator\(\s*color:\s*([^)]+)\)', r'LogoLoadingIndicator(color: \1, size: 24)', content)
    
    # Pattern: CircularProgressIndicator()
    content = re.sub(r'CircularProgressIndicator\(\)', r'LogoLoadingIndicator(color: Colors.blue, size: 24)', content)

    # Some might be const CircularProgressIndicator... 
    # LogoLoadingIndicator can be const if the color is const. Wait, size is a double. We can use const LogoLoadingIndicator.
    # But to avoid const errors, let's remove 'const ' before LogoLoadingIndicator if it was there.
    content = re.sub(r'const\s+LogoLoadingIndicator', r'LogoLoadingIndicator', content)

    if content != original:
        # Check depth of file to generate correct relative import for loading_overlay.dart
        depth = f.count('/') - 1
        prefix = '../' * depth
        import_stmt = f"import '{prefix}widgets/loading_overlay.dart';"
        
        content = add_import(content, import_stmt)
        
        with open(f, 'w', encoding='utf-8') as file:
            file.write(content)
        print(f"Updated {f}")

