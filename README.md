# hot_pepper_merchant

Merchant app for managing Hot Pepper booking orders.

## Getting Started

Run the local backend on port 3000, then start the Flutter app:

```sh
flutter pub get
flutter run -d chrome
```

The app reads the API from `http://localhost:3000/api` and realtime updates
from `ws://localhost:3000/ws` by default. To use another real backend, pass
`--dart-define`:

```sh
flutter run -d chrome \
  --dart-define=API_BASE_URL=https://YOUR_API_HOST/api \
  --dart-define=WS_BASE_URL=wss://YOUR_API_HOST/ws
```

Release builds use the same backend defines:

```sh
flutter build apk --release \
  --dart-define=API_BASE_URL=https://YOUR_API_HOST/api \
  --dart-define=WS_BASE_URL=wss://YOUR_API_HOST/ws

flutter build ios --release \
  --dart-define=API_BASE_URL=https://YOUR_API_HOST/api \
  --dart-define=WS_BASE_URL=wss://YOUR_API_HOST/ws
```
