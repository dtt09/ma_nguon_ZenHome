import os

replacements = {
    '0xFF121212': '0xFF090C15',
    '0xFF0A0A0A': '0xFF090C15',
    '0xFF1E1E1E': '0xFF121827',
    '0xFF1C1C1E': '0xFF1A2235',
    '0xFF2A2A2A': '0xFF1A2235',
    '0xFF6C8DF0': '0xFF5C8CFF',
}

for root, dirs, files in os.walk('lib/'):
    for file in files:
        if file.endswith('.dart'):
            filepath = os.path.join(root, file)
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
                
            original = content
            for old_color, new_color in replacements.items():
                content = content.replace(old_color, new_color)
                
            if content != original:
                with open(filepath, 'w', encoding='utf-8') as f:
                    f.write(content)
                print(f"Updated {filepath}")
