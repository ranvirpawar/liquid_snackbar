part of 'liquid_snackbar_library.dart';

/// Explicit-context entry point. No global navigator key or global queue.
abstract final class LiquidSnackbar {
  static final Expando<LiquidSnackbarController> _overlays =
      Expando<LiquidSnackbarController>();

  /// Show a card in the nearest host, or the nearest Navigator overlay.
  /// Without a host, scheduling uses default config scoped to that overlay.
  static LiquidSnackbarHandle show(
    BuildContext context, {
    required String message,
    String? title,
    LiquidSnackbarVariant variant = LiquidSnackbarVariant.neutral,
    LiquidSnackbarVariantStyle? customStyle,
    LiquidSnackbarPosition position = LiquidSnackbarPosition.bottom,
    Duration? duration = const Duration(seconds: 4),
    LiquidSnackbarAction? action,
    bool quick = false,
    bool showCloseButton = false,
    bool showProgress = false,
    Object? duplicateKey,
    LiquidSnackbarLabels? labels,
    ValueChanged<LiquidSnackbarCloseReason>? onDismissed,
  }) => of(context).show(
    LiquidSnackbarRequest(
      message: message,
      title: title,
      variant: variant,
      customStyle: customStyle,
      position: position,
      duration: duration,
      action: action,
      quick: quick,
      showCloseButton: showCloseButton,
      showProgress: showProgress,
      duplicateKey: duplicateKey,
      labels: labels,
      onDismissed: onDismissed,
    ),
  );

  /// Resolve the nearest host's controller, or an overlay-scoped controller.
  static LiquidSnackbarController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_SnackbarScope>();
    if (scope != null) return scope.controller;
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) {
      throw FlutterError(
        'LiquidSnackbar requires an Overlay or LiquidSnackbarHost ancestor.',
      );
    }
    final controller = _overlays[overlay] ??= LiquidSnackbarController();
    controller.attach(overlay, context: context);
    return controller;
  }

  /// Immediately dismiss all notifications in the resolved scope.
  static void dismissAll(BuildContext context) => of(context).dismissAll();

  /// Remove pending notifications in the resolved scope.
  static void clearQueue(BuildContext context) => of(context).clearQueue();
}

/// Preferred scoped setup. Creates its own overlay above [child], and releases
/// notifications when removed. Place inside MaterialApp's builder or a route.
class LiquidSnackbarHost extends StatefulWidget {
  /// Creates a scope. An external controller is detached, not disposed, on exit.
  const LiquidSnackbarHost({
    required this.child,
    this.controller,
    this.config = const LiquidSnackbarConfig(),
    this.labels = const LiquidSnackbarLabels(),
    super.key,
  });

  /// Application content below notifications.
  final Widget child;

  /// Optional externally owned controller for context-free calls.
  final LiquidSnackbarController? controller;

  /// Used only when the host creates its controller.
  final LiquidSnackbarConfig config;

  /// Accessibility labels inherited by requests without their own override.
  final LiquidSnackbarLabels labels;

  @override
  State<LiquidSnackbarHost> createState() => _LiquidSnackbarHostState();
}

class _LiquidSnackbarHostState extends State<LiquidSnackbarHost> {
  final GlobalKey<OverlayState> _overlayKey = GlobalKey<OverlayState>();
  late LiquidSnackbarController _controller;
  late OverlayEntry _content;

  @override
  void initState() {
    super.initState();
    _claimController();
    _content = OverlayEntry(
      builder: (_) =>
          _SnackbarScope(controller: _controller, child: widget.child),
    );
  }

  void _claimController() {
    _controller =
        widget.controller ?? LiquidSnackbarController(config: widget.config);
    if (_controller._hostAttached || _controller.isDisposed) {
      throw StateError(
        'A controller must be alive and owned by only one host.',
      );
    }
    _controller._hostAttached = true;
    _controller._labels = widget.labels;
    // The overlay attaches during layout, before callers interact with child.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.attach(_overlayKey.currentState!);
    });
  }

  void _releaseController(LiquidSnackbarController? supplied) {
    _controller._hostAttached = false;
    if (supplied == null) {
      _controller.dispose();
    } else {
      _controller._detach();
    }
  }

  @override
  void didUpdateWidget(LiquidSnackbarHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        (widget.controller == null && oldWidget.config != widget.config)) {
      _releaseController(oldWidget.controller);
      _claimController();
    }
    _controller._labels = widget.labels;
    _content.markNeedsBuild();
    _controller._entry?.markNeedsBuild();
  }

  @override
  void dispose() {
    _releaseController(widget.controller);
    _content.remove();
    _content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Overlay(key: _overlayKey, initialEntries: [_content]);
}

class _SnackbarScope extends InheritedWidget {
  const _SnackbarScope({required this.controller, required super.child});
  final LiquidSnackbarController controller;
  @override
  bool updateShouldNotify(_SnackbarScope oldWidget) =>
      oldWidget.controller != controller;
}

class _NotificationLayer extends StatefulWidget {
  const _NotificationLayer({required this.controller, required this.entry});
  final LiquidSnackbarController controller;
  final OverlayEntry entry;
  @override
  State<_NotificationLayer> createState() => _NotificationLayerState();
}

class _NotificationLayerState extends State<_NotificationLayer> {
  @override
  void dispose() {
    widget.controller._lostOverlay(widget.entry);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context).extension<LiquidSnackbarTheme>() ??
        const LiquidSnackbarTheme();
    final media = MediaQuery.of(context);
    final margin = theme.margin.resolve(Directionality.of(context));
    return Positioned.fill(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          math.max(media.viewPadding.left, media.viewInsets.left) + margin.left,
          math.max(media.viewPadding.top, media.viewInsets.top) + margin.top,
          math.max(media.viewPadding.right, media.viewInsets.right) +
              margin.right,
          math.max(media.viewPadding.bottom, media.viewInsets.bottom) +
              margin.bottom,
        ),
        child: Stack(
          children: [
            for (final position in LiquidSnackbarPosition.values)
              Align(
                alignment: position == LiquidSnackbarPosition.top
                    ? Alignment.topCenter
                    : Alignment.bottomCenter,
                child: SingleChildScrollView(
                  reverse: position == LiquidSnackbarPosition.bottom,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final handle in widget.controller._visible.where(
                        (h) => h._request.position == position,
                      ))
                        Padding(
                          padding: EdgeInsets.only(bottom: theme.gap),
                          child: Align(
                            alignment: theme.alignment,
                            heightFactor: 1,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: theme.maxWidth,
                              ),
                              child: _NotificationCard(
                                key: handle._key,
                                handle: handle,
                                theme: theme,
                                labels: widget.controller._labels,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
