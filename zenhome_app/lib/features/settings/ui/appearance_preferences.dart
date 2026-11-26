import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/localization_extension.dart';

class AppearancePreferences extends StatelessWidget {
  const AppearancePreferences({
    super.key,
    required this.mode,
    required this.language,
    required this.onThemeChanged,
    required this.onLanguageChanged,
  });

  final ThemeMode mode;
  final String language;
  final void Function(ThemeMode, Offset) onThemeChanged;
  final ValueChanged<String> onLanguageChanged;

  @override
  Widget build(BuildContext context) {
    final themeOptions = [
      (ThemeMode.light, Icons.light_mode_outlined, context.tr('theme_light')),
      (
        ThemeMode.system,
        Icons.brightness_auto_outlined,
        context.tr('theme_system'),
      ),
      (ThemeMode.dark, Icons.dark_mode_outlined, context.tr('theme_dark')),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('theme_mode'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            children: [
              for (final (value, icon, label) in themeOptions)
                Builder(
                  builder: (buttonContext) {
                    return _Option(
                      label: label,
                      icon: icon,
                      selected: mode == value,
                      onTap: () {
                        final box =
                            buttonContext.findRenderObject() as RenderBox;
                        onThemeChanged(
                          value,
                          box.localToGlobal(box.size.center(Offset.zero)),
                        );
                      },
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            context.tr('language'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            children: [
              for (final (code, label) in [
                ('vi', 'Tiếng Việt'),
                ('en', 'English'),
              ])
                _Option(
                  label: label,
                  selected: code == language,
                  onTap: () => onLanguageChanged(code),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark
        ? context.zenColors.primaryAccent
        : context.zenColors.primaryDark;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: selected
                    ? accent.withValues(alpha: 0.10)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (selected ? accent : scheme.onSurface).withValues(
                    alpha: selected ? 0.35 : 0.12,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(
                        icon,
                        size: 16,
                        color: selected ? accent : scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected ? accent : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
