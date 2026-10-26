import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_snackbar/liquid_snackbar.dart';

void main() {
  testWidgets('capture actual rendered package preview', (tester) async {
    await tester.binding.setSurfaceSize(const Size(720, 960));
    await tester.runAsync(() async {
      final configUri = File('.dart_tool/package_config.json').absolute.uri;
      final config =
          jsonDecode(File.fromUri(configUri).readAsStringSync())
              as Map<String, dynamic>;
      final packages = config['packages'] as List<dynamic>;
      final flutter = packages.cast<Map<String, dynamic>>().firstWhere(
        (p) => p['name'] == 'flutter',
      );
      final sdk = Directory.fromUri(
        configUri.resolve(flutter['rootUri'] as String),
      ).parent.parent;
      for (final spec in {
        'Roboto': ['roboto-regular.ttf', 'roboto-bold.ttf'],
        'MaterialIcons': ['materialicons-regular.otf'],
      }.entries) {
        final loader = FontLoader(spec.key);
        for (final file in spec.value) {
          final data = await File(
            '${sdk.path}/bin/cache/artifacts/material_fonts/$file',
          ).readAsBytes();
          loader.addFont(Future.value(ByteData.sublistView(data)));
        }
        await loader.load();
      }
    });
    final boundary = GlobalKey();
    final controller = LiquidSnackbarController(
      config: const LiquidSnackbarConfig(maxVisible: 5),
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            fontFamily: 'Roboto',
            colorSchemeSeed: const Color(0xFF3259A8),
          ),
          builder: (context, child) =>
              LiquidSnackbarHost(controller: controller, child: child!),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 300),
                  const Text(
                    'Liquid Snackbar',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Clear feedback. A little depth.',
                    style: TextStyle(fontSize: 20),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    children: [
                      for (final color in [
                        const Color(0xFFCDE2F7),
                        const Color(0xFFD5EADB),
                        const Color(0xFFE7DDF7),
                      ])
                        Container(
                          width: 180,
                          height: 110,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Flutter only. Scoped queues. Accessible interaction.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    controller.show(
      const LiquidSnackbarRequest(
        title: 'Changes saved',
        message: 'Everything is up to date.',
        variant: LiquidSnackbarVariant.success,
        position: LiquidSnackbarPosition.top,
        showCloseButton: true,
        duration: null,
      ),
    );
    controller.show(
      LiquidSnackbarRequest(
        title: 'Item removed',
        message: 'You can restore it with one action.',
        variant: LiquidSnackbarVariant.warning,
        position: LiquidSnackbarPosition.top,
        duration: null,
        action: LiquidSnackbarAction(label: 'Undo', onPressed: () {}),
      ),
    );
    controller.show(
      const LiquidSnackbarRequest(
        message: 'Copied to clipboard',
        quick: true,
        duration: null,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await render.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        'doc/screenshots/glass.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    controller.dispose();
    await tester.pumpWidget(const SizedBox());
    await tester.binding.setSurfaceSize(null);
  });
}
