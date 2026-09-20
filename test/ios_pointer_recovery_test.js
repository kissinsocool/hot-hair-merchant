const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

class FakeEventTarget {
  constructor() {
    this.listeners = new Map();
  }

  addEventListener(type, listener) {
    const listeners = this.listeners.get(type) ?? [];
    listeners.push(listener);
    this.listeners.set(type, listeners);
  }

  dispatchEvent(event) {
    event.target ??= this;
    for (const listener of this.listeners.get(event.type) ?? []) {
      listener(event);
    }
  }
}

class FakePointerEvent {
  constructor(type, init) {
    this.type = type;
    Object.assign(this, init);
  }
}

function createRuntime(userAgent = 'Mozilla/5.0 (iPhone; CPU iPhone OS 27_0 like Mac OS X)') {
  const window = new FakeEventTarget();
  const flutterView = new FakeEventTarget();
  const context = {
    document: {querySelector: () => flutterView},
    navigator: {maxTouchPoints: 5, platform: 'iPhone', userAgent},
    PointerEvent: FakePointerEvent,
    window,
  };
  const script = fs.readFileSync(
    path.join(__dirname, '..', 'web', 'ios_pointer_recovery.js'),
    'utf8',
  );
  vm.runInNewContext(script, context);
  return {flutterView, window};
}

test('cancels a touch that iOS WebKit abandons', () => {
  const {flutterView, window} = createRuntime();
  const cancellations = [];
  flutterView.addEventListener('pointercancel', (event) => cancellations.push(event));

  window.dispatchEvent({
    type: 'pointerdown',
    pointerType: 'touch',
    pointerId: 7,
    clientX: 12,
    clientY: 34,
    isPrimary: true,
  });
  window.dispatchEvent({type: 'touchend', touches: []});

  assert.equal(cancellations.length, 1);
  assert.equal(cancellations[0].pointerId, 7);
  assert.equal(cancellations[0].pointerType, 'touch');
});

test('does not cancel a touch that ended normally', () => {
  const {flutterView, window} = createRuntime();
  let cancellations = 0;
  flutterView.addEventListener('pointercancel', () => cancellations++);

  window.dispatchEvent({type: 'pointerdown', pointerType: 'touch', pointerId: 8});
  window.dispatchEvent({type: 'pointerup', pointerType: 'touch', pointerId: 8});
  window.dispatchEvent({type: 'touchend', touches: []});

  assert.equal(cancellations, 0);
});

test('leaves native selection fields entirely to the browser', () => {
  const {flutterView, window} = createRuntime();
  let cancellations = 0;
  flutterView.addEventListener('pointercancel', () => cancellations++);

  window.dispatchEvent({
    type: 'pointerdown',
    pointerType: 'touch',
    pointerId: 10,
    target: {closest: (selector) => selector === '[data-native-selection-field]'},
  });
  window.dispatchEvent({type: 'touchend', touches: []});

  assert.equal(cancellations, 0);
});

test('does not install the workaround outside iOS WebKit', () => {
  const {flutterView, window} = createRuntime('Mozilla/5.0 (Macintosh; Intel Mac OS X) Chrome/140');
  let cancellations = 0;
  flutterView.addEventListener('pointercancel', () => cancellations++);

  window.dispatchEvent({type: 'pointerdown', pointerType: 'touch', pointerId: 9});
  window.dispatchEvent({type: 'touchend', touches: []});

  assert.equal(cancellations, 0);
});
