import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_snackbar_example/main.dart';

void main() {
  testWidgets('gallery shows a real success notification and switches themes', (
    tester,
  ) async {
    await tester.pumpWidget(const SnackbarExample());
    await tester.tap(find.text('success'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Your changes have been saved safely.'), findsOneWidget);
    await tester.tap(find.byTooltip('Toggle dark mode'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.light_mode_outlined), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
