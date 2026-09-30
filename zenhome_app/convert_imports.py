import os
import re

lib_dir = '/home/dt_thuat/Documents/STEM_2026-2027/zenhome_app/lib'

def fix_imports():
    for root, dirs, files in os.walk(lib_dir):
        # Skip the lib_backup dir
        if 'lib_backup' in root:
            continue
            
        for file in files:
            if not file.endswith('.dart'):
                continue
                
            filepath = os.path.join(root, file)
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Find all import '...' lines
            lines = content.split('\n')
            new_lines = []
            changed = False
            for line in lines:
                match = re.search(r"import\s+['\"](.*?)['\"];", line)
                if match:
                    import_path = match.group(1)
                    # If it's a relative path and doesn't point to dart: or package:
                    if not import_path.startswith('dart:') and not import_path.startswith('package:'):
                        # Calculate absolute path relative to lib/
                        current_dir = os.path.dirname(filepath)
                        # Resolve the relative path
                        resolved_path = os.path.normpath(os.path.join(current_dir, import_path))
                        
                        # Verify the resolved path starts with lib_dir
                        if resolved_path.startswith(lib_dir):
                            # Get relative to lib/
                            rel_to_lib = os.path.relpath(resolved_path, lib_dir)
                            # Convert to package import
                            new_import = f"package:zenhome_app/{rel_to_lib}"
                            # Standardize path separator to /
                            new_import = new_import.replace('\\', '/')
                            line = line.replace(import_path, new_import)
                            changed = True
                new_lines.append(line)
            
            if changed:
                with open(filepath, 'w', encoding='utf-8') as f:
                    f.write('\n'.join(new_lines))

if __name__ == '__main__':
    fix_imports()
    print("Converted all relative imports to absolute package imports.")
