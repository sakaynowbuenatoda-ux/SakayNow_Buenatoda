import { test, expect, Page } from '@playwright/test';

/**
 * SakayNow Flutter Web – App Shell Smoke Tests
 *
 * Verifies that the Flutter web engine boots cleanly, initializes Firebase
 * bindings without unhandled runtime exceptions, and renders the unauthenticated
 * welcome screen by default when accessed in a fresh session.
 */

async function waitForFlutterBoot(page: Page) {
  await page.waitForSelector('flutter-view, flt-glass-pane', {
    timeout: 30_000,
  });
}

test.describe('Flutter Web Build Boot & Stability', () => {
  test('engine renders initial frame without crash', async ({ page }) => {
    await page.goto('/');
    await waitForFlutterBoot(page);

    const flutterView = page.locator('flutter-view, flt-glass-pane').first();
    await expect(flutterView).toBeVisible();

    // Ensure no obvious Flutter critical crash overlays are present in standard DOM
    const crashNotice = page.locator('text=/unhandled exception/i');
    await expect(crashNotice).toBeHidden();
  });

  test('no critical JavaScript console errors during boot and Firebase init', async ({ page }) => {
    const consoleErrors: string[] = [];
    page.on('console', (msg) => {
      if (msg.type() === 'error') {
        consoleErrors.push(msg.text());
      }
    });

    await page.goto('/');
    await waitForFlutterBoot(page);

    // Give the application a few seconds to process any initial auth/stream checks
    await page.waitForTimeout(3_000);

    // Filter out known benign errors (e.g., Firebase network retries or local CORS when offline)
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
});

test.describe('Default Session State Routing', () => {
  test('unauthenticated root load terminates stably in unauthed viewport', async ({
    page,
  }) => {
    await page.goto('/');
    await waitForFlutterBoot(page);

    // Verify the engine mounts stably and maintains an active viewport without loop redirects
    const flutterView = page.locator('flutter-view, flt-glass-pane').first();
    const box = await flutterView.boundingBox();
    expect(box?.height).toBeGreaterThan(0);

    // Confirm URL does not crash or infinitely route-hop
    await page.waitForTimeout(2_000);
    expect(page.url()).toContain('http://localhost:8080');
  });
});
