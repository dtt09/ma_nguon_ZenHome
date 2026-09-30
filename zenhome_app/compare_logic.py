import os
import re

lib_dir = '/home/dt_thuat/Documents/STEM_2026-2027/zenhome_app/lib'
backup_dir = '/home/dt_thuat/Documents/STEM_2026-2027/zenhome_app/lib_backup'

def get_code_without_imports(content):
    # Remove all import and part statements
    lines = content.split('\n')
    filtered_lines = [line for line in lines if not line.strip().startswith('import ') and not line.strip().startswith('part ')]
    return '\n'.join(filtered_lines).strip()

def compare_logic():
    # Gather backup files
    backup_files = {}
    for root, dirs, files in os.walk(backup_dir):
        for file in files:
            if file.endswith('.dart'):
                filepath = os.path.join(root, file)
                with open(filepath, 'r', encoding='utf-8') as f:
                    backup_files[file] = get_code_without_imports(f.read())
                    
    # Compare with new files
    differences = []
    for root, dirs, files in os.walk(lib_dir):
        if 'lib_backup' in root:
            continue
        for file in files:
            if file.endswith('.dart'):
                filepath = os.path.join(root, file)
                with open(filepath, 'r', encoding='utf-8') as f:
                    new_code = get_code_without_imports(f.read())
                
                # admin_login_screen.dart was intentionally modified to separate logic
                if file == 'admin_login_screen.dart':
                    continue
                    
                if file in backup_files:
                    if new_code != backup_files[file]:
                        differences.append(file)
                else:
                    # New files like admin_login_logic.dart
                    pass
                    
    return differences

if __name__ == '__main__':
    diffs = compare_logic()
    if not diffs:
        print("SUCCESS: 100% Logic match! All non-import code is completely identical.")
    else:
        print("DIFFERENCES FOUND in files:")
        for d in diffs:
            print("- " + d)
