import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../core/widgets/zen_liquid_glass.dart';

/// The same controller drives page swipes and the dock's selection.
class HomeNavigationDock extends StatefulWidget {
  const HomeNavigationDock({
    super.key,
    required this.controller,
    required this.currentIndex,
  });

  final PageController controller;
  final int currentIndex;

  @override
  State<HomeNavigationDock> createState() => _HomeNavigationDockState();
}

class _HomeNavigationDockState extends State<HomeNavigationDock> {
  final _dragPage = ValueNotifier<double?>(null);

  @override
  void dispose() {
    _dragPage.dispose();
    super.dispose();
  }

  void _select(int index) {
    final controller = widget.controller;
    if (!controller.hasClients) return;
    HapticFeedback.selectionClick();
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.jumpToPage(index);
    } else {
      controller.animateToPage(
        index,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark
        ? context.zenColors.primaryAccent
        : context.zenColors.primary;
    final muted = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final tabs = [
      (Icons.home_rounded, context.tr('tab_home')),
      (Icons.auto_awesome_mosaic_rounded, context.tr('tab_scene')),
      (Icons.settings_rounded, context.tr('tab_settings')),
    ];
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ZenGlassContainer(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.all(4),
            borderRadius: 26,
            blurSigma: 8,
            child: LayoutBuilder(
              builder: (context, constraints) {
                void track(Offset position) {
                  final fraction = position.dx / constraints.maxWidth;
                  _dragPage.value =
                      ((rtl ? 1 - fraction : fraction) * tabs.length - 0.5)
                          .clamp(0, tabs.length - 1)
                          .toDouble();
                }

                return GestureDetector(
                  onHorizontalDragStart: (event) => track(event.localPosition),
                  onHorizontalDragUpdate: (event) => track(event.localPosition),
                  onHorizontalDragCancel: () => _dragPage.value = null,
                  onHorizontalDragEnd: (_) {
                    final target = _dragPage.value;
                    _dragPage.value = null;
                    if (target != null) _select(target.round());
                  },
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ListenableBuilder(
                          listenable: Listenable.merge([
                            widget.controller,
                            _dragPage,
                          ]),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: accent.withValues(
                                alpha: isDark ? 0.15 : 0.10,
                              ),
                              borderRadius: BorderRadius.circular(22),
                            ),
                          ),
                          builder: (context, child) {
                            final controller = widget.controller;
                            final page =
                                _dragPage.value ??
                                (controller.hasClients &&
                                        controller.position.haveDimensions
                                    ? controller.page
                                    : null) ??
                                widget.currentIndex.toDouble();
                            return FractionallySizedBox(
                              alignment: AlignmentDirectional(
                                (page - 1).clamp(-1, 1).toDouble(),
                                0,
                              ),
                              widthFactor: 1 / tabs.length,
                              child: child,
                            );
                          },
                        ),
                      ),
                      Row(
                        children: [
                          for (var i = 0; i < tabs.length; i++)
                            Expanded(
                              child: Semantics(
                                selected: i == widget.currentIndex,
                                button: true,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(22),
                                  onTap: () => _select(i),
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      minHeight: 48,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 3,
                                        vertical: 5,
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            tabs[i].$1,
                                            size: 20,
                                            color: i == widget.currentIndex
                                                ? accent
                                                : muted,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            tabs[i].$2,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 12,
                                              height: 1.2,
                                              fontWeight:
                                                  i == widget.currentIndex
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: i == widget.currentIndex
                                                  ? accent
                                                  : muted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
