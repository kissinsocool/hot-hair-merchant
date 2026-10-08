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

## Web portals

The merchant and admin portals have separate entry points and output directories:

```sh
flutter build web --base-href "/merchant-app/" --output build/merchant-web
flutter build web --base-href "/admin-app/" --target lib/main_admin.dart --output build/admin-web
```

Publish the build directories to `/merchant-app/` and `/admin-app/` on the same
origin. Both portals use the same backend endpoints and separate browser
sessions.
