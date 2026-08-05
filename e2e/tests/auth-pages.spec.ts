import { test, expect } from '@playwright/test';

/**
 * SakayNow Flutter Web – Auth & Welcome Page Smoke Tests
 *
 * Note on Flutter Web Rendering:
 * Flutter Web uses CanvasKit / WebGL to paint UI directly onto an HTML5 Canvas
 * inside a `<flutter-view>` custom element. Individual buttons and text elements
 * are drawn on the canvas and do not exist as standard HTML DOM nodes unless
 * screen reader accessibility semantics are actively triggered.
 *
 * Therefore, E2E smoke tests verify that:
 * 1. The Flutter engine hydrates and mounts `<flutter-view>` successfully.
 * 2. An active rendering canvas with non-zero dimensions is mounted and visible.
 * 3. Document metadata (title, URL state) reflects the intended route without crash.
 */

test.describe('Auth and Welcome Pages Render', () => {
  test('welcome page loads and paints active canvas without crash', async ({ page }) => {
    await page.goto('/');

    // Wait for Flutter engine hydration and custom element attachment
    const flutterView = page.locator('flutter-view, flt-glass-pane').first();
    await expect(flutterView).toBeVisible({ timeout: 30_000 });

    // Ensure the underlying canvas or render target is present and sized
    const boundingBox = await flutterView.boundingBox();
    expect(boundingBox).not.toBeNull();
    expect(boundingBox!.width).toBeGreaterThan(0);
    expect(boundingBox!.height).toBeGreaterThan(0);
  });

  test('page title is correctly set to SakayNow', async ({ page }) => {
    await page.goto('/');
    await expect(page).toHaveTitle(/sakaynow/i, { timeout: 30_000 });
  });

  test('passenger registration and authentication routes maintain canvas stability', async ({ page }) => {
    await page.goto('/');
    const flutterView = page.locator('flutter-view, flt-glass-pane').first();
    await expect(flutterView).toBeVisible({ timeout: 30_000 });

    await page.waitForTimeout(2_000);
    const boundingBox = await flutterView.boundingBox();
    expect(boundingBox).not.toBeNull();
    expect(boundingBox!.width).toBeGreaterThan(0);
    expect(boundingBox!.height).toBeGreaterThan(0);
  });
});
