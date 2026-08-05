import { defineConfig, devices } from '@playwright/test';

/**
 * Playwright configuration for SakayNow Flutter web smoke tests.
 *
 * Expects the Flutter web build to be served locally (e.g. via
 * `flutter run -d chrome --web-port 8080` or a static file server
 * on port 8080).
 */
export default defineConfig({
  testDir: './tests',
  fullyParallel: false,
  retries: 1,
  workers: 1,
  reporter: [['html', { open: 'never' }], ['list']],
  timeout: 60_000,
  expect: { timeout: 15_000 },

  use: {
    baseURL: 'http://localhost:8080',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },

  webServer: {
    command: 'npx --yes http-server ../build/web -p 8080 -c-1',
    port: 8080,
    timeout: 30_000,
    reuseExistingServer: true,
  },

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
});
