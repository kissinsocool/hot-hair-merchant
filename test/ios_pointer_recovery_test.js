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

test('releases an abandoned native textarea gesture after the finger lifts', () => {
  const {flutterView, window} = createRuntime();
  let cancellations = 0;
  flutterView.addEventListener('pointercancel', () => cancellations++);

  window.dispatchEvent({
    type: 'pointerdown',
    pointerType: 'touch',
    pointerId: 10,
    target: {closest: (selector) => selector === '[data-native-selection-field]'},
  });
  assert.equal(cancellations, 0, 'must preserve native selection while touching');
  window.dispatchEvent({type: 'touchend', touches: []});

  assert.equal(cancellations, 1, 'must release the pointer held by Flutter');
  window.dispatchEvent({type: 'touchend', touches: []});
  assert.equal(cancellations, 1, 'must not cancel the same pointer twice');
});

test('does not cancel a finger still down when touch and pointer IDs differ', () => {
  const {flutterView, window} = createRuntime();
  const cancellations = [];
  flutterView.addEventListener('pointercancel', (event) => cancellations.push(event));
  window.dispatchEvent({type: 'pointerdown', pointerType: 'touch', pointerId: 10});
  window.dispatchEvent({type: 'pointerdown', pointerType: 'touch', pointerId: 11});
  window.dispatchEvent({type: 'pointerup', pointerType: 'touch', pointerId: 11});
  window.dispatchEvent({type: 'touchend', touches: [{identifier: 0}]});
  assert.equal(cancellations.length, 0);
  window.dispatchEvent({type: 'touchend', touches: []});
  assert.equal(cancellations.length, 1);
  assert.equal(cancellations[0].pointerId, 10);
});

test('recovers repeated native selection interruptions on touchcancel', () => {
  const {flutterView, window} = createRuntime();
  const cancellations = [];
  flutterView.addEventListener('pointercancel', (event) => cancellations.push(event));
  const target = {closest: () => true};
  for (let pointerId = 1; pointerId <= 100; pointerId++) {
    window.dispatchEvent({type: 'pointerdown', pointerType: 'touch', pointerId, target});
    window.dispatchEvent({type: 'touchcancel', touches: []});
    assert.equal(cancellations.length, pointerId);
    assert.equal(cancellations.at(-1).pointerId, pointerId);
  }
  window.dispatchEvent({type: 'pointerdown', pointerType: 'touch', pointerId: 101, target});
  window.dispatchEvent({type: 'pointerup', pointerType: 'touch', pointerId: 101});
  window.dispatchEvent({type: 'touchend', touches: []});
  assert.equal(cancellations.length, 100, 'normal input must still finish without repair');
});

test('does not install the workaround outside iOS WebKit', () => {
  const {flutterView, window} = createRuntime('Mozilla/5.0 (Macintosh; Intel Mac OS X) Chrome/140');
  let cancellations = 0;
  flutterView.addEventListener('pointercancel', () => cancellations++);

  window.dispatchEvent({type: 'pointerdown', pointerType: 'touch', pointerId: 9});
  window.dispatchEvent({type: 'touchend', touches: []});

  assert.equal(cancellations, 0);
});
