import os
import re

auth_dir = '/home/dt_thuat/Documents/STEM_2026-2027/zenhome_app/lib/screens/auth'

for filename in os.listdir(auth_dir):
    if filename.endswith('.dart') and not filename.endswith('.bak'):
        filepath = os.path.join(auth_dir, filename)
        with open(filepath, 'r') as f:
            content = f.read()

        # Remove `field = IgnorePointer(child: field);`
        new_content = re.sub(r'\s*field\s*=\s*IgnorePointer\(\s*child:\s*field\s*\);', '', content)
        
        if new_content != content:
            with open(filepath, 'w') as f:
                f.write(new_content)
            print(f"Updated {filename}")

