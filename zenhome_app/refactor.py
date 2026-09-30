import os
import re

def replace_in_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Thêm import home_config_provider.dart nếu có dùng activeConfig nhưng chưa import
    if 'activeConfig' in content or 'availableHomes' in content or 'saveConfigToStorage' in content or 'switchActiveHome' in content or 'setAvailableHomes' in content:
        if 'home_config_provider.dart' not in content:
            # tìm dòng import cuối cùng để chèn
            lines = content.split('\n')
            last_import_idx = 0
            for i, line in enumerate(lines):
                if line.startswith('import '):
                    last_import_idx = i
            
            # Tính toán relative path đến lib/providers/home_config_provider.dart
            depth = filepath.count('/') - filepath.find('lib/') - 1
            rel_path = '../' * depth + 'providers/home_config_provider.dart'
            lines.insert(last_import_idx + 1, f"import '{rel_path}';")
            content = '\n'.join(lines)

    # Replaces
    # activeConfig -> ref.read(homeConfigProvider).activeConfig hoặc ref.watch(homeConfigProvider).activeConfig
    # Do this manually for each file because ref is needed.
    # Actually, using a script for this is dangerous because `ref` might not be in scope in all places.
    # I should just view each file and use multi_replace_file_content carefully.
    
    pass

if __name__ == '__main__':
    print("Script ran")
