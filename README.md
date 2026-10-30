# liquid_snackbar

[![pub.dev](https://img.shields.io/pub/v/liquid_snackbar.svg)](https://pub.dev/packages/liquid_snackbar)

Small, polished glass notifications with bounded queues and explicit ownership.
Flutter SDK only. No third-party runtime dependencies, global navigator key,
state-management integration, assets, network calls, or custom fonts required.

### Glass notification styles

![Liquid Snackbar promotional artwork](https://raw.githubusercontent.com/ranvirpawar/liquid_snackbar/v0.1.2/doc/promotional/liquid-snackbar-promo-v1.png)

### Mobile-first app concept

![Mobile-first Liquid Snackbar promotional concept](https://raw.githubusercontent.com/ranvirpawar/liquid_snackbar/v0.1.2/doc/promotional/liquid-snackbar-mobile-v1.png)

*Promotional UI concept in a fictional iOS-style app. Runtime styling is unchanged.*

## Quick start: three steps

1. Add `liquid_snackbar: ^0.1.3` to your app's dependencies.
   For local evaluation use `path: ../liquid_snackbar`. Ensure your app has
   `uses-material-design: true` enabled under its `flutter:` section for Material status icons.
2. Add the preferred scoped host inside your app builder:

```dart
MaterialApp(
  builder: (context, child) => LiquidSnackbarHost(child: child!),
  home: const HomePage(),
);
```

3. Import and show from a descendant context:

```dart
import 'package:liquid_snackbar/liquid_snackbar.dart';

final handle = LiquidSnackbar.show(
  context,
  message: 'Changes saved',
  variant: LiquidSnackbarVariant.success,
);
await handle.closed;
```

A normal MaterialApp route context also works without installing a host.
That path uses the nearest Navigator overlay and an overlay-scoped default queue.
Avoid calling show during build; invoke it from user events or after the frame.

## Lifetime and queue API

`show` returns a `LiquidSnackbarHandle`: call `dismiss()` or await `closed`.
`closed` resolves once with a reason, including timeout, dismissal, action,
swipe, replacement, queue overflow, queue clearing and owner disposal.
Content updates and request priorities are intentionally not part of the 0.1.x API.

```dart
final controller = LiquidSnackbarController(
  config: const LiquidSnackbarConfig(
    maxVisible: 2,
    maxQueueLength: 10,
    suppressDuplicates: true,
    policy: LiquidSnackbarPolicy.queue,
  ),
);
// Supply controller to LiquidSnackbarHost(controller: controller, child: ...).
final handle = controller.show(const LiquidSnackbarRequest(message: 'Saved'));
controller.clearQueue();  // Waiting requests only; closed reason = cleared.
controller.dismissAll();  // Visible and waiting, immediately, without exit motion.
controller.dispose();     // Required for caller-owned controllers.
```

Capacity is shared across top and bottom. Waiting requests are FIFO and their
clock begins when displayed. A full queue rejects the newest request with
`queueFull`. `replace` closes the oldest visible card immediately. Duplicates
match title/message/variant/position/pill state or an explicit `duplicateKey`;
a duplicate returns the original handle, without running the suppressed
request's dismissal callback. Set `suppressDuplicates: false` to retain repeats.
Callbacks may enqueue new work; dismissAll operates on its initial snapshot.

A host owns its implicit controller. Caller-provided controllers are detached,
not disposed, when a host disappears, and can later attach to another host.
One controller can belong to only one host at a time. Operations after disposal
throw StateError; calling dispose or dismiss repeatedly is safe.

## Actions, variants and quick pills

```dart
LiquidSnackbar.show(
  context,
  title: 'Item removed',
  message: 'You can undo this operation.',
  variant: LiquidSnackbarVariant.warning,
  showCloseButton: true,
  showProgress: true,
  action: LiquidSnackbarAction(
    label: 'Undo',
    onPressed: () async { /* restore item */ },
    dismissOnAction: true,
  ),
);
LiquidSnackbar.show(context, message: 'Copied', quick: true);
LiquidSnackbar.show(
  context,
  message: 'Custom status',
  variant: LiquidSnackbarVariant.custom,
  customStyle: const LiquidSnackbarVariantStyle(
    color: Colors.purpleAccent, icon: Icons.star_outline,
  ),
);
```

Built-ins: success, error, warning, info, neutral. Status icons are distinct,
so color is not the only signal. Pills contain only a message: title, action
and close-button options are not combined with quick mode. Tap a plain card
or pill to close it. Persistent feedback uses `duration: null`.

Actions accept synchronous or asynchronous callbacks. Their timer pauses while
they execute; repeat activation is disabled. Callback errors go through
FlutterError.reportError, and cleanup/queue progression remains intact.
Dismiss-on-action applies on both success and failure; use false to keep the
notification while your callback presents recovery UI.

## Theming

```dart
ThemeData(
  extensions: [
    const LiquidSnackbarTheme().copyWith(
      blurSigma: 16,
      solid: false, // true: opaque fallback without backdrop compositing
      maxWidth: 480,
      radius: 18,
      alignment: AlignmentDirectional.centerEnd,
      animationDuration: const Duration(milliseconds: 240),
    ),
  ],
);
```

The extension configures surface color/opacity, tint opacity, blur, border,
card/pill radii, shadows, padding, outer margin, width, alignment, stack gap,
body/title/action typography, per-variant colors/icons and animation curve/time.
Use the ambient ThemeData for fonts. Defaults use restrained dark glass with
white text in light and dark apps, keeping contrast independent of app colors.
Custom translucent colors must be checked against your app's actual backdrops.
Place the theme above the host so live theme changes reach its overlay.

## Accessibility and localization

Live-region semantics announce caller-provided text once and retain separate
focusable action/close buttons with minimum 48dp targets. Dismiss labels default
to the app's MaterialLocalizations; all message/title/action text comes from you.
Supply LiquidSnackbarLabels at the host or per request, including an
`announcementBuilder`, for custom localized announcements. No English status
prefix is injected. RTL uses directional layout and padding.

Touch, hover, keyboard focus, app inactivity and pending async actions pause the
remaining visible duration independently. Escape dismisses while focus is inside
a card; notifications do not steal focus from the app. Tab reaches action/close
controls. Accessible-navigation mode disables automatic timeout entirely.
Reduced-motion mode removes blur and translation and uses a fade capped at 80ms.
Haptics default off; opt into light/byVariant via controller config.

Bottom notifications avoid the keyboard and safe area. Long content wraps and
the stack scrolls when vertical space is constrained. Keep messages concise.

## Optional context-free calls

Preferred: retain a controller and give it to LiquidSnackbarHost.
Alternatively supply your own key; the package never creates a global key:

```dart
final navigatorKey = GlobalKey<NavigatorState>();
final controller = LiquidSnackbarController(navigatorKey: navigatorKey);
// MaterialApp(navigatorKey: navigatorKey, ...)
// After the navigator is mounted:
controller.show(const LiquidSnackbarRequest(message: 'Ready'));
```

An `overlayKey: GlobalKey<OverlayState>()` or explicit
`controller.attach(overlay, context: context)` also works. A missing/unmounted
overlay throws a clear StateError rather than silently dropping notifications.

## How it differs

- [Toastification](https://pub.dev/packages/toastification) is a broader notification toolkit with extensive presentation options.
- [Another Flushbar](https://pub.dev/packages/another_flushbar) provides flexible notification bars and additional integrations.
- [Elegant Notification](https://pub.dev/packages/elegant_notification) offers stacked notifications, themes and animation controls.
- [Motion Toast](https://pub.dev/packages/motion_toast) emphasizes multiple animated toast designs.
- Liquid Snackbar focuses on one polished glass surface plus compact pills, with Flutter-only runtime dependencies.
- Its scope is explicit queue ownership, bounded scheduling, safe completion and accessible interaction rather than a large catalog of effects.
- These packages overlap; choose the one matching your visual design and maintenance needs.

## Platform status

Android, iOS, web and Windows are declared after successful verification.
Android APK, iOS simulator and Windows desktop builds pass in CI. The full
widget/logic suite also passes in Chrome, alongside web release compilation.
Flutter 3.41.6 / Dart 3.11.4 and Flutter 3.47.8 / Dart 3.13.7 are tested.
macOS and Linux native application builds are not claimed.
Physical-device accessibility and performance checks remain release follow-up.

## Example and verification

Run `cd example` then `flutter run`. The gallery includes every variant, both
positions, actions, queue limits, duplicate suppression, dark mode, custom theme,
solid fallback, reduced motion, progress, RTL and a keyboard test field.
See [VALIDATION.md](VALIDATION.md) for actual SDK/platform results and remaining
release checks. Platform claims reflect verified builds, not inferred portability.

## FAQ

**Does it require GetX, Provider or a special app class?** No.

**Can it send push or background notifications?** No; it renders in-app feedback.

**Why a dark surface in a light theme?** Predictable contrast over arbitrary app
content. Override the theme when your visual system calls for another treatment.

**Does clearQueue close the visible card?** No. Use dismissAll for both.

**Does it replace Material's SnackBar?** Only where you explicitly use this API.

**Can I publish this local checkout?** First review validation, the MIT license,
repository metadata and screenshots, then run the dry run yourself. This task
requires an authorized pub.dev account; CI performs dry runs only.

## License and source

MIT, copyright 2026 ranvirpawar.
[Repository](https://github.com/ranvirpawar/liquid_snackbar) ·
[Issues](https://github.com/ranvirpawar/liquid_snackbar/issues).