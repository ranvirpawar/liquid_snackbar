part of 'liquid_snackbar_library.dart';

/// A single notification's lifetime; duplicate requests share one handle.
class LiquidSnackbarHandle {
  LiquidSnackbarHandle._(this._owner, this._request);
  final LiquidSnackbarController _owner;
  final LiquidSnackbarRequest _request;
  final Completer<LiquidSnackbarCloseReason> _closed =
      Completer<LiquidSnackbarCloseReason>();
  final GlobalKey<_NotificationCardState> _key =
      GlobalKey<_NotificationCardState>();

  /// Completes exactly once, including rejected, cleared and disposed requests.
  Future<LiquidSnackbarCloseReason> get closed => _closed.future;

  /// Whether cleanup has completed.
  bool get isClosed => _closed.isCompleted;

  /// Dismiss a queued or visible notification. Safe to call repeatedly.
  Future<void> dismiss() async {
    _owner._dismiss(this, LiquidSnackbarCloseReason.dismissed);
    await closed;
  }
}

/// Owns a bounded queue and its overlay. Dispose controllers that you create.
/// Attach through [LiquidSnackbarHost], [attach], or an opt-in navigator key.
class LiquidSnackbarController {
  /// Creates an independent scope. Navigator/overlay keys are opt-in only.
  LiquidSnackbarController({
    this.config = const LiquidSnackbarConfig(),
    this.navigatorKey,
    this.overlayKey,
  });

  /// Immutable scheduling and haptic settings.
  final LiquidSnackbarConfig config;

  /// Optional context-free setup using the application's existing navigator.
  final GlobalKey<NavigatorState>? navigatorKey;

  /// Optional context-free setup using an application-owned overlay.
  final GlobalKey<OverlayState>? overlayKey;

  final List<LiquidSnackbarHandle> _visible = [];
  final Queue<LiquidSnackbarHandle> _queue = Queue<LiquidSnackbarHandle>();
  OverlayState? _overlay;
  OverlayEntry? _entry;
  CapturedThemes? _themes;
  LiquidSnackbarLabels _labels = const LiquidSnackbarLabels();
  bool _disposed = false;
  bool _batching = false;
  bool _hostAttached = false;

  /// Number of visible requests, including cards animating out.
  int get visibleCount => _visible.length;

  /// Number of requests waiting for a visible slot.
  int get queuedCount => _queue.length;

  /// True after [dispose].
  bool get isDisposed => _disposed;

  /// Attach to an application-owned overlay using current inherited themes.
  /// Reattaching to another overlay closes existing requests as disposed.
  void attach(OverlayState overlay, {BuildContext? context}) {
    _checkAlive();
    if (_overlay != overlay) {
      _detach();
      _overlay = overlay;
    }
    if (context != null) {
      _themes = InheritedTheme.capture(from: context, to: overlay.context);
    }
  }

  void _checkAlive() {
    if (_disposed) {
      throw StateError('LiquidSnackbarController has been disposed.');
    }
  }

  /// Schedule immutable content and receive its lifetime handle.
  /// A full queue rejects the newest request. Duplicates return the original
  /// handle and do not invoke the suppressed request's onDismissed callback.
  LiquidSnackbarHandle show(LiquidSnackbarRequest request) {
    _checkAlive();
    if (request.duration != null && request.duration! <= Duration.zero) {
      throw ArgumentError.value(
        request.duration,
        'duration',
        'Must be positive or null.',
      );
    }
    if (config.maxVisible < 1 || config.maxQueueLength < 0) {
      throw StateError(
        'Queue limits must be non-negative with at least one visible slot.',
      );
    }
    final keyedOverlay =
        overlayKey?.currentState ?? navigatorKey?.currentState?.overlay;
    if (keyedOverlay != null && keyedOverlay != _overlay) {
      attach(keyedOverlay, context: keyedOverlay.context);
    }
    if (_overlay == null || !_overlay!.mounted) {
      throw StateError(
        'No active overlay. Use LiquidSnackbarHost, attach(), or an attached navigator/overlay key.',
      );
    }
    if (config.suppressDuplicates) {
      for (final handle in [..._visible, ..._queue]) {
        if (handle._request._identity == request._identity &&
            !handle.isClosed) {
          return handle;
        }
      }
    }
    final handle = LiquidSnackbarHandle._(this, request);
    if (_visible.length >= config.maxVisible &&
        config.policy == LiquidSnackbarPolicy.replace) {
      final previousBatching = _batching;
      _batching = true;
      _finish(_visible.first, LiquidSnackbarCloseReason.replaced);
      _batching = previousBatching;
      // A replacement callback may synchronously dispose/detach this scope.
      if (_disposed || !(_overlay?.mounted ?? false)) {
        _finish(handle, LiquidSnackbarCloseReason.disposed);
        return handle;
      }
    }
    if (_visible.length < config.maxVisible && !_batching) {
      _visible.add(handle);
      _rebuild();
    } else if (_queue.length < config.maxQueueLength) {
      _queue.add(handle);
    } else {
      _finish(handle, LiquidSnackbarCloseReason.queueFull);
    }
    return handle;
  }

