import { test, expect, type Locator, type Page } from '@playwright/test';

async function openFlutterApp(page: Page): Promise<Locator> {
  const flutterView = page.locator('flutter-view, flt-glass-pane').first();
  for (let attempt = 0; attempt < 2; attempt += 1) {
    await page.goto('/', { waitUntil: 'domcontentloaded' });
    try {
      await expect(flutterView).toBeVisible({ timeout: 25_000 });
      return flutterView;
    } catch (error) {
      if (attempt === 1) throw error;
    }
  }
  return flutterView;
}

/**
 * Phase 9 browser smoke coverage. The deployed web environment has no seeded
 * authenticated account, so preference field persistence and sound mapping are
 * asserted in Flutter tests while Playwright protects app/settings integration
 * from browser boot and runtime regressions.
 */
test.describe('Phase 9 notification settings compatibility', () => {
  test('notification-enabled app shell boots cleanly', async ({ page }) => {
    const flutterView = await openFlutterApp(page);
    const bounds = await flutterView.boundingBox();
    expect(bounds).not.toBeNull();
    expect(bounds!.width).toBeGreaterThan(0);
    expect(bounds!.height).toBeGreaterThan(0);
  });

  test('notification integration introduces no critical runtime errors', async ({ page }) => {
    const consoleErrors: string[] = [];
    page.on('console', (message) => {
      if (message.type() === 'error') consoleErrors.push(message.text());
    });

    await openFlutterApp(page);
    await page.waitForTimeout(3_000);

    const criticalErrors = consoleErrors.filter(
      (message) =>
        !message.includes('FirebaseError') &&
        !message.includes('Failed to fetch') &&
        !message.includes('net::ERR_') &&
        !message.includes('CORS') &&
        !message.includes('whatwg-encoding')
    );
    expect(criticalErrors).toEqual([]);
    await expect(page.locator('text=/unhandled exception/i')).not.toBeVisible();
  });
});
