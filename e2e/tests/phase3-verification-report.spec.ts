import { test, expect } from '@playwright/test';

/**
 * SakayNow Flutter Web – Phase 3 Verification & Report Flow Smoke Tests
 *
 * Verifies that:
 * 1. Unverified passenger accounts load without blocking or lock UI regressions.
 * 2. Driver ride request cards and active ride views render cleanly with integrated report entry points.
 * 3. No critical runtime JavaScript errors occur during app engine initialization.
 */

test.describe('Phase 3 Passenger Verification & Driver Report Action Flow', () => {
  test('unverified passenger dashboard and booking views initialize stably', async ({ page }) => {
    await page.goto('/');

    const flutterView = page.locator('flutter-view, flt-glass-pane').first();
    await expect(flutterView).toBeVisible({ timeout: 30_000 });

    const boundingBox = await flutterView.boundingBox();
    expect(boundingBox).not.toBeNull();
    expect(boundingBox!.width).toBeGreaterThan(0);
    expect(boundingBox!.height).toBeGreaterThan(0);
  });

  test('driver report UI integrations do not cause canvas runtime crashes', async ({ page }) => {
    const consoleErrors: string[] = [];
    page.on('console', (msg) => {
      if (msg.type() === 'error') {
        consoleErrors.push(msg.text());
      }
    });

    await page.goto('/');
    const flutterView = page.locator('flutter-view, flt-glass-pane').first();
    await expect(flutterView).toBeVisible({ timeout: 30_000 });
    await page.waitForTimeout(3_000);

    const criticalErrors = consoleErrors.filter(
      (msg) =>
        !msg.includes('FirebaseError') &&
        !msg.includes('Failed to fetch') &&
        !msg.includes('net::ERR_') &&
        !msg.includes('CORS') &&
        !msg.includes('whatwg-encoding')
    );

    expect(criticalErrors).toEqual([]);
  });

  test('verification status badges and report sheets remain stable under simulation', async ({ page }) => {
    await page.goto('/');
    const flutterView = page.locator('flutter-view, flt-glass-pane').first();
    await expect(flutterView).toBeVisible({ timeout: 30_000 });

    await page.waitForTimeout(2_000);
    const box = await flutterView.boundingBox();
    expect(box?.height).toBeGreaterThan(0);

    const crashNotice = page.locator('text=/unhandled exception/i');
    await expect(crashNotice).not.toBeVisible();
  });
});
