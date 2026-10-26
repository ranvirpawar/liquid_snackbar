part of 'liquid_snackbar_library.dart';

/// The semantic category; custom notifications supply their own style.
enum LiquidSnackbarVariant {
  /// A completed operation.
  success,

  /// An unsuccessful operation.
  error,

  /// A condition needing attention.
  warning,

  /// Contextual information.
  info,

  /// Feedback without a semantic category.
  neutral,

  /// A caller-defined category and visual style.
  custom,
}

/// Screen edge at which notifications are stacked.
enum LiquidSnackbarPosition {
  /// Below the top safe area; dismiss by swiping upward.
  top,

  /// Above the keyboard/bottom safe area; dismiss by swiping downward.
  bottom,
}

/// How new requests behave when all visible slots are occupied.
enum LiquidSnackbarPolicy {
  /// Wait in a bounded, first-in-first-out queue.
  queue,

  /// Immediately replace the oldest visible notification.
  replace,
}

/// Optional platform haptic feedback on presentation.
enum LiquidSnackbarHaptics {
  /// No platform calls (the default).
  off,

  /// Light impact for every variant.
  light,

  /// Medium impact for errors, light for other variants.
  byVariant,
}

/// Why a handle's [LiquidSnackbarHandle.closed] future completed.
enum LiquidSnackbarCloseReason {
  /// Its visible duration elapsed.
  timeout,

  /// The caller requested dismissal.
  dismissed,

  /// A notification action requested dismissal.
  action,

  /// The user swiped toward the screen edge.
  swipe,

  /// A newer notification replaced it.
  replaced,

  /// It exceeded the queue capacity (newest request is rejected).
  queueFull,

  /// It was removed before being displayed.
  cleared,

  /// The owning host, overlay, or controller was disposed.
  disposed,
}

/// Queue settings shared by all requests on one controller.
@immutable
class LiquidSnackbarConfig {
  /// Creates bounded notification settings.
  const LiquidSnackbarConfig({
    this.maxVisible = 1,
    this.maxQueueLength = 20,
    this.suppressDuplicates = true,
    this.policy = LiquidSnackbarPolicy.queue,
    this.haptics = LiquidSnackbarHaptics.off,
  }) : assert(maxVisible > 0),
       assert(maxQueueLength >= 0);

  /// Maximum simultaneously visible cards, shared across both positions.
  final int maxVisible;

  /// Maximum waiting requests; overflow rejects the newest request.
  final int maxQueueLength;

  /// Return the existing handle when an active/waiting duplicate is found.
  final bool suppressDuplicates;

  /// Full-slot behavior.
  final LiquidSnackbarPolicy policy;

  /// Presentation feedback, disabled by default.
  final LiquidSnackbarHaptics haptics;
}

/// Localizable accessibility labels supplied at the host or per notification.
@immutable
class LiquidSnackbarLabels {
  /// Overrides the ambient Material dismiss label and announcement builder.
  const LiquidSnackbarLabels({this.dismissLabel, this.announcementBuilder});

  /// A localized close-button label; null uses MaterialLocalizations.
  final String? dismissLabel;

  /// Builds the notification live-region label from localized app content.
  final String Function(LiquidSnackbarRequest request)? announcementBuilder;
}

/// A keyboard-focusable action with exception-safe invocation.
@immutable
class LiquidSnackbarAction {
  /// Creates an action; asynchronous errors are also reported to Flutter.
  const LiquidSnackbarAction({
    required this.label,
    required this.onPressed,
    this.dismissOnAction = true,
  });

  /// Localized text displayed on the action button.
  final String label;

  /// Operation to perform. Repeated activation is blocked while it runs.
  final FutureOr<void> Function() onPressed;

  /// Dismiss after completion, including when the callback throws.
  final bool dismissOnAction;
}

/// Immutable notification content, independent of any app or state manager.
@immutable
class LiquidSnackbarRequest {
  /// Creates a card, or a message-only pill when [quick] is true.
  const LiquidSnackbarRequest({
    required this.message,
    this.title,
    this.variant = LiquidSnackbarVariant.neutral,
    this.customStyle,
    this.position = LiquidSnackbarPosition.bottom,
    this.duration = const Duration(seconds: 4),
    this.action,
    this.quick = false,
    this.showCloseButton = false,
    this.showProgress = false,
    this.duplicateKey,
    this.labels,
    this.onDismissed,
  }) : assert(variant != LiquidSnackbarVariant.custom || customStyle != null),
       assert(!quick || (title == null && action == null && !showCloseButton));

  /// Localized body text; also used for the default announcement.
  final String message;

  /// Optional localized heading.
  final String? title;

  /// Status category, indicated by shape as well as color.
  final LiquidSnackbarVariant variant;

  /// Overrides the variant style; required for the custom variant.
  final LiquidSnackbarVariantStyle? customStyle;

  /// Preferred screen edge.
  final LiquidSnackbarPosition position;

  /// Visible time excluding pauses; null persists until dismissed.
  /// Accessible-navigation mode also disables automatic dismissal.
  final Duration? duration;

  /// Optional action. Not supported by message-only pills.
  final LiquidSnackbarAction? action;

  /// Render a compact, message-only pill.
  final bool quick;

  /// Include an explicit localized close button.
  final bool showCloseButton;

  /// Display a determinate timer progress indicator.
  final bool showProgress;

  /// Identity for duplicate suppression. Default: title/message/variant/edge.
  final Object? duplicateKey;

  /// Per-request accessibility overrides.
  final LiquidSnackbarLabels? labels;

  /// Invoked once after cleanup. Errors are reported and cannot stall queues.
  final ValueChanged<LiquidSnackbarCloseReason>? onDismissed;

  Object get _identity =>
      duplicateKey ?? (message, title, variant, position, quick);
}
