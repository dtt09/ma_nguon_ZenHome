import os
import re

lib_dir = '/home/dt_thuat/Documents/STEM_2026-2027/zenhome_app/lib'

# 1. Build lookup table: filename -> package:zenhome_app/path/to/file.dart
lookup = {}
for root, dirs, files in os.walk(lib_dir):
    if 'lib_backup' in root:
        continue
    for file in files:
        if file.endswith('.dart'):
            filepath = os.path.join(root, file)
            rel_path = os.path.relpath(filepath, lib_dir)
            package_path = f"package:zenhome_app/{rel_path}"
            # Standardize to forward slashes
            package_path = package_path.replace('\\', '/')
            lookup[file] = package_path

# 2. Replace all imports
def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    lines = content.split('\n')
    new_lines = []
    changed = False
    
    for line in lines:
        match = re.search(r"(?:import|part)\s+['\"](.*?)['\"]", line)
        if match:
            import_path = match.group(1)
            # Skip dart: core libraries
            if import_path.startswith('dart:'):
                new_lines.append(line)
                continue
            
            # Skip external packages
            if import_path.startswith('package:') and not import_path.startswith('package:zenhome_app/'):
                new_lines.append(line)
                continue
            
            filename = os.path.basename(import_path)
            
            # If it's a part file, it MUST be relative. 
            # In Dart, `part 'something.g.dart'` must be a relative URI.
            if line.strip().startswith('part '):
                # Just keep it as filename, assuming it's in the same directory
                if import_path != filename:
                    line = line.replace(import_path, filename)
                    changed = True
            elif filename in lookup:
                new_import = lookup[filename]
                line = line.replace(import_path, new_import)
                changed = True
        
        new_lines.append(line)
        
    if changed:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write('\n'.join(new_lines))

for root, dirs, files in os.walk(lib_dir):
    if 'lib_backup' in root:
        continue
    for file in files:
        if file.endswith('.dart'):
            process_file(os.path.join(root, file))

print("All imports fixed globally.")
