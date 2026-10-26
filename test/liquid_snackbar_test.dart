import 'dart:async';
import 'dart:ui' show PointerDeviceKind, SemanticsAction;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_snackbar/liquid_snackbar.dart';

Future<void> mount(
  WidgetTester tester,
  LiquidSnackbarController controller, {
  LiquidSnackbarTheme theme = const LiquidSnackbarTheme(),
  bool reduced = false,
  bool accessible = false,
  TextDirection direction = TextDirection.ltr,
  double keyboard = 0,
  double scale = 1,
  LiquidSnackbarLabels labels = const LiquidSnackbarLabels(),
  Widget? child,
  TargetPlatform platform = TargetPlatform.android,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: platform, extensions: [theme]),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: reduced,
          accessibleNavigation: accessible,
          viewInsets: EdgeInsets.only(bottom: keyboard),
          textScaler: TextScaler.linear(scale),
        ),
        child: Directionality(
          textDirection: direction,
          child: LiquidSnackbarHost(
            controller: controller,
            labels: labels,
            child: child!,
          ),
        ),
      ),
      home: Scaffold(body: child ?? const Center(child: Text('Page content'))),
    ),
  );
  await tester.pump();
}

LiquidSnackbarController owned({
  LiquidSnackbarConfig config = const LiquidSnackbarConfig(),
}) {
  final controller = LiquidSnackbarController(config: config);
  addTearDown(controller.dispose);
  return controller;
}

LiquidSnackbarRequest note(
  String text, {
  Duration? duration,
  LiquidSnackbarPosition position = LiquidSnackbarPosition.bottom,
  ValueChanged<LiquidSnackbarCloseReason>? onDismissed,
}) => LiquidSnackbarRequest(
  message: text,
  duration: duration,
  position: position,
  onDismissed: onDismissed,
);

