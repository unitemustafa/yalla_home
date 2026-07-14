# Yalla Home release checklist

## Automated gates

- `flutter analyze` completes with no diagnostics.
- `flutter test` passes.
- Android App Bundle builds with `env/production.json`.
- The release manifest blocks cleartext traffic and Android backup.
- Crashlytics receives a controlled non-fatal test from an internal build.

## Device matrix

- Android: one low-memory device, one current mid-range device, and Android 13+
  notification permission behavior.
- iPhone: compact 320/375-point width, current 393-point width, and a 430-point
  Pro Max width.
- Verify normal and larger accessibility text, RTL, dark mode, keyboard, safe
  areas, rotation lock, and slow/offline network behavior.

## Critical courier flows

- Login, remembered login, logout, expired token refresh, and transient network
  failure without an unintended logout.
- Assigned order appears once; pickup and delivery updates are not duplicated.
- Delivery works with no attachment, a note, and a camera proof image.
- Customer call and external map navigation work with coordinates and address
  fallback.
- Push notifications open the correct order in foreground, background, and
  terminated states; logout removes the device token.
- App resume and pull-to-refresh do not issue duplicate order/profile requests.

## Store rollout

- Complete the account-owned steps in `ios/README_RELEASE.md` on macOS/Xcode.
- Upload Android to an internal track and iOS to TestFlight first.
- Complete privacy disclosures for camera, notifications, crash reporting,
  authentication data, and any location/address data shown by the app.
- Monitor Crashlytics and API error/latency rates during a staged rollout before
  expanding availability.
