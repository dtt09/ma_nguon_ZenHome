import json
import re

arb_path = 'lib/l10n/app_vi.arb'
ext_path = 'lib/utils/localization_extension.dart'

with open(arb_path, 'r', encoding='utf-8') as f:
    arb_data = json.load(f)

keys = [k for k in arb_data.keys() if not k.startswith('@')]
# Also add register_prompt
if 'register_prompt' not in keys:
    keys.append('register_prompt')

with open(ext_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Find the default: return key; line
switch_end_match = re.search(r'      default: return key;', content)
if switch_end_match:
    existing_cases = re.findall(r"case '([^']+)':", content)
    missing = [k for k in keys if k not in existing_cases]
    
    if missing:
        insert_idx = switch_end_match.start()
        insert_str = ""
        for k in missing:
            insert_str += f"      case '{k}': return l.{k};\n"
        
        new_content = content[:insert_idx] + insert_str + content[insert_idx:]
        
        with open(ext_path, 'w', encoding='utf-8') as f:
            f.write(new_content)
        
        print(f"Added {len(missing)} keys: {', '.join(missing)}")
    else:
        print("No missing keys found.")
else:
    print("Could not find default case.")