Future<void> enter(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('FIFO and maxVisible share capacity across positions', (
    tester,
  ) async {
    final c = owned(config: const LiquidSnackbarConfig(maxVisible: 2));
    await mount(tester, c);
    final first = c.show(note('one'));
    c.show(note('two', position: LiquidSnackbarPosition.top));
    c.show(note('three'));
    c.show(note('four'));
    await enter(tester);
    expect(c.visibleCount, 2);
    expect(c.queuedCount, 2);
    expect(find.text('three'), findsNothing);
    final closing = first.dismiss();
    await tester.pumpAndSettle();
    await closing;
    expect(find.text('three'), findsOneWidget);
    expect(find.text('four'), findsNothing);
    expect(await first.closed, LiquidSnackbarCloseReason.dismissed);
  });

  testWidgets('queue overflow rejects newest and completes its handle once', (
    tester,
  ) async {
    final c = owned(config: const LiquidSnackbarConfig(maxQueueLength: 1));
    await mount(tester, c);
    c.show(note('visible'));
    c.show(note('waiting'));
    var called = 0;
    final rejected = c.show(note('rejected', onDismissed: (_) => called++));
    expect(await rejected.closed, LiquidSnackbarCloseReason.queueFull);
    await rejected.dismiss();
    expect(called, 1);
    expect(c.queuedCount, 1);
  });

  testWidgets('duplicate suppression covers visible and queued handles', (
    tester,
  ) async {
    final c = owned();
    await mount(tester, c);
    final a = c.show(note('one'));
    final b = c.show(note('two'));
    expect(identical(c.show(note('one')), a), isTrue);
    expect(identical(c.show(note('two')), b), isTrue);
    expect(c.queuedCount, 1);
    c.clearQueue();
    expect(await b.closed, LiquidSnackbarCloseReason.cleared);
    expect(identical(c.show(note('two')), b), isFalse);
  });

  testWidgets('custom duplicate keys and opt-out', (tester) async {
    final c = owned();
    await mount(tester, c);
    final a = c.show(
      const LiquidSnackbarRequest(
        message: 'one',
        duplicateKey: 'id',
        duration: null,
      ),
    );
    expect(
      identical(
        a,
        c.show(
          const LiquidSnackbarRequest(message: 'other', duplicateKey: 'id'),
        ),
      ),
      isTrue,
    );
    final other = owned(
      config: const LiquidSnackbarConfig(suppressDuplicates: false),
    );
    await mount(tester, other);
    expect(
      identical(other.show(note('same')), other.show(note('same'))),
      isFalse,
    );
  });

  testWidgets('replace closes oldest; queue length zero is valid', (
    tester,
  ) async {
    final c = owned(
      config: const LiquidSnackbarConfig(
        policy: LiquidSnackbarPolicy.replace,
        maxQueueLength: 0,
      ),
    );
    await mount(tester, c);
    final a = c.show(note('old'));
    await enter(tester);
    c.show(note('new'));
    await enter(tester);
    expect(await a.closed, LiquidSnackbarCloseReason.replaced);
    expect(find.text('old'), findsNothing);
    expect(find.text('new'), findsOneWidget);
    expect(c.queuedCount, 0);
  });

  testWidgets('queued and pre-mount dismiss are immediate and idempotent', (
    tester,
  ) async {
    final c = owned();
    await mount(tester, c);
    final a = c.show(note('first'));
    final b = c.show(note('queued'));
    await b.dismiss();
    await b.dismiss();
    await a.dismiss();
    expect(c.visibleCount, 0);
    expect(c.queuedCount, 0);
  });

  testWidgets(
    'dismissAll closes visible and waiting; controller remains reusable',
    (tester) async {
      final c = owned();
      await mount(tester, c);
      final a = c.show(note('one'));
      final b = c.show(note('two'));
      await enter(tester);
      c.dismissAll();
      await tester.pump();
      expect(await a.closed, LiquidSnackbarCloseReason.dismissed);
      expect(await b.closed, LiquidSnackbarCloseReason.dismissed);
      c.show(note('again'));
      await enter(tester);
      expect(find.text('again'), findsOneWidget);
    },
  );

  testWidgets('throwing dismissal callback cannot stall queue', (tester) async {
    final c = owned();
    await mount(tester, c);
    final a = c.show(
      note('one', onDismissed: (_) => throw StateError('callback')),
    );
    c.show(note('two'));
    await enter(tester);
    final closing = a.dismiss();
    await tester.pumpAndSettle();
    await closing;
    expect(tester.takeException(), isA<StateError>());
    expect(find.text('two'), findsOneWidget);
    expect(c.queuedCount, 0);
  });

  testWidgets('callbacks can enqueue during batch dismissal', (tester) async {
    final c = owned();
    await mount(tester, c);
    c.show(note('old', onDismissed: (_) => c.show(note('new'))));
    c.dismissAll();
    await enter(tester);
    expect(find.text('new'), findsOneWidget);
    expect(c.visibleCount, 1);
  });

  testWidgets('timeout starts on visibility, never while queued', (
    tester,
  ) async {
    final c = owned();
    await mount(tester, c);
    final a = c.show(note('first'));
    final b = c.show(note('second', duration: const Duration(seconds: 1)));
    await tester.pump(const Duration(seconds: 5));
    expect(b.isClosed, isFalse);
    c.dismissAll();
    await tester.pump();
    expect(a.isClosed, isTrue);
    final timed = c.show(note('timed', duration: const Duration(seconds: 1)));
    await enter(tester);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(await timed.closed, LiquidSnackbarCloseReason.timeout);
  });

  testWidgets('touch pauses remaining visible time and resumes on release', (
    tester,
  ) async {
    final c = owned();
    await mount(tester, c);
    final h = c.show(note('timer', duration: const Duration(seconds: 1)));
    await enter(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('timer')),
    );
    await tester.pump(const Duration(seconds: 3));
    expect(h.isClosed, isFalse);
    await gesture.moveBy(const Offset(1, 1));
    await gesture.cancel();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(await h.closed, LiquidSnackbarCloseReason.timeout);
  });

  testWidgets('hover pauses and resumes the timeout', (tester) async {
    final c = owned();
    await mount(tester, c);
    final h = c.show(note('hover', duration: const Duration(seconds: 1)));
    await enter(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('hover')));
    await tester.pump(const Duration(seconds: 3));
    expect(h.isClosed, isFalse);
    await mouse.moveTo(Offset.zero);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(await h.closed, LiquidSnackbarCloseReason.timeout);
    await mouse.removePointer();
  });

  testWidgets('focus pauses; Escape closes with the action focused', (
    tester,
  ) async {
    final c = owned();
    await mount(tester, c);
    final h = c.show(
      LiquidSnackbarRequest(
        message: 'focus',
        duration: const Duration(seconds: 1),
        action: LiquidSnackbarAction(label: 'Undo', onPressed: () {}),
      ),
    );
    await enter(tester);
    Focus.of(tester.element(find.text('Undo'))).requestFocus();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(h.isClosed, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(await h.closed, LiquidSnackbarCloseReason.dismissed);
  });

  testWidgets('background lifecycle pauses the timeout', (tester) async {
    final c = owned();
    await mount(tester, c);
    final h = c.show(note('background', duration: const Duration(seconds: 1)));
    await enter(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(seconds: 3));
    expect(h.isClosed, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(await h.closed, LiquidSnackbarCloseReason.timeout);
  });

  for (final position in LiquidSnackbarPosition.values) {
    testWidgets('swipe toward $position edge dismisses', (tester) async {
      final c = owned();
      await mount(tester, c);
      final h = c.show(note('swipe', position: position));
      await enter(tester);
      await tester.drag(
        find.text('swipe'),
        Offset(0, position == LiquidSnackbarPosition.top ? -130 : 130),
      );
      await tester.pumpAndSettle();
      expect(await h.closed, LiquidSnackbarCloseReason.swipe);
    });
    testWidgets('swipe away from $position edge snaps back', (tester) async {
      final c = owned();
      await mount(tester, c);
      final h = c.show(note('stay', position: position));
      await enter(tester);
      await tester.drag(
        find.text('stay'),
        Offset(0, position == LiquidSnackbarPosition.top ? 40 : -40),
      );
      await tester.pumpAndSettle();
      expect(h.isClosed, isFalse);
    });
  }

  testWidgets('bottom stays above keyboard and top stays below safe area', (
    tester,
  ) async {
    final c = owned(config: const LiquidSnackbarConfig(maxVisible: 2));
    await mount(tester, c, keyboard: 240);
    c.show(note('bottom'));
    c.show(note('top', position: LiquidSnackbarPosition.top));
    await enter(tester);
    expect(tester.getBottomLeft(find.text('bottom')).dy, lessThan(360));
    expect(tester.getTopLeft(find.text('top')).dy, greaterThanOrEqualTo(16));
    expect(tester.takeException(), isNull);
  });

  testWidgets('keyboard opening while visible repositions content', (
    tester,
  ) async {
    final c = owned();
    await mount(tester, c);
    c.show(note('moving'));
    await enter(tester);
    final before = tester.getTopLeft(find.text('moving')).dy;
    await mount(tester, c, keyboard: 250);
    await tester.pump();
    expect(tester.getTopLeft(find.text('moving')).dy, lessThan(before - 200));
  });

  testWidgets('host disposal completes waiting and visible handles', (
    tester,
  ) async {
    final c = owned();
    await mount(tester, c);
    final a = c.show(note('visible'));
    final b = c.show(note('queued'));
    await enter(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(await a.closed, LiquidSnackbarCloseReason.disposed);
    expect(await b.closed, LiquidSnackbarCloseReason.disposed);
    expect(c.isDisposed, isFalse);
    await mount(tester, c);
    c.show(note('reattached'));
    await enter(tester);
    expect(find.text('reattached'), findsOneWidget);
  });

  testWidgets('dispose during exit and before first frame is safe', (
    tester,
  ) async {
    final c = owned();
    await mount(tester, c);
    final h = c.show(note('first'));
    await enter(tester);
    final closing = h.dismiss();
    c.dispose();
    c.dispose();
    await tester.pumpWidget(const SizedBox());
    await closing;
    expect(await h.closed, LiquidSnackbarCloseReason.disposed);
    expect(() => c.show(note('invalid')), throwsStateError);
    expect(tester.takeException(), isNull);
    final d = owned();
    await mount(tester, d);
    final unseen = d.show(note('never mounted'));
    d.dispose();
    await tester.pump();
    expect(await unseen.closed, LiquidSnackbarCloseReason.disposed);
  });

  testWidgets('reduced motion disables blur and uses a short fade', (
    tester,
  ) async {
    final c = owned();
    await mount(tester, c, reduced: true);
    final h = c.show(note('reduced'));
    await tester.pump();
    expect(
      tester.widget<BackdropFilter>(find.byType(BackdropFilter)).enabled,
      isFalse,
    );
    await tester.pump(const Duration(milliseconds: 90));
    final closing = h.dismiss();
    await tester.pumpAndSettle();
    await closing;
    expect(h.isClosed, isTrue);
  });

  testWidgets('accessible navigation keeps timed feedback until dismissed', (
    tester,
  ) async {
    final c = owned();
    await mount(tester, c, accessible: true);
    final h = c.show(
      const LiquidSnackbarRequest(message: 'accessible', showProgress: true),
    );
    await enter(tester);
    await tester.pump(const Duration(seconds: 30));
    expect(h.isClosed, isFalse);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('semantics announce once and retain localized button roles', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    final c = owned();
    await mount(
      tester,
      c,
      labels: const LiquidSnackbarLabels(dismissLabel: 'Fermer'),
    );
    c.show(
      LiquidSnackbarRequest(
        message: 'Saved',
        title: 'Complete',
        showCloseButton: true,
        duration: null,
        labels: LiquidSnackbarLabels(
          dismissLabel: 'Cerrar',
          announcementBuilder: (r) => 'Aviso: ${r.message}',
        ),
        action: LiquidSnackbarAction(label: 'Undo', onPressed: () {}),
      ),
    );
    await enter(tester);
    expect(find.bySemanticsLabel('Aviso: Saved'), findsOneWidget);
    expect(find.byTooltip('Cerrar'), findsOneWidget);
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Undo'))
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isTrue,
    );
    expect(
      tester.getSize(find.byType(IconButton)).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.byType(TextButton)).height,
      greaterThanOrEqualTo(48),
    );
    semantics.dispose();
    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();
    expect(c.visibleCount, 0);
  });

  testWidgets('action exceptions report errors and still advance queue', (
    tester,
  ) async {
    final c = owned();
    await mount(tester, c);
    final h = c.show(
      LiquidSnackbarRequest(
        message: 'action',
        duration: null,
        action: LiquidSnackbarAction(
          label: 'Fail',
          onPressed: () async => throw StateError('action failure'),
        ),
      ),
    );
    c.show(note('next'));
    await enter(tester);
    await tester.tap(find.text('Fail'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isA<StateError>());
    expect(await h.closed, LiquidSnackbarCloseReason.action);
    expect(find.text('next'), findsOneWidget);
  });

  testWidgets(
    'async action pauses timeout, blocks duplicates, and may persist',
    (tester) async {
      final c = owned();
      await mount(tester, c);
      final done = Completer<void>();
      var count = 0;
      final h = c.show(
        LiquidSnackbarRequest(
          message: 'async',
          duration: const Duration(seconds: 1),
          action: LiquidSnackbarAction(
            label: 'Run',
            dismissOnAction: false,
            onPressed: () {
              count++;
              return done.future;
            },
          ),
        ),
      );
      await enter(tester);
      await tester.tap(find.text('Run'));
      await tester.pump();
      await tester.tap(find.text('Run'));
      await tester.pump(const Duration(seconds: 3));
      expect(count, 1);
      expect(h.isClosed, isFalse);
      done.complete();
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(h.isClosed, isTrue);
    },
  );

  testWidgets('async action completing after disposal is harmless', (
    tester,
  ) async {
    final c = owned();
    await mount(tester, c);
    final done = Completer<void>();
    c.show(
      LiquidSnackbarRequest(
        message: 'pending',
        duration: null,
        action: LiquidSnackbarAction(
          label: 'Wait',
          onPressed: () => done.future,
        ),
      ),
    );
    await enter(tester);
    await tester.tap(find.text('Wait'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    done.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('quick pill is compact, tappable and theme configurable', (
    tester,
  ) async {
    final c = owned();
    await mount(
      tester,
      c,
      theme: const LiquidSnackbarTheme(solid: true, maxWidth: 300),
    );
    final h = c.show(
      const LiquidSnackbarRequest(
        message: 'Copied',
        quick: true,
        duration: null,
      ),
    );
    await enter(tester);
    expect(find.byIcon(Icons.notifications_none_rounded), findsNothing);
    expect(
      tester.widget<BackdropFilter>(find.byType(BackdropFilter)).enabled,
      isFalse,
    );
    expect(tester.getSize(find.byType(Material).last).width, lessThan(300));
    await tester.tap(find.text('Copied'));
    await tester.pumpAndSettle();
    expect(await h.closed, LiquidSnackbarCloseReason.dismissed);
  });

  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.windows,
  ]) {
    testWidgets('large text and RTL layout on $platform', (tester) async {
      final c = owned();
      await mount(
        tester,
        c,
        direction: TextDirection.rtl,
        scale: 2.5,
        platform: platform,
      );
      c.show(
        LiquidSnackbarRequest(
          message:
              'Long notification message that wraps across multiple lines safely.',
          title: 'Heading',
          duration: null,
          showCloseButton: true,
          action: LiquidSnackbarAction(
            label: 'A long localized action',
            onPressed: () {},
          ),
        ),
      );
      await enter(tester);
      expect(tester.takeException(), isNull);
      expect(
        tester.getCenter(find.byIcon(Icons.close_rounded)).dx,
        lessThan(tester.getCenter(find.text('Heading')).dx),
      );
    });
  }

  testWidgets('theme override and custom variant are applied', (tester) async {
    final c = owned();
    await mount(
      tester,
      c,
      theme: const LiquidSnackbarTheme(
        solid: true,
        radius: 8,
        maxWidth: 320,
        messageStyle: TextStyle(color: Colors.yellow, fontSize: 19),
      ),
    );
    c.show(
      const LiquidSnackbarRequest(
        message: 'custom',
        variant: LiquidSnackbarVariant.custom,
        duration: null,
        customStyle: LiquidSnackbarVariantStyle(
          color: Colors.pink,
          icon: Icons.star,
        ),
      ),
    );
    await enter(tester);
    expect(find.byIcon(Icons.star), findsOneWidget);
    expect(tester.widget<Text>(find.text('custom')).style!.fontSize, 19);
    expect(
      tester.getSize(find.byType(BackdropFilter)).width,
      lessThanOrEqualTo(320),
    );
  });

  test('theme copyWith and interpolation cover all configurable tokens', () {
    const base = LiquidSnackbarTheme();
    final changed = base.copyWith(
      blurSigma: 0,
      solid: true,
      surfaceColor: Colors.blue,
      surfaceOpacity: .9,
      tintOpacity: .1,
      border: BorderSide.none,
      radius: 8,
      pillRadius: 30,
      shadows: [],
      padding: EdgeInsets.zero,
      margin: EdgeInsets.zero,
      maxWidth: 400,
      alignment: AlignmentDirectional.centerEnd,
      gap: 12,
      messageStyle: const TextStyle(fontSize: 18),
      titleStyle: const TextStyle(fontSize: 20),
      actionStyle: const TextStyle(fontSize: 15),
      animationDuration: const Duration(milliseconds: 100),
      animationCurve: Curves.linear,
      variantStyles: const {},
    );
    final mid = base.lerp(changed, .5);
    expect(mid.maxWidth, 460);
    expect(mid.radius, 14);
    expect(mid.solid, isTrue);
    expect(base.lerp(null, .5), same(base));
    expect(base.lerp(changed, 0).maxWidth, base.maxWidth);
    expect(base.lerp(changed, 1).maxWidth, changed.maxWidth);
    expect(base.copyWith().maxWidth, base.maxWidth);
  });

  testWidgets('context API works without host and scopes control to overlay', (
    tester,
  ) async {
    late BuildContext page;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            page = context;
            return const Scaffold(body: Text('page'));
          },
        ),
      ),
    );
    final h = LiquidSnackbar.show(
      page,
      message: 'direct',
      title: 'Title',
      variant: LiquidSnackbarVariant.success,
      position: LiquidSnackbarPosition.top,
      duration: null,
      showCloseButton: true,
      showProgress: true,
      duplicateKey: 'direct',
      labels: const LiquidSnackbarLabels(dismissLabel: 'Close'),
    );
    LiquidSnackbar.show(page, message: 'queued', duration: null);
    await enter(tester);
    expect(find.text('direct'), findsOneWidget);
    LiquidSnackbar.clearQueue(page);
    LiquidSnackbar.dismissAll(page);
    await tester.pump();
    expect(await h.closed, LiquidSnackbarCloseReason.dismissed);
    final lost = LiquidSnackbar.show(page, message: 'lost', duration: null);
    await enter(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(await lost.closed, LiquidSnackbarCloseReason.disposed);
  });

  testWidgets('context API reports missing overlay clearly', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      Builder(
        builder: (value) {
          context = value;
          return const SizedBox();
        },
      ),
    );
    expect(
      () => LiquidSnackbar.show(context, message: 'missing'),
      throwsFlutterError,
    );
  });

  testWidgets('owned host controller is disposed with the host', (
    tester,
  ) async {
    late LiquidSnackbarController c;
    await tester.pumpWidget(
      MaterialApp(
        home: LiquidSnackbarHost(
          child: Builder(
            builder: (context) {
              c = LiquidSnackbar.of(context);
              return const Scaffold();
            },
          ),
        ),
      ),
    );
    await tester.pump();
    final h = c.show(note('owned'));
    await enter(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(c.isDisposed, isTrue);
    expect(await h.closed, LiquidSnackbarCloseReason.disposed);
  });

  testWidgets('navigator key and overlay key setups are opt-in', (
    tester,
  ) async {
    final key = GlobalKey<NavigatorState>();
    final c = LiquidSnackbarController(navigatorKey: key);
    addTearDown(c.dispose);
    expect(() => c.show(note('too early')), throwsStateError);
    await tester.pumpWidget(
      MaterialApp(navigatorKey: key, home: const Scaffold()),
    );
    c.show(note('keyed'));
    await enter(tester);
    expect(find.text('keyed'), findsOneWidget);
    c.dismissAll();
    await tester.pump();
    final overlayKey = GlobalKey<OverlayState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Overlay(
          key: overlayKey,
          initialEntries: [OverlayEntry(builder: (_) => const SizedBox())],
        ),
      ),
    );
    final d = LiquidSnackbarController(overlayKey: overlayKey);
    addTearDown(d.dispose);
    d.show(note('overlay key'));
    await enter(tester);
    expect(find.text('overlay key'), findsOneWidget);
  });

  testWidgets('haptics are opt-in and safe when no platform plugin exists', (
    tester,
  ) async {
    final methods = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        methods.add(call.method);
        if (call.method == 'HapticFeedback.vibrate') {
          throw MissingPluginException();
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    for (final mode in [
      LiquidSnackbarHaptics.light,
      LiquidSnackbarHaptics.byVariant,
    ]) {
      final c = owned(config: LiquidSnackbarConfig(haptics: mode));
      await mount(tester, c);
      c.show(
        const LiquidSnackbarRequest(
          message: 'haptic',
          variant: LiquidSnackbarVariant.error,
          duration: null,
        ),
      );
      await enter(tester);
      c.dismissAll();
      await tester.pump();
    }
    expect(
      methods.where((method) => method == 'HapticFeedback.vibrate').length,
      2,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid duration is rejected even outside assertion builds', (
    tester,
  ) async {
    final c = owned();
    await mount(tester, c);
    expect(
      () => c.show(
        const LiquidSnackbarRequest(
          message: 'invalid',
          duration: Duration.zero,
        ),
      ),
      throwsArgumentError,
    );
  });
}
