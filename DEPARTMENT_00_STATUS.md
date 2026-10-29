# Department 00 — Production Office (implementation status)

Implemented source:
- `android/lib/production_office.dart`: local intake, private project copy, SHA-256, atomic JSON manifests, persisted status, independently re-read review, revalidation on handoff.
- `android/android/app/src/main/kotlin/co/parikshit/otakudub/MainActivity.kt`: Android MediaExtractor + MediaMetadataRetriever track/duration/resolution inspection.
- `android/lib/main.dart`: Studio import, Hindi/English target selection, Projects records, detailed raw evidence in Departments.
- `android/test/production_office_test.dart`: fixture-level valid, missing audio, changed source, empty source and language checks.

A deterministic controller is appropriate: generative AI is neither necessary nor trusted for file validation. Department 01 must demand a fresh `canHandoff` approval; a manifest status alone is insufficient.

## Not yet certified
No Flutter/Android SDK is installed in the available execution environment. The previous destructive branch reset also removed the Android Gradle/settings/wrapper infrastructure. The code and tests have been committed but not compiled or executed. Restore standard Flutter Android scaffold (preserving package name, signature configuration and launcher assets), run `flutter pub get`, `flutter analyze`, `flutter test`, then release build and real-device integration tests before calling this department approved. Source metadata examination is native Android, not FFprobe, and the current manifest is JSON rather than Room/SQLite. Large media, low storage, interrupted copy, malformed containers and simultaneous imports need instrumented stress testing. Other departments remain unimplemented.

Do not mistake project intake approval for department implementation certification or a completed dub.

## Verification automation added
`.github/workflows/department-00.yml` restores missing standard Flutter Android scaffolding in the CI workspace while preserving the app's source files, runs `flutter pub get`, `flutter analyze`, `flutter test`, and builds a debug APK, publishing it as a run artifact. This workflow is triggered by pushes to this branch. A workflow definition or push does not prove a passing run. Review its actual logs and artifact before certification. An on-device test remains required for long media, interruption, low storage, codec variability, and native MethodChannel behavior.
