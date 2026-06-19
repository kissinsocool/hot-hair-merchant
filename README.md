# hot_pepper_merchant

Merchant app for managing Hot Pepper booking orders.

## Getting Started

Start the local mock API first:

```sh
node mock_api_server.mjs
```

Then run the Flutter app:

```sh
flutter pub get
flutter run -d chrome
```

The app reads orders from `http://localhost:3000/api` by default. To use a
different backend, pass `--dart-define`:

```sh
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000/api
```

Realtime booking updates are enabled by default and use
`ws://localhost:3000/ws`. Disable them only when running without a WebSocket
backend:

```sh
flutter run -d chrome --dart-define=ENABLE_REALTIME=false
```
