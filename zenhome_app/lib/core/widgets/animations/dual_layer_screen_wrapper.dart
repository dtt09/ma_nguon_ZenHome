import 'package:flutter/material.dart';
import 'package:zenhome_app/core/widgets/animations/wave_background.dart';

class DualLayerScreenWrapper extends StatefulWidget {
  final Widget Function(
    BuildContext context,
    bool isTopLayer,
    ScrollController controller,
  )
  builder;
  final double waveHeightPercent;

  const DualLayerScreenWrapper({
    super.key,
    required this.builder,
    this.waveHeightPercent = 0.4,
  });

  @override
  State<DualLayerScreenWrapper> createState() => _DualLayerScreenWrapperState();
}

class _DualLayerScreenWrapperState extends State<DualLayerScreenWrapper> {
  final ScrollController _bottomController = ScrollController();
  final ScrollController _topController = ScrollController();

  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _bottomController.addListener(
      () => _syncScroll(_bottomController, _topController),
    );
    _topController.addListener(
      () => _syncScroll(_topController, _bottomController),
    );
  }

  void _syncScroll(ScrollController source, ScrollController target) {
    if (_isSyncing) return;
    if (source.hasClients && target.hasClients) {
      if (source.offset != target.offset) {
        _isSyncing = true;
        target.jumpTo(source.offset);
        _isSyncing = false;
      }
    }
  }

  @override
  void dispose() {
    _bottomController.dispose();
    _topController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Base Layer (Bottom): Interacts with user, controls scrolling
        widget.builder(context, false, _bottomController),

        // 2. Wave Layer (Top): Clipped, syncs scroll
        WaveBackground(
          heightPercent: widget.waveHeightPercent,
          child: widget.builder(context, true, _topController),
        ),
      ],
    );
  }
}
