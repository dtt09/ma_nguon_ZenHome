import 'package:flutter/material.dart';
import 'package:zenhome_app/core/widgets/animations/wave_background.dart';

/// Single-tree wrapper (by default `useSingleLayer: true`) over static themed [WaveBackground].
/// Retains the legacy `(context, isTopLayer, controller)` builder signature for compatibility
/// while eliminating duplicate widget subtrees, duplicate controllers, and scroll sync loops.
class DualLayerScreenWrapper extends StatefulWidget {
  final Widget Function(
    BuildContext context,
    bool isTopLayer,
    ScrollController controller,
  ) builder;
  final double waveHeightPercent;
  final bool useSingleLayer;

  const DualLayerScreenWrapper({
    super.key,
    required this.builder,
    this.waveHeightPercent = 0.4,
    this.useSingleLayer = true,
  });

  @override
  State<DualLayerScreenWrapper> createState() => _DualLayerScreenWrapperState();
}

class _DualLayerScreenWrapperState extends State<DualLayerScreenWrapper> {
  final ScrollController _bottomController = ScrollController();
  ScrollController? _topController;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    if (!widget.useSingleLayer) {
      _initDualSync();
    }
  }

  void _initDualSync() {
    _topController ??= ScrollController();
    _bottomController.addListener(_syncBottomToTop);
    _topController!.addListener(_syncTopToBottom);
  }

  void _syncBottomToTop() {
    if (_topController != null) {
      _syncScroll(_bottomController, _topController!);
    }
  }

  void _syncTopToBottom() {
    if (_topController != null) {
      _syncScroll(_topController!, _bottomController);
    }
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
  void didUpdateWidget(covariant DualLayerScreenWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.useSingleLayer && _topController == null) {
      _initDualSync();
    }
  }

  @override
  void dispose() {
    _bottomController.removeListener(_syncBottomToTop);
    _topController?.removeListener(_syncTopToBottom);
    _bottomController.dispose();
    _topController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.useSingleLayer) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: WaveBackground(
              heightPercent: widget.waveHeightPercent,
              animate: false,
            ),
          ),
          widget.builder(context, true, _bottomController),
        ],
      );
    }

    return Stack(
      children: [
        widget.builder(context, false, _bottomController),
        WaveBackground(
          heightPercent: widget.waveHeightPercent,
          animate: false,
          child: widget.builder(context, true, _topController!),
        ),
      ],
    );
  }
}
