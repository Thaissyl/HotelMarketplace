# Hotel Marketplace Mobile

Flutter mobile client for the Hotel Marketplace Management System.

## Stack

- Flutter and Dart
- Riverpod for application-wide dependency injection and state management
- GoRouter for centralized navigation
- Dio for HTTP networking
- Flutter Secure Storage for sensitive session data

## Local API Configuration

The app resolves the API base URL from Dart compile-time defines.

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5080
```

Default development URLs:

- Android Emulator: `http://10.0.2.2:5080`
- iOS Simulator: `http://localhost:5080`
- Desktop: `http://localhost:5080`

For a physical device, run the backend on a reachable LAN address and pass:

```powershell
flutter run --dart-define=API_BASE_URL=http://YOUR_LAN_IP:5080
```

## Current Scope

This stage contains the base mobile infrastructure only:

- Environment configuration
- Shared Dio API client
- JWT and hotel-scope request interceptors
- Centralized API exception mapping
- Secure local session storage
- Router initialization
- API health check screen
