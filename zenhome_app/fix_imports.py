import os
import re

for root, dirs, files in os.walk("lib"):
    for file in files:
        if file.endswith(".dart"):
            filepath = os.path.join(root, file)
            with open(filepath, "r") as f:
                content = f.read()
            original = content
            
            # Fix imports
            content = content.replace("import './providers/theme_provider.dart';", "import '../providers/theme_provider.dart';")
            content = content.replace("import '../utils/helpers.dart';", "import '../../utils/helpers.dart';")
            
            # Actually, just regex the bad imports in auth/
            if "screens/auth" in filepath or "screens/settings" in filepath or "screens/admin" in filepath or "screens/setup" in filepath:
                content = content.replace("import '../providers/theme_provider.dart';", "import '../../providers/theme_provider.dart';")

            # Fix ConsumerWidget build method missing WidgetRef
            # Find class XXX extends ConsumerWidget { ... Widget build(BuildContext context)
            # This is hard with simple replace, let's just do it for ZenHomeApp
            if "class ZenHomeApp extends ConsumerWidget" in content:
                content = content.replace("Widget build(BuildContext context) {", "Widget build(BuildContext context, WidgetRef ref) {")
            
            # Also for SettingsScreen there was a missing ref
            if "class SettingsScreen extends ConsumerWidget" in content:
                content = content.replace("Widget build(BuildContext context) {", "Widget build(BuildContext context, WidgetRef ref) {")

            if content != original:
                with open(filepath, "w") as f:
                    f.write(content)

