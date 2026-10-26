part of 'liquid_snackbar_library.dart';

class _NotificationCard extends StatefulWidget {
  const _NotificationCard({
    required this.handle,
    required this.theme,
    required this.labels,
    super.key,
  });
  final LiquidSnackbarHandle handle;
  final LiquidSnackbarTheme theme;
  final LiquidSnackbarLabels labels;
  @override
  State<_NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<_NotificationCard>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _entrance;
  late final AnimationController _lifetime;
  final Set<Object> _pauses = {};
  final Set<int> _pointers = {};
  bool _dismissing = false;
  bool _acting = false;
  bool _initialized = false;
  double _drag = 0;
  bool _reduced = false;
  bool _accessible = false;

  LiquidSnackbarRequest get request => widget.handle._request;
  int get _direction => request.position == LiquidSnackbarPosition.top ? -1 : 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _entrance = AnimationController(vsync: this);
    _lifetime =
        AnimationController(
          vsync: this,
          duration: request.duration ?? const Duration(seconds: 4),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            dismiss(LiquidSnackbarCloseReason.timeout);
          }
        });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final media = MediaQuery.of(context);
    _reduced = media.disableAnimations;
    _accessible = media.accessibleNavigation;
    _entrance.duration = _reduced
        ? Duration(
            milliseconds: math.min(
              80,
              widget.theme.animationDuration.inMilliseconds,
            ),
          )
        : widget.theme.animationDuration;
    if (!_initialized) {
      _initialized = true;
      _entrance.forward();
      _haptic();
    }
    _syncTimer();
  }

  @override
  void didUpdateWidget(_NotificationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _entrance.duration = _reduced
        ? Duration(
            milliseconds: math.min(
              80,
              widget.theme.animationDuration.inMilliseconds,
            ),
          )
        : widget.theme.animationDuration;
  }

  Future<void> _haptic() async {
    final haptics = widget.handle._owner.config.haptics;
    if (haptics == LiquidSnackbarHaptics.off || _reduced) return;
    try {
      if (haptics == LiquidSnackbarHaptics.byVariant &&
          request.variant == LiquidSnackbarVariant.error) {
        await HapticFeedback.mediumImpact();
      } else {
        await HapticFeedback.lightImpact();
      }
    } on MissingPluginException {
      // Haptics are optional on unsupported platforms.
    } on PlatformException {
      // Platforms may decline feedback; notifications still function.
    }
  }

  void _pause(Object reason, bool paused) {
    if (paused) {
      _pauses.add(reason);
    } else {
      _pauses.remove(reason);
    }
    _syncTimer();
  }

  void _syncTimer() {
    if (_dismissing ||
        request.duration == null ||
        _accessible ||
        _pauses.isNotEmpty) {
      _lifetime.stop();
    } else if (!_lifetime.isAnimating && !_lifetime.isCompleted) {
      _lifetime.forward();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _pause('lifecycle', state != AppLifecycleState.resumed);
  }

  Future<void> dismiss(LiquidSnackbarCloseReason reason) async {
    if (_dismissing || !mounted) return;
    _dismissing = true;
    _lifetime.stop();
    try {
      await _entrance.reverse().orCancel;
    } on TickerCanceled {
      return;
    }
    if (mounted) widget.handle._owner._finish(widget.handle, reason);
  }

  Future<void> _act() async {
    final action = request.action;
    if (_acting || action == null || _dismissing) return;
    setState(() => _acting = true);
    _pause('action', true);
    try {
      await action.onPressed();
    } catch (error, stack) {
      _report(error, stack, 'action');
    } finally {
      if (mounted) {
        setState(() => _acting = false);
        _pause('action', false);
        if (action.dismissOnAction) dismiss(LiquidSnackbarCloseReason.action);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _entrance.dispose();
    _lifetime.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final style =
        request.customStyle ??
        theme.variantStyles[request.variant] ??
        const LiquidSnackbarTheme().variantStyles[LiquidSnackbarVariant
            .neutral]!;
    final labels = request.labels ?? widget.labels;
    final announcement =
        labels.announcementBuilder?.call(request) ??
        [if (request.title != null) request.title!, request.message].join('. ');
    final dismissLabel =
        labels.dismissLabel ??
        MaterialLocalizations.of(context).modalBarrierDismissLabel;
    final radius = BorderRadius.circular(
      request.quick ? theme.pillRadius : theme.radius,
    );
    final solid = theme.solid || _reduced;
    final base = theme.surfaceColor.withValues(
      alpha: solid ? 1 : theme.surfaceOpacity,
    );
    final surface = Color.alphaBlend(
      style.color.withValues(alpha: theme.tintOpacity),
      base,
    );

    Widget content = Padding(
      padding: theme.padding,
      child: request.quick
          ? ExcludeSemantics(
              child: Text(
                request.message,
                style: theme.messageStyle,
                textAlign: TextAlign.center,
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        end: 12,
                        top: 4,
                      ),
                      child: ExcludeSemantics(
                        child: Icon(style.icon, size: 24, color: style.color),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (request.title != null)
                            ExcludeSemantics(
                              child: Text(
                                request.title!,
                                style: theme.titleStyle,
                              ),
                            ),
                          ExcludeSemantics(
                            child: Text(
                              request.message,
                              style: theme.messageStyle,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (request.showCloseButton)
                      IconButton(
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        tooltip: dismissLabel,
                        color: theme.messageStyle.color,
                        onPressed: () =>
                            dismiss(LiquidSnackbarCloseReason.dismissed),
                        icon: const Icon(Icons.close_rounded, size: 20),
                      ),
                  ],
                ),
                if (request.action != null)
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      onPressed: _acting ? null : _act,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        foregroundColor: theme.actionStyle.color,
                        textStyle: Theme.of(
                          context,
                        ).textTheme.labelLarge?.merge(theme.actionStyle),
                      ),
                      child: Text(request.action!.label),
                    ),
                  ),
              ],
            ),
    );
    content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        content,
        if (request.showProgress && request.duration != null && !_accessible)
          AnimatedBuilder(
            animation: _lifetime,
            builder: (context, child) => LinearProgressIndicator(
              value: 1 - _lifetime.value,
              minHeight: 2,
              color: style.color,
              backgroundColor: Colors.transparent,
            ),
          ),
      ],
    );
    content = DecoratedBox(
      decoration: BoxDecoration(borderRadius: radius, boxShadow: theme.shadows),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          enabled: !solid && theme.blurSigma > 0,
          filter: ImageFilter.blur(
            sigmaX: theme.blurSigma,
            sigmaY: theme.blurSigma,
          ),
          child: Material(
            color: surface,
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: theme.border,
            ),
            child: content,
          ),
        ),
      ),
    );
    content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: content,
    );
    if (request.quick) content = IntrinsicWidth(child: content);

    // Label text once; retain child action/close button semantics.
    content = Semantics(
      container: true,
      liveRegion: true,
      label: announcement,
      onDismiss: () => dismiss(LiquidSnackbarCloseReason.dismissed),
      child: content,
    );
    content = Focus(
      onFocusChange: (focused) => _pause('focus', focused),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          dismiss(LiquidSnackbarCloseReason.dismissed);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        onEnter: (_) => _pause('hover', true),
        onExit: (_) => _pause('hover', false),
        child: Listener(
          onPointerDown: (event) {
            _pointers.add(event.pointer);
            _pause('touch', true);
          },
          onPointerUp: (event) {
            _pointers.remove(event.pointer);
            _pause('touch', _pointers.isNotEmpty);
          },
          onPointerCancel: (event) {
            _pointers.remove(event.pointer);
            _pause('touch', _pointers.isNotEmpty);
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: request.action == null && !request.showCloseButton
                ? () => dismiss(LiquidSnackbarCloseReason.dismissed)
                : null,
            onVerticalDragUpdate: (details) => setState(() {
              _drag = (_drag + details.delta.dy) * _direction >= 0
                  ? _drag + details.delta.dy
                  : 0;
            }),
            onVerticalDragEnd: (details) {
              if (_drag * _direction > 48 ||
                  details.velocity.pixelsPerSecond.dy * _direction > 600) {
                dismiss(LiquidSnackbarCloseReason.swipe);
              } else {
                setState(() => _drag = 0);
              }
            },
            onVerticalDragCancel: () => setState(() => _drag = 0),
            child: AnimatedContainer(
              duration: _reduced
                  ? Duration.zero
                  : const Duration(milliseconds: 100),
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(0, _reduced ? 0 : _drag, 0),
              child: content,
            ),
          ),
        ),
      ),
    );
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _entrance,
        child: content,
        builder: (context, child) {
          final value = theme.animationCurve.transform(_entrance.value);
          return Opacity(
            opacity: value.clamp(0, 1),
            child: Transform.translate(
              offset: Offset(0, _reduced ? 0 : (1 - value) * 24 * _direction),
              child: child,
            ),
          );
        },
      ),
    );
  }
}
