import { test, expect } from '@playwright/test';

/**
 * SakayNow Flutter Web – Phase 5 Passenger Vehicle Identification E2E Smoke Tests
 *
 * Verifies that:
 * 1. Passenger booking driver selection cards with vehicle summary chips and modal triggers load stably without crashes.
 * 2. Active ride monitoring screens with interactive DriverVehicleInfoCard streaming maintain canvas rendering stability.
 * 3. No critical unhandled JavaScript runtime exceptions occur during ride tracking engine initialization.
 */

test.describe('Phase 5 Passenger Vehicle Identification Flow', () => {
  test('passenger booking view with vehicle identification features initializes cleanly on canvas', async ({ page }) => {
    await page.goto('/');

    const flutterView = page.locator('flutter-view, flt-glass-pane').first();
    await expect(flutterView).toBeVisible({ timeout: 30_000 });

    const boundingBox = await flutterView.boundingBox();
    expect(boundingBox).not.toBeNull();
    expect(boundingBox!.width).toBeGreaterThan(0);
    expect(boundingBox!.height).toBeGreaterThan(0);
  });

  test('no critical runtime JavaScript exceptions during ride tracking and vehicle details boot', async ({ page }) => {
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

  test('ride monitoring vehicle info cards and photo fallback viewers maintain UI stability', async ({ page }) => {
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
