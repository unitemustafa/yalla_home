# iOS release handoff

The repository-side iOS configuration is ready for CocoaPods, push
entitlements, background remote notifications, camera proof capture, and
Crashlytics. The remaining values are owned by Apple/Firebase accounts and
must not be invented locally.

On a Mac with Xcode:

1. Register `com.yallamarket.yallaHome` in the Apple Developer portal.
2. Add the Apple Development Team to the Runner target and keep automatic
   signing enabled.
3. Register the same iOS bundle ID in the existing Firebase project, download
   `GoogleService-Info.plist`, and add it to the Runner target. Run
   `flutterfire configure` against the existing Firebase project and verify
   that Crashlytics symbol upload is present in the Runner build phases.
4. Upload an APNs authentication key to Firebase Cloud Messaging.
5. Run `flutter pub get`, then `cd ios && pod install`.
6. Build and validate with
   `flutter build ipa --release --dart-define-from-file=env/production.json`.
7. Upload the archive to TestFlight and verify foreground, background, and
   terminated-state notifications on a physical iPhone.

The App Store archive must use `RunnerRelease.entitlements`; Debug and Profile
use `RunnerDebug.entitlements`.
