async function installGamepad(page, { connected = false, heldButtons = [] } = {}) {
  await page.addInitScript(({ connected, heldButtons }) => {
    let pad = null;
    let polls = 0;
    Object.defineProperty(navigator, 'getGamepads', {
      configurable: true,
      value: () => { polls++; return pad ? [pad] : []; }
    });
    function notify(type, gamepad) {
      const event = new Event(type);
      Object.defineProperty(event, 'gamepad', { value: gamepad });
      window.dispatchEvent(event);
    }
    window.gamepadFixture = {
      get polls() { return polls; },
      connect() {
        pad = {
          id: 'Xbox Controller (STANDARD GAMEPAD)', index: 0, mapping: 'standard', connected: true,
          timestamp: performance.now(), axes: [0, 0, 0, 0],
          buttons: Array.from({ length: 17 }, () => ({ pressed: false, touched: false, value: 0 }))
        };
        notify('gamepadconnected', pad);
      },
      button(index, pressed) {
        pad.buttons[index] = { pressed, touched: pressed, value: pressed ? 1 : 0 };
        pad.timestamp = performance.now();
      },
      axis(index, value) {
        pad.axes[index] = value;
        pad.timestamp = performance.now();
      },
      disconnect() {
        const disconnected = pad;
        pad = null;
        disconnected.connected = false;
        notify('gamepaddisconnected', disconnected);
      }
    };
    if (connected) {
      window.gamepadFixture.connect();
      for (const index of heldButtons) window.gamepadFixture.button(index, true);
    }
  }, { connected, heldButtons });
}

async function pressGamepad(page, index) {
  await page.evaluate(index => window.gamepadFixture.button(index, true), index);
  await page.waitForTimeout(120);
  await page.evaluate(index => window.gamepadFixture.button(index, false), index);
  await page.waitForTimeout(120);
}

module.exports = { installGamepad, pressGamepad };
