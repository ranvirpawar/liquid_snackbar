import 'package:flutter/material.dart';
import 'package:liquid_snackbar/liquid_snackbar.dart';

void main() => runApp(const SnackbarExample());

/// Interactive package gallery with independent, scoped notifications.
class SnackbarExample extends StatefulWidget {
  /// Creates the runnable example.
  const SnackbarExample({super.key});
  @override
  State<SnackbarExample> createState() => _SnackbarExampleState();
}

class _SnackbarExampleState extends State<SnackbarExample> {
  final _controller = LiquidSnackbarController(
    config: const LiquidSnackbarConfig(maxVisible: 2, maxQueueLength: 5),
  );
  bool _dark = false;
  bool _reduced = false;
  bool _solid = false;
  bool _rtl = false;
  bool _top = false;
  bool _progress = true;
  bool _customTheme = false;
  String _status = 'Ready';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  LiquidSnackbarTheme get _theme => const LiquidSnackbarTheme().copyWith(
    solid: _solid,
    radius: _customTheme ? 10 : 20,
    maxWidth: _customTheme ? 400 : 520,
    border: _customTheme ? const BorderSide(color: Color(0xFF91C8FF)) : null,
  );

  void _show({
    LiquidSnackbarVariant variant = LiquidSnackbarVariant.neutral,
    bool quick = false,
    bool action = false,
    String? message,
  }) {
    final text =
        message ??
        (quick
            ? 'Copied to clipboard'
            : 'Your changes have been saved safely.');
    _controller.show(
      LiquidSnackbarRequest(
        message: text,
        title: quick ? null : variant.name.toUpperCase(),
        variant: variant,
        customStyle: variant == LiquidSnackbarVariant.custom
            ? const LiquidSnackbarVariantStyle(
                color: Color(0xFFDFC3FF),
                icon: Icons.auto_awesome_outlined,
              )
            : null,
        quick: quick,
        position: _top
            ? LiquidSnackbarPosition.top
            : LiquidSnackbarPosition.bottom,
        showCloseButton: !quick,
        showProgress: _progress,
        action: action
            ? LiquidSnackbarAction(
                label: 'Undo',
                onPressed: () {
                  setState(() => _status = 'Undo completed');
                },
              )
            : null,
        onDismissed: (reason) {
          if (mounted) setState(() => _status = 'Closed: ${reason.name}');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Liquid Snackbar',
    themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
    theme: ThemeData(
      colorSchemeSeed: const Color(0xFF3259A8),
      useMaterial3: true,
      extensions: [_theme],
    ),
    darkTheme: ThemeData(
      colorSchemeSeed: const Color(0xFF91C8FF),
      brightness: Brightness.dark,
      useMaterial3: true,
      extensions: [_theme],
    ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: _reduced),
      child: Directionality(
        textDirection: _rtl ? TextDirection.rtl : TextDirection.ltr,
        child: LiquidSnackbarHost(controller: _controller, child: child!),
      ),
    ),
    home: Scaffold(
      appBar: AppBar(
        title: const Text('Liquid Snackbar'),
        actions: [
          IconButton(
            tooltip: 'Toggle dark mode',
            onPressed: () => setState(() => _dark = !_dark),
            icon: Icon(
              _dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Clear feedback. A little depth.',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              const Text(
                'Glass notifications with bounded queues, accessible actions and an explicit owner. Try a notification, then explore the controls.',
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final variant in LiquidSnackbarVariant.values)
                    FilledButton.tonal(
                      onPressed: () => _show(variant: variant),
                      child: Text(variant.name),
                    ),
                  FilledButton(
                    onPressed: () => _show(quick: true),
                    child: const Text('Quick pill'),
                  ),
                  OutlinedButton(
                    onPressed: () => _show(action: true),
                    child: const Text('With action'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(),
              const Text(
                'Behavior',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show at the top'),
                value: _top,
                onChanged: (v) => setState(() => _top = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Timer progress'),
                value: _progress,
                onChanged: (v) => setState(() => _progress = v),
              ),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      for (var i = 1; i <= 8; i++) {
                        _show(message: 'Queued message $i');
                      }
                    },
                    child: const Text('Queue 8 messages'),
                  ),
                  OutlinedButton(
                    onPressed: _controller.clearQueue,
                    child: const Text('Clear queue'),
                  ),
                  OutlinedButton(
                    onPressed: _controller.dismissAll,
                    child: const Text('Dismiss all'),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      _show(message: 'Same message');
                      _show(message: 'Same message');
                    },
                    child: const Text('Duplicate suppression'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(),
              const Text(
                'Appearance & accessibility',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Solid surface (no blur)'),
                value: _solid,
                onChanged: (v) => setState(() => _solid = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Custom theme'),
                value: _customTheme,
                onChanged: (v) => setState(() => _customTheme = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Reduced motion'),
                value: _reduced,
                onChanged: (v) => setState(() => _reduced = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Right-to-left layout'),
                value: _rtl,
                onChanged: (v) => setState(() => _rtl = v),
              ),
              const SizedBox(height: 12),
              const TextField(
                decoration: InputDecoration(
                  labelText: 'Open the keyboard to test avoidance',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              Text(_status),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    ),
  );
}
