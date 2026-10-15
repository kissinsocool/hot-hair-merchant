#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

CHROMEDRIVER_BIN="${CHROMEDRIVER_BIN:-$(command -v chromedriver || true)}"
if [[ -z "$CHROMEDRIVER_BIN" || ! -x "$CHROMEDRIVER_BIN" ]]; then
  echo 'Set CHROMEDRIVER_BIN to a ChromeDriver executable matching the installed Chrome version.' >&2
  exit 1
fi

flutter pub get
flutter analyze --no-pub
flutter test --no-pub
flutter test --no-pub --platform chrome \
  test/native_multiline_text_field_web_test.dart \
  test/portal_session_store_web_test.dart \
  test/image_upload_picker_web_test.dart
node --test test/ios_pointer_recovery_test.js

if curl --silent --fail http://127.0.0.1:4444/status >/dev/null; then
  echo 'Port 4444 is already in use by another ChromeDriver.' >&2
  exit 1
fi
DRIVER_LOG=$(mktemp /tmp/merchant-chromedriver.XXXXXX)
"$CHROMEDRIVER_BIN" --port=4444 >"$DRIVER_LOG" 2>&1 &
DRIVER_PID=$!
cleanup() {
  kill "$DRIVER_PID" 2>/dev/null || true
  wait "$DRIVER_PID" 2>/dev/null || true
  rm -f "$DRIVER_LOG"
}
trap cleanup EXIT
for _ in {1..30}; do
  if curl --silent --fail http://127.0.0.1:4444/status >/dev/null; then
    break
  fi
  if ! kill -0 "$DRIVER_PID" 2>/dev/null; then
    cat "$DRIVER_LOG" >&2
    exit 1
  fi
  sleep 0.2
done
curl --silent --fail http://127.0.0.1:4444/status >/dev/null

flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/merchant_editor_web_test.dart \
  -d web-server --browser-name=chrome --browser-dimension=390x844@1 \
  --driver-port=4444 --no-pub

flutter build web --base-href "/merchant-app/" --output build/merchant-web
