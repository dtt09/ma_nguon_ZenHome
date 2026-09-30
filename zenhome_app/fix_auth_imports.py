import os
import re

lib_dir = '/home/dt_thuat/Documents/STEM_2026-2027/zenhome_app/lib'

replacements = {
    # Screens
    r"['\"](?:\.\./)*screens/auth/(.*?)\.dart['\"]": r"'package:zenhome_app/features/auth/ui/\1.dart'",
    r"['\"]package:zenhome_app/screens/auth/(.*?)\.dart['\"]": r"'package:zenhome_app/features/auth/ui/\1.dart'",
    
    # Mixins
    r"['\"](?:\.\./)*screens/auth/mixins/(.*?)\.dart['\"]": r"'package:zenhome_app/features/auth/logic/\1.dart'",
    r"['\"]package:zenhome_app/screens/auth/mixins/(.*?)\.dart['\"]": r"'package:zenhome_app/features/auth/logic/\1.dart'",
    r"['\"]mixins/(.*?)\.dart['\"]": r"'package:zenhome_app/features/auth/logic/\1.dart'", # From inside ui
    
    # Providers
    r"['\"](?:\.\./)*providers/auth_provider\.dart['\"]": r"'package:zenhome_app/features/auth/logic/auth_provider.dart'",
    r"['\"]package:zenhome_app/providers/auth_provider\.dart['\"]": r"'package:zenhome_app/features/auth/logic/auth_provider.dart'",
    
    # Repositories
    r"['\"](?:\.\./)*repositories/auth_repository\.dart['\"]": r"'package:zenhome_app/features/auth/data/auth_repository.dart'",
    r"['\"]package:zenhome_app/repositories/auth_repository\.dart['\"]": r"'package:zenhome_app/features/auth/data/auth_repository.dart'",
}

for root, dirs, files in os.walk(lib_dir):
    for file in files:
        if file.endswith('.dart'):
            filepath = os.path.join(root, file)
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
            
            new_content = content
            for pattern, repl in replacements.items():
                new_content = re.sub(pattern, repl, new_content)
            
            if new_content != content:
                with open(filepath, 'w', encoding='utf-8') as f:
                    f.write(new_content)
                print(f"Updated imports in {filepath}")
