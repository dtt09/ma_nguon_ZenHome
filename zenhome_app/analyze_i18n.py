import os
import re
import json

def get_dart_files(d):
    for root, _, files in os.walk(d):
        for f in files:
            if f.endswith('.dart'):
                yield os.path.join(root, f)

def main():
    arb_vi_path = 'lib/l10n/app_vi.arb'
    arb_en_path = 'lib/l10n/app_en.arb'
    
    with open(arb_vi_path, 'r', encoding='utf-8') as f:
        vi_data = json.load(f)
    with open(arb_en_path, 'r', encoding='utf-8') as f:
        en_data = json.load(f)
        
    vi_keys = set([k for k in vi_data.keys() if not k.startswith('@')])
    en_keys = set([k for k in en_data.keys() if not k.startswith('@')])
    
    used_keys = set()
    dart_files = list(get_dart_files('lib'))
    
    static_texts = []
    
    for df in dart_files:
        with open(df, 'r', encoding='utf-8') as f:
            content = f.read()
            
            # Find context.tr('key')
            matches = re.findall(r"context\.tr\(['\"]([^'\"]+)['\"]\)", content)
            used_keys.update(matches)
            
            # Find static text patterns (very rough)
            # Find Text('...') that don't have context.tr
            lines = content.split('\n')
            for i, line in enumerate(lines):
                if 'Text(' in line and 'context.tr' not in line:
                    # check if it contains common Vietnamese chars or simple english text
                    if re.search(r"Text\(['\"]([^'\"]+)['\"]", line):
                        text = re.search(r"Text\(['\"]([^'\"]+)['\"]", line).group(1)
                        if text and not text.isascii() or (' ' in text and not text.startswith('http') and text != 'ZenHome' and text != 'Google'):
                            static_texts.append(f"{df}:{i+1} -> {text.strip()}")
                
                # Check for showFloatingToast strings not localized
                if 'showFloatingToast(' in line and 'context.tr' not in line:
                    static_texts.append(f"{df}:{i+1} -> Toast: {line.strip()}")
                    
    missing_vi = used_keys - vi_keys
    missing_en = used_keys - en_keys
    
    print("=== Keys used in Dart but missing in app_vi.arb ===")
    for k in missing_vi: print(k)
    print("\n=== Keys used in Dart but missing in app_en.arb ===")
    for k in missing_en: print(k)
    
    print("\n=== Potential Static Texts ===")
    for t in static_texts[:50]: print(t)

if __name__ == '__main__':
    main()
