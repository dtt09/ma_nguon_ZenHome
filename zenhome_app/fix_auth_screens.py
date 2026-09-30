import os
import re

auth_dir = '/home/dt_thuat/Documents/STEM_2026-2027/zenhome_app/lib/screens/auth'

for filename in os.listdir(auth_dir):
    if filename.endswith('.dart') and not filename.endswith('.bak'):
        filepath = os.path.join(auth_dir, filename)
        with open(filepath, 'r') as f:
            content = f.read()

        # We want to replace `if (isTopLayer == false) { CODE }` with `CODE`.
        # However, it could be multi-line.
        # A simpler way is to replace `if (isTopLayer == false)` with `if (true)` or just remove it if it's single line.
        # Let's replace `if (isTopLayer == false) {` with `if (true) {`
        # and `if (isTopLayer == false)` with `if (true)`
        
        new_content = re.sub(r'if\s*\(\s*isTopLayer\s*==\s*false\s*\)', 'if (true)', content)
        
        # There might be `isTopLayer ? null : _phoneFocus` etc. We leave those alone to avoid focus node collisions.
        
        if new_content != content:
            with open(filepath, 'w') as f:
                f.write(new_content)
            print(f"Updated {filename}")

