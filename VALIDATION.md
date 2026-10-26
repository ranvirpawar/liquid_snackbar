# Validation and publication checklist

No OMS app code was changed. No pub.dev version has been uploaded.

## Package and SDK results

The minimum is Flutter 3.41.6 / Dart 3.11.4. Latest stable verified here is
Flutter 3.47.8 / Dart 3.13.7, downloaded separately with its SHA-256 checked
against the official release manifest. The final minimum check used a separate
source snapshot to avoid reusing engine-specific build caches across SDKs.

Actual command excerpts:

```text
Minimum Flutter 3.41.6:
flutter analyze: No issues found!
flutter test --coverage: +44: All tests passed!
lib/src line coverage: 504/519 (97.11%)
example/flutter test: +1: All tests passed!
flutter build apk --debug: Built build\app\outputs\flutter-apk\app-debug.apk

Latest Flutter 3.47.8:
flutter analyze: No issues found!
dart format --set-exit-if-changed .: Formatted 12 files (0 changed)
flutter test --coverage: +44: All tests passed!
lib/src line coverage: 504/519 (97.11%)
example/flutter build web: Built build\web

Publication rehearsal:
dart pub publish --dry-run: Package has 0 warnings.
Total compressed archive size: 151 KB (before final report updates).

Pana compatibility fallback 0.23.16, using Flutter 3.47.8:
Points: 160/160.
```

The minimum APK is preserved locally at .validation/app-minimum-debug.apk;
this and validation logs are excluded from Git/pub. A final latest-stable APK
build and example test are still running at the time of this report revision.
Android scaffolding emits future-support warnings for its minimum-compatible
Gradle 8.14 / AGP 8.11.1 / Kotlin 2.2.20 versions on latest Flutter. The package
itself has zero third-party runtime dependencies.

The real preview was rendered with Flutter SDK fonts and visually inspected.
The unit/widget suite covers queues/limits/replacement/deduplication, callback
exceptions and reentrancy, timer pause/resume, actions, swipe direction, keyboard
insets, disposal, reduced motion, semantics, contrast, theming, RTL, narrow-screen
long stacks, and context/host/keyed setup. Coverage is source line coverage,
not branch coverage or a substitute for real assistive-technology testing.

## Remaining platform/tool limitations

- Native iOS: requires macOS/Xcode; no native build result on this Windows PC.
- Windows native: attempted; Flutter reports "Unable to find suitable Visual Studio toolchain."
- Web: release and WASM dry-run compilation succeed. Automated Chrome tests compile
  but stall before running tests in both JS and WASM modes. A direct demo browser
  check was also blocked by an in-app webview attach timeout. Browser runtime
  behavior is not claimed verified.
- Pana 0.23.19: fails on this Windows host with
  `Invalid argument (outputFolder): Sandbox output folder must not contain ":"`.
  The installed 0.23.16 fallback predates that Windows path regression and returns
  160/160 with official WebP tools on PATH. This is not a latest-pana score.
  The workflow includes a latest-pana check on Linux.
- Pana's inferred platform/wasm portability tags are static analysis; only Android
  is declared in pubspec until the missing platform checks actually pass.
- TalkBack/VoiceOver, a physical keyboard on device, and blur performance on
  lower-end phones still require device verification.

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
dart pub global run pana .
```

For the documented Windows workaround, activate pana 0.23.16 and put official
WebP binaries on PATH. Run latest pana on Linux CI for the final release score.
Switching SDKs requires flutter clean or an independent checkout before tests;
otherwise cached shaders can fail with "Runtime stages buffer failed verification."
The previous SDK lockfile error is resolved by granting execution access to the
SDK cache; no OMS SDK was replaced. Generate the preview with
flutter test tool/capture_preview.dart.

## GitHub and publication

The empty repository exists at https://github.com/ranvirpawar/liquid_snackbar.
Automatic approval review rejected the public push because repository creation
alone did not authorize disclosing the extracted OMS-derived payload. The source
remains local until explicit approval. Prepared iOS, Android, Windows, web and
SDK CI jobs cannot run until that push is approved. No release tag was created.

Before actual pub.dev publication:

- Select the Google/pub.dev account or verified publisher that will own it.
- Confirm name availability again immediately before the first upload.
- Review MIT attribution, repository/issue URLs, source and screenshot.
- Optionally replace the README GIF placeholder with a short recording.
- Require green native/browser CI and update platform declarations accordingly.
- Review the complete archive list from a fresh zero-warning dry run.
- Tag the approved commit v0.1.0.
- Run dart pub publish only after explicit authorization.