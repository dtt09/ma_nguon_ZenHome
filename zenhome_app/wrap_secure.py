import os
import re

files_to_secure = [
    'lib/features/auth/ui/login_screen.dart',
    'lib/features/auth/ui/register_screen.dart',
    'lib/features/auth/ui/profile_screen.dart',
    'lib/features/auth/ui/change_password_screen.dart',
    'lib/features/auth/ui/reset_password_screen.dart',
]

def wrap_with_secure_screen():
    for f in files_to_secure:
        filepath = os.path.join('/home/dt_thuat/Documents/STEM_2026-2027/zenhome_app', f)
        if not os.path.exists(filepath):
            continue
            
        with open(filepath, 'r', encoding='utf-8') as file:
            content = file.read()
            
        if 'SecureScreen' in content:
            continue
            
        # Add import
        content = "import 'package:zenhome_app/core/widgets/secure_screen.dart';\n" + content
        
        # We find the main `return Scaffold(` in the build method and wrap it.
        # But some might have DualLayerScreenWrapper or WaveBackground.
        # It's safer to just wrap the top-level widget returned by the build method of the State.
        # Actually, let's just do `return Scaffold` -> `return SecureScreen(child: Scaffold`
        # and add `)` at the very end... wait, regex replacement for `return Scaffold(` is dangerous because of the closing bracket.
        
        # A safer approach for login_screen.dart etc. is to find `Widget build(BuildContext context) {` 
        # and insert `return SecureScreen(child: Builder(builder: (context) {`
        # and at the end of the file, we can't easily do it.
        pass

if __name__ == '__main__':
    wrap_with_secure_screen()
