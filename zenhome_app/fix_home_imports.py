import os
import re

lib_dir = '/home/dt_thuat/Documents/STEM_2026-2027/zenhome_app/lib'

replacements = {
    # Screens
    r"['\"]package:zenhome_app/screens/dashboard_screen\.dart['\"]": r"'package:zenhome_app/features/home/ui/dashboard_screen.dart'",
    r"['\"]package:zenhome_app/screens/scenes_screen\.dart['\"]": r"'package:zenhome_app/features/home/ui/scenes_screen.dart'",
    r"['\"]package:zenhome_app/screens/main_layout\.dart['\"]": r"'package:zenhome_app/features/home/ui/main_layout.dart'",
    
    # Components & Mixins
    r"['\"]package:zenhome_app/screens/main_layout/components/disabled_view\.dart['\"]": r"'package:zenhome_app/features/home/ui/components/disabled_view.dart'",
    r"['\"]package:zenhome_app/screens/main_layout/mixins/auth_sync_mixin\.dart['\"]": r"'package:zenhome_app/features/home/logic/auth_sync_mixin.dart'",
    r"['\"]package:zenhome_app/screens/main_layout/mixins/home_sync_mixin\.dart['\"]": r"'package:zenhome_app/features/home/logic/home_sync_mixin.dart'",
    
    # Widgets
    r"['\"]package:zenhome_app/widgets/device_card\.dart['\"]": r"'package:zenhome_app/features/home/ui/device_card.dart'",
    r"['\"]package:zenhome_app/widgets/room_tab\.dart['\"]": r"'package:zenhome_app/features/home/ui/room_tab.dart'",
    r"['\"]package:zenhome_app/widgets/scene_section\.dart['\"]": r"'package:zenhome_app/features/home/ui/scene_section.dart'",
    r"['\"]package:zenhome_app/widgets/schedule_section\.dart['\"]": r"'package:zenhome_app/features/home/ui/schedule_section.dart'",
    r"['\"]package:zenhome_app/widgets/timer_section\.dart['\"]": r"'package:zenhome_app/features/home/ui/timer_section.dart'",
    r"['\"]package:zenhome_app/widgets/weather_card\.dart['\"]": r"'package:zenhome_app/features/home/ui/weather_card.dart'",
    r"['\"]package:zenhome_app/widgets/home_switcher_sheet\.dart['\"]": r"'package:zenhome_app/features/home/ui/home_switcher_sheet.dart'",
    
    # Logic (Providers)
    r"['\"]package:zenhome_app/providers/home_config_provider\.dart['\"]": r"'package:zenhome_app/features/home/logic/home_config_provider.dart'",
}

for root, dirs, files in os.walk(lib_dir):
    if 'lib_backup' in root:
        continue
    for file in files:
        if file.endswith('.dart'):
            filepath = os.path.join(root, file)
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
            
            new_content = content
            for pattern, repl in replacements.items():
                new_content = re.sub(pattern, repl, new_content)
            
            if new_content != content:
                with open(filepath, 'w', encoding='utf-8') as f:
                    f.write(new_content)
                print(f"Updated imports in {filepath}")
