const { test, expect } = require('@playwright/test');

test('streaming WASM keeps its fetched response so the browser can cache compiled code', async ({ page }) => {
  await page.addInitScript(() => {
    const instantiate = WebAssembly.instantiateStreaming;
    WebAssembly.instantiateStreaming = async (source, imports) => {
      const response = await source;
      window.wasmResponse = { url: response.url, type: response.type, contentType: response.headers.get('content-type') };
      return instantiate.call(WebAssembly, response, imports);
    };
  });
  await page.goto('/');
  await expect(page.locator('body')).toHaveAttribute('data-engine-ready', 'true', { timeout: 60000 });
  const response = await page.evaluate(() => window.wasmResponse);
  expect(response.url).toMatch(/\/engine-[a-f0-9]{16}\.wasm$/);
  expect(response.type).toBe('basic');
  expect(response.contentType).toBe('application/wasm');
});

for (const scenario of ['streaming Error', 'streaming RangeError', 'fallback RangeError']) {
  test(`a real engine ${scenario} rejection exposes recovery instead of waiting forever`, async ({ page }, testInfo) => {
    const detail = 'Engine allocation failed during startup.';
    await page.addInitScript(({ scenario, detail }) => {
      const reject = () => {
        throw scenario.includes('RangeError') ? new RangeError(detail) : new Error(detail);
      };
      if (scenario.startsWith('streaming')) {
        WebAssembly.instantiateStreaming = async response => {
          await (await response).arrayBuffer();
          reject();
        };
      } else {
        WebAssembly.instantiateStreaming = undefined;
        WebAssembly.instantiate = async () => reject();
      }
    }, { scenario, detail });
    await page.goto('/');
    await expect(page.locator('#message')).toContainText(detail, { timeout: 10000 });
    await expect(page.locator('#retry')).toBeFocused();
    await expect(page.locator('#canvas')).toHaveAttribute('inert');
    await expect(page.locator('body')).not.toHaveAttribute('data-engine-ready', 'true');
    if (scenario === 'streaming RangeError') {
      await page.screenshot({ path: testInfo.outputPath('wasm-startup-recovery.png'), scale: 'css' });
    }
  });
}

test('a rejected filesystem initialization reaches the real engine failure boundary', async ({ page }) => {
  await page.route(/\/engine-[a-f0-9]{16}\.js$/, async route => {
    const response = await route.fetch();
    await route.fulfill({ response, body: `${await response.text()}
      const originalGodot = Godot;
      Godot = async (...args) => {
        const module = await originalGodot(...args);
        module.initFS = () => Promise.reject(new DOMException('Saved data could not be opened.', 'SecurityError'));
        return module;
      };
    ` });
  });
  await page.goto('/');
  await expect(page.locator('#message')).toContainText('Saved data could not be opened.', { timeout: 10000 });
  await expect(page.locator('#retry')).toBeFocused();
  await expect(page.locator('body')).not.toHaveAttribute('data-engine-ready', 'true');
});

test('a blocked saved-data upgrade explains recovery and starts after the other tab closes', async ({ page, context }, testInfo) => {
  const owner = await context.newPage();
  await owner.route('**/startup-storage-owner', route => route.fulfill({ contentType: 'text/html', body: '<title>Storage owner</title>' }));
  await owner.goto('/startup-storage-owner');
  await owner.evaluate(() => new Promise((resolve, reject) => {
    const request = indexedDB.open('/userfs', 20);
    request.onupgradeneeded = () => request.result.createObjectStore('FILE_DATA').createIndex('timestamp', 'timestamp');
    request.onerror = () => reject(request.error);
    request.onsuccess = () => {
      window.savedDataConnection = request.result;
      window.savedDataConnection.onversionchange = () => { window.upgradeRequested = true; };
      const transaction = request.result.transaction('FILE_DATA', 'readwrite');
      const files = transaction.objectStore('FILE_DATA');
      // Godot's web user:// path includes its application data directory.
      for (const directory of ['/userfs/godot', '/userfs/godot/app_userdata', '/userfs/godot/app_userdata/Word Buddies']) {
        files.put({ timestamp: new Date(), mode: 0o40777 }, directory);
      }
      files.put({
        timestamp: new Date(), mode: 0o100666,
        contents: new TextEncoder().encode('[medals]\nversion=1\ncounts={"spring-1": 2}\n')
      }, '/userfs/godot/app_userdata/Word Buddies/medals.cfg');
      transaction.oncomplete = () => resolve();
      transaction.onerror = () => reject(transaction.error);
    };
  }));
  await page.bringToFront();
  await page.goto('/');
  await expect.poll(() => owner.evaluate(() => window.upgradeRequested)).toBe(true);
  await expect(page.locator('#message')).toContainText(/close.*other.*game.*tab/i, { timeout: 10000 });
  await expect(page.locator('#retry')).toBeVisible();
  await expect(page.locator('body')).not.toHaveAttribute('data-engine-ready', 'true');
  expect(await page.evaluate(() => localStorage.getItem('wordBuddies.medalProgress'))).toBeNull();
  await page.screenshot({ path: testInfo.outputPath('storage-blocked-recovery.png'), scale: 'css' });
  await owner.close();
  await page.getByRole('button', { name: 'Try again', exact: true }).click();
  await expect(page.locator('body')).toHaveAttribute('data-engine-ready', 'true', { timeout: 60000 });
  await expect(page.locator('#status')).toBeHidden();
  await expect(page.locator('#canvas')).toBeFocused();
  expect(await page.evaluate(() => localStorage.getItem('wordBuddies.medalProgress'))).toMatch(/"spring-1":\s*2/);
  await page.screenshot({ path: testInfo.outputPath('storage-recovered-game.png'), scale: 'css' });
});

test('a browser without IndexedDB can still play and retain browser rewards', async ({ page }) => {
  await page.addInitScript(() => {
    const open = IDBFactory.prototype.open;
    IDBFactory.prototype.open = function (...args) {
      if (args[0] === '/userfs') throw new DOMException('IndexedDB is unavailable.', 'SecurityError');
      return open.apply(this, args);
    };
    localStorage.setItem('wordBuddies.medalProgress', '[medals]\nversion=1\ncounts={"spring-1": 2}\n');
  });
  await page.goto('/');
  await expect(page.locator('body')).toHaveAttribute('data-engine-ready', 'true', { timeout: 60000 });
  await expect(page.locator('#status')).toBeHidden();
  expect(await page.evaluate(() => localStorage.getItem('wordBuddies.medalProgress'))).toMatch(/"spring-1":\s*2/);
});
