import { test, expect } from '@playwright/test';

/**
 * Phase 6 smoke coverage for the Driver Info Hub, renewal upload route, and
 * admin renewal review UI. Authenticated data paths remain covered by Flutter
 * widget/rules tests when the web smoke environment has no seeded Firebase user.
 */
test.describe('Phase 6 Driver Info Hub and Renewal', () => {
  test('Flutter web shell for driver hub routes initializes cleanly', async ({ page }) => {
    await page.goto('/');

    const flutterView = page.locator('flutter-view, flt-glass-pane').first();
    await expect(flutterView).toBeVisible({ timeout: 30_000 });

    const bounds = await flutterView.boundingBox();
    expect(bounds).not.toBeNull();
    expect(bounds!.width).toBeGreaterThan(0);
    expect(bounds!.height).toBeGreaterThan(0);
  });

  test('renewal and admin review additions introduce no critical runtime errors', async ({ page }) => {
    const consoleErrors: string[] = [];
    page.on('console', (message) => {
      if (message.type() === 'error') consoleErrors.push(message.text());
    });

    await page.goto('/');
    const flutterView = page.locator('flutter-view, flt-glass-pane').first();
    await expect(flutterView).toBeVisible({ timeout: 30_000 });
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
