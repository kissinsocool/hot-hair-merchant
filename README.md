# hot_pepper_merchant

Merchant app for managing Hot Pepper booking orders.

## Getting Started

The app uses `https://api.hothaircc.cn/api` and realtime updates from
`wss://api.hothaircc.cn/ws` by default:

```sh
flutter pub get
flutter run -d chrome
```

To use a local or different backend, pass `--dart-define`:

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
