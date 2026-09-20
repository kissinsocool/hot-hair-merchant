// Remove after upgrading to a Flutter release containing flutter/flutter#189608.
(() => {
  const isIOSWebKit =
    /iPad|iPhone|iPod/.test(navigator.userAgent) ||
    (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  if (!isIOSWebKit || typeof PointerEvent === 'undefined') return;

  const downTouches = new Map();

  window.addEventListener('pointerdown', (event) => {
    if (event.pointerType !== 'touch') return;
    if (event.target?.closest?.('[data-native-selection-field]')) return;
    downTouches.set(event.pointerId, {
      clientX: event.clientX ?? 0,
      clientY: event.clientY ?? 0,
      isPrimary: event.isPrimary ?? false,
    });
  }, true);

  const release = (event) => {
    if (event.pointerType === 'touch') downTouches.delete(event.pointerId);
  };
  window.addEventListener('pointerup', release, true);
  window.addEventListener('pointercancel', release, true);

  const cancelAbandonedTouches = (event) => {
    if (downTouches.size === 0) return;

    const onSurface = new Set(Array.from(event.touches, (touch) => touch.identifier));
    const flutterView = document.querySelector('flutter-view');
    if (!flutterView) return;

    for (const [pointerId, lastEvent] of downTouches) {
      if (onSurface.has(pointerId)) continue;
      downTouches.delete(pointerId);
      flutterView.dispatchEvent(new PointerEvent('pointercancel', {
        bubbles: true,
        composed: true,
        pointerId,
        pointerType: 'touch',
        isPrimary: lastEvent.isPrimary,
        clientX: lastEvent.clientX,
        clientY: lastEvent.clientY,
        button: 0,
        buttons: 0,
        pressure: 0,
      }));
    }
  };

  window.addEventListener('touchend', cancelAbandonedTouches, true);
  window.addEventListener('touchcancel', cancelAbandonedTouches, true);
})();
