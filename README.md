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

### Merchant Web release check

Before publishing the merchant portal, run `scripts/check_merchant_web.sh`.
It runs static analysis, unit and widget tests, browser tests for Web-only code,
a Chrome integration test of the real shop editor at phone width, and the
merchant Web build. The integration test uses an in-memory repository and does
not write to the production API.

Install a ChromeDriver version matching the installed Chrome version, then run:

```sh
npx @puppeteer/browsers install chromedriver@stable --path /tmp/merchant-chromedriver
CHROMEDRIVER_BIN=/path/printed/by/the/install/command/chromedriver \
  ./scripts/check_merchant_web.sh
```

After the automated check, verify text selection and the keyboard in Safari on
an iPhone before publishing changes to native text inputs. Chrome's phone-width
test checks layout and editing but does not emulate iOS text selection.
