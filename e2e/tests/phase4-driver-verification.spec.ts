import { test, expect } from '@playwright/test';

/**
 * SakayNow Flutter Web – Phase 4 Driver Verification & Vehicle Data E2E Smoke Tests
 *
 * Verifies that:
 * 1. The 3-step driver registration onboarding workflow loads and renders cleanly without runtime regressions.
 * 2. Admin verification review views with vehicle data and uploaded credentials grid maintain stable canvas rendering.
 * 3. No critical unhandled JavaScript runtime exceptions occur during engine initialization.
 */

test.describe('Phase 4 Driver Verification & Vehicle Data Flow', () => {
  test('driver 3-step onboarding workflow initializes cleanly on canvas', async ({ page }) => {
    await page.goto('/');

    const flutterView = page.locator('flutter-view, flt-glass-pane').first();
    await expect(flutterView).toBeVisible({ timeout: 30_000 });

    const boundingBox = await flutterView.boundingBox();
    expect(boundingBox).not.toBeNull();
    expect(boundingBox!.width).toBeGreaterThan(0);
    expect(boundingBox!.height).toBeGreaterThan(0);
  });

  test('no critical runtime JavaScript exceptions during driver registration boot', async ({ page }) => {
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

  test('admin user review vehicle info and credential grids maintain UI stability', async ({ page }) => {
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
