# Validation and publication checklist

No OMS app code was changed. Version 0.1.0 was published on 26 October 2026.
Version 0.1.1 updates artwork, README links and release metadata only; runtime
implementation and tests are unchanged. The public package is
https://pub.dev/packages/liquid_snackbar.

## Result

All required quality gates pass. The standalone package has only Flutter SDK
runtime dependencies. Android, iOS, web and Windows are declared based on
verified builds and browser/widget behavior; macOS and Linux native application
builds are not claimed.

[Successful CI run](https://github.com/ranvirpawar/liquid_snackbar/actions/runs/40286665535)
validated implementation commit `3de1c59`. The final follow-up changes only
documentation, the rendered preview and verified platform metadata; implementation
and tests are unchanged. Local gate output and downloaded CI logs are retained
in `.validation/` (excluded from Git and publication).

## SDK and quality-gate output

Minimum SDK: Flutter 3.41.6 / Dart 3.11.4.
Latest stable tested: Flutter 3.47.8 / Dart 3.13.7. This isolated SDK was downloaded
and its SHA-256 checked against the official release manifest. A separate source
snapshot was used for the final minimum check to avoid engine-cache interference.

Actual output excerpts:

```text
Minimum SDK (local and Linux CI):
flutter analyze: No issues found!
flutter test --coverage: +44: All tests passed!
lib/src line coverage: 504/519 (97.11%)
example/flutter test: +1: All tests passed!

Latest stable (local and Linux CI):
flutter analyze: No issues found!
dart format --set-exit-if-changed .: Formatted 12 files (0 changed)
flutter test --coverage: +44: All tests passed!
lib/src line coverage: 504/519 (97.11%)
example/flutter test: +1: All tests passed!
flutter test --platform chrome --reporter expanded: All tests passed!
example/flutter build web: Built build/web

Native CI builds:
Android: Built build/app/outputs/flutter-apk/app-debug.apk
iOS: Built build/ios/iphonesimulator/Runner.app
Windows: Built build/windows/x64/runner/Debug/liquid_snackbar_example.exe

Latest pana on Linux CI (0.23.19):
Points: 160/160.

dart pub publish --dry-run:
Package has 0 warnings.
```

Android debug APK builds also passed locally on both SDKs. Preserved local
artifacts are `.validation/app-minimum-debug.apk` and
`.validation/app-latest-debug.apk`. The latest APK SHA-256 is
`C86CD2FBFE7BE4EEA314FC22DF6E0EADC800F41B638C0EF4EFE5DC1C1F9A1107`.
The initial release was subsequently published and tagged v0.1.0.

## What the tests cover

FIFO queues, visibility and capacity limits, duplicate suppression, replacement,
handle completion, dismiss/dismissAll/clearQueue, callback errors and reentrant
disposal, independent pause states, async actions, directed swipes, keyboard
insets, host/overlay disposal, reduced motion, live semantics, localized labels,
48dp targets, default contrast, theme overrides/interpolation, RTL, narrow-screen
long stacks and all three setup paths. Coverage is source line coverage, not
branch coverage or a substitute for device testing.

The README preview is an actual Flutter render with SDK fonts, visually checked.
The gallery demonstrates every built-in/custom variant, both positions, actions,
queue limits, deduplication, progress, custom theme, dark mode, reduced motion,
solid fallback, RTL and keyboard avoidance.

## Local tool limitations and resolved workarounds

- The previous SDK lockfile permission issue was resolved by running Flutter with
  access to its installed SDK cache. No OMS SDK was replaced.
- Switching SDKs in the same build directory can cause
  `Runtime stages buffer failed verification` for cached shaders. `flutter clean`
  or an independent checkout resolves it; both final SDK suites pass.
- Windows Chrome test loaders stalled before execution in JS and WASM modes;
  an in-app browser also failed to attach. The same full suite passed in Chrome
  on Linux CI, so browser behavior is verified there.
- Windows lacked Visual Studio C++ tools and cannot build iOS. Native Windows
  and iOS simulator builds passed on their proper hosted CI toolchains.
- Pana 0.23.19 fails locally on Windows drive-letter paths with
  `Invalid argument (outputFolder): Sandbox output folder must not contain ":"`.
  Pana 0.23.16 with official WebP tools provides a local compatibility fallback
  (160/160). The authoritative current-pana result is 160/160 on Linux CI.
- The example's minimum-compatible Android scaffolding emits future-support
  warnings on latest Flutter for Gradle 8.14 / AGP 8.11.1 / Kotlin 2.2.20. These
  are not package analyzer issues; both native Android builds pass.

The initially rejected public push was explicitly approved and then completed.
Source, tests, example, screenshot and MIT license are available at
https://github.com/ranvirpawar/liquid_snackbar. CI has no publishing credentials
and performs only a publication dry run.

## Repeat the checks

```sh
flutter pub get
flutter analyze
dart format --set-exit-if-changed .
flutter test --coverage
dart run tool/check_coverage.dart
cd example
flutter test
flutter build apk --debug
flutter build web
cd ..
flutter test --platform chrome
dart pub publish --dry-run
dart pub global activate pana
dart pub global run pana --exit-code-threshold 20 .
```

Use Linux for latest pana; on Windows the documented older-pana fallback also
needs official WebP executables on PATH. Generate the preview with
`flutter test tool/capture_preview.dart`.

## Remaining release checks

- Select the Google/pub.dev account or verified publisher that will own it.
- Confirm name availability again immediately before the first upload.
- Review MIT attribution, repository/issue URLs, source and screenshot.
- Optionally replace the README GIF placeholder with a short recording.
- Test TalkBack/VoiceOver, haptics and blur performance on real Android/iOS devices.
- Check contrast if changing translucent colors or typography.
- Review the file list from a fresh zero-warning dry run.
- Tag each approved release commit with its matching version.
- Run `dart pub publish` only after explicit authorization.