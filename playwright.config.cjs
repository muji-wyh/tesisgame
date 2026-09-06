const path = require('node:path');
const { defineConfig, devices } = require('@playwright/test');

if (!devices['iPhone 13'] || !devices['iPad Pro 11']) {
  throw new Error('Required Apple device profiles are unavailable.');
}

module.exports = defineConfig({
  testDir: path.join(__dirname, 'tests', 'browser'),
  testMatch: '*.spec.cjs',
  timeout: 30000,
  expect: { timeout: 7000 },
  workers: 1,
  retries: 0,
  forbidOnly: true,
  reporter: 'list',
  use: {
    baseURL: 'http://127.0.0.1:4173',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure'
  },
  webServer: {
    command: 'npm start',
    url: 'http://127.0.0.1:4173',
    reuseExistingServer: false,
    timeout: 20000
  },
  projects: [
    {
      name: 'desktop-chromium',
      use: { browserName: 'chromium', viewport: { width: 1366, height: 768 }, hasTouch: true }
    },
    { name: 'iphone-webkit', use: { ...devices['iPhone 13'], browserName: 'webkit' } },
    { name: 'ipad-webkit', use: { ...devices['iPad Pro 11'], browserName: 'webkit' } }
  ]
});
