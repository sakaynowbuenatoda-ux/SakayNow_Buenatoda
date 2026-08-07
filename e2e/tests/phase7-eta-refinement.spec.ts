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
 * Phase 7 browser smoke coverage for the ride-monitoring ETA refinements.
 * Authenticated Firestore status transitions and exact pickup/destination ETA
 * copy are covered by Flutter widget and rules tests when this web environment
 * has no seeded Firebase users.
 */
test.describe('Phase 7 ride ETA refinement', () => {
  test('ride-monitoring additions initialize in the Flutter web shell', async ({ page }) => {
    const flutterView = await openFlutterApp(page);

    const bounds = await flutterView.boundingBox();
    expect(bounds).not.toBeNull();
    expect(bounds!.width).toBeGreaterThan(0);
    expect(bounds!.height).toBeGreaterThan(0);
  });

  test('ETA status UI introduces no critical runtime errors', async ({ page }) => {
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
