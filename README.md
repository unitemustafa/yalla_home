# Yalla Home

Flutter courier app for managing Yalla Home delivery orders.

## Features

- Arabic-first delivery workflow.
- Active, delivered, notification, and profile tabs.
- Theme switching and offline connection status.

## Running

```powershell
flutter pub get
flutter run
```

## Checks

```powershell
flutter analyze
flutter test
```

## Authentication sessions

- `تذكرني` is off by default. Off creates a process-only mobile session with
  an absolute eight-hour backend deadline; Web uses `sessionStorage`.
- Enabling it persists the session and uses a seven-day inactivity window.
  A successful foreground token refresh starts a new seven-day window.
- Access tokens refresh automatically. The app does not refresh in the
  background solely to keep an unused session alive.