  void _rebuild() {
    if (_disposed || _overlay == null || !_overlay!.mounted) return;
    if (_visible.isEmpty) {
      _removeEntry();
      return;
    }
    if (_entry == null) {
      late final OverlayEntry entry;
      entry = OverlayEntry(
        builder: (context) {
          final child = _NotificationLayer(controller: this, entry: entry);
          return _themes?.wrap(child) ?? child;
        },
      );
      _entry = entry;
      _overlay!.insert(entry);
      // An overlay may disappear before its entry ever mounts.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (identical(_entry, entry) && !(_overlay?.mounted ?? false)) {
          _lostOverlay(entry);
        }
      });
    } else {
      _entry!.markNeedsBuild();
    }
  }

  void _removeEntry() {
    final entry = _entry;
    _entry = null;
    if (entry == null) return;
    entry.remove();
    entry.dispose();
  }

  void _dismiss(LiquidSnackbarHandle handle, LiquidSnackbarCloseReason reason) {
    if (handle.isClosed) return;
    final card = handle._key.currentState;
    if (_visible.contains(handle) && card != null) {
      card.dismiss(reason);
    } else {
      _finish(handle, reason);
    }
  }

  void _finish(LiquidSnackbarHandle handle, LiquidSnackbarCloseReason reason) {
    if (handle.isClosed) return;
    _visible.remove(handle);
    _queue.remove(handle);
    handle._closed.complete(reason);
    // Clean up and unblock the queue before executing application code.
    if (!_batching && !_disposed) {
      while (_queue.isNotEmpty && _visible.length < config.maxVisible) {
        _visible.add(_queue.removeFirst());
      }
      _rebuild();
    }
    try {
      handle._request.onDismissed?.call(reason);
    } catch (error, stack) {
      _report(error, stack, 'onDismissed');
    }
  }

  /// Close every visible and waiting request immediately, without exit motion.
  /// New requests made by callbacks are scheduled after this batch.
  void dismissAll() => _finishAll(LiquidSnackbarCloseReason.dismissed);

  /// Remove only requests that have not started displaying.
  void clearQueue() {
    final handles = _queue.toList();
    final previousBatching = _batching;
    _batching = true;
    for (final handle in handles) {
      _finish(handle, LiquidSnackbarCloseReason.cleared);
    }
    _batching = previousBatching;
    _drain();
  }

  void _drain() {
    if (_batching || _disposed) return;
    while (_queue.isNotEmpty && _visible.length < config.maxVisible) {
      _visible.add(_queue.removeFirst());
    }
    _rebuild();
  }

  void _finishAll(LiquidSnackbarCloseReason reason) {
    final handles = [..._visible, ..._queue];
    final previousBatching = _batching;
    _batching = true;
    for (final handle in handles) {
      _finish(handle, reason);
    }
    _batching = previousBatching;
    _drain();
  }

  void _lostOverlay(OverlayEntry entry) {
    if (!identical(_entry, entry)) return;
    entry.remove();
    entry.dispose();
    _entry = null;
    _overlay = null;
    _finishAll(LiquidSnackbarCloseReason.disposed);
  }

  void _detach() {
    _removeEntry();
    _overlay = null;
    _themes = null;
    _finishAll(LiquidSnackbarCloseReason.disposed);
  }

  /// Release all requests and overlay resources. Idempotent.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _detach();
  }
}

void _report(Object error, StackTrace stack, String operation) {
  FlutterError.reportError(
    FlutterErrorDetails(
      exception: error,
      stack: stack,
      library: 'liquid_snackbar',
      context: ErrorDescription('while invoking $operation'),
    ),
  );
}
