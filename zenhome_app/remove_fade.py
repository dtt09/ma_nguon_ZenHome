import os
import re

def remove_fade(text):
    # This function finds ".fade" and removes it along with its balanced parentheses
    result = ""
    i = 0
    while i < len(text):
        if text.startswith(".fade(", i) or text.startswith(".fade()", i):
            if text.startswith(".fade()", i):
                i += 7
                continue
            # find matching parenthesis
            start = i + 5 # index of '('
            count = 1
            j = start + 1
            while j < len(text) and count > 0:
                if text[j] == '(':
                    count += 1
                elif text[j] == ')':
                    count -= 1
                j += 1
            i = j
        else:
            result += text[i]
            i += 1
    return result

for root, dirs, files in os.walk("lib"):
    for file in files:
        if file.endswith(".dart"):
            path = os.path.join(root, file)
            with open(path, "r") as f:
                content = f.read()
            new_content = remove_fade(content)
            if content != new_content:
                with open(path, "w") as f:
                    f.write(new_content)
                print(f"Updated {path}")
