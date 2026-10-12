import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:sheet_navigator/src/stack/visible_scroll_positions.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

class const SheetScrolledContentDragGate({
  required final SheetController controller,
  required final Widget child,
  super.key,
}) extends StatefulWidget {
  @override
  State<SheetScrolledContentDragGate> createState() => _SheetScrolledContentDragGateState();
}

class _SheetScrolledContentDragGateState extends State<SheetScrolledContentDragGate> {
  static const _tolerance = 1.0;

  final _tickerModeNotifiers = <ValueListenable<TickerModeData>>{};

  @override
  void dispose() {
    _syncTickerModeNotifiers(const {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scrollController = PrimaryScrollController.maybeOf(context);

    return ListenableBuilder(
      listenable: Listenable.merge([widget.controller, ?scrollController]),
      builder: (context, child) {
        _syncTickerModeNotifiers(_attachedTickerModeNotifiers(scrollController));

        return ScrollConfiguration(
          behavior: _isSheetDragOnly(scrollController)
              ? ScrollConfiguration.of(context).copyWith(dragDevices: const {})
              : ScrollConfiguration.of(context),
          child: child!,
        );
      },
      child: widget.child,
    );
  }

  Set<ValueListenable<TickerModeData>> _attachedTickerModeNotifiers(
    ScrollController? scrollController,
  ) => {
    for (final position in scrollController?.positions ?? const <ScrollPosition>[])
      TickerMode.getValuesNotifier(position.context.storageContext),
  };

  void _syncTickerModeNotifiers(Set<ValueListenable<TickerModeData>> next) {
    for (final notifier in _tickerModeNotifiers.difference(next)) {
      notifier.removeListener(_onVisibleContentChanged);
    }
    for (final notifier in next.difference(_tickerModeNotifiers)) {
      notifier.addListener(_onVisibleContentChanged);
    }
    _tickerModeNotifiers
      ..clear()
      ..addAll(next);
  }

  void _onVisibleContentChanged() {
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else if (mounted) {
      setState(() {});
    }
  }

  bool _isSheetDragOnly(ScrollController? scrollController) {
    final metrics = widget.controller.metrics;
    if (metrics == null || scrollController == null) return false;
    if (metrics.offset >= metrics.maxOffset - _tolerance) return false;

    return scrollController.visiblePositions.any(
      (position) =>
          position.hasContentDimensions && position.pixels > position.minScrollExtent + _tolerance,
    );
  }
}
