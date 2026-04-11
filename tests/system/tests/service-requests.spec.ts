import { test, expect } from '@playwright/test';

/**
 * System (E2E) tests — run against the full stack (Docker Compose).
 *
 * Prerequisites: `docker compose up` must be running before executing these.
 *
 * What these test that unit/integration tests CANNOT:
 * - The React app actually loads in a real browser
 * - Navigation between pages works (React Router)
 * - Form input, submission, and API round-trips work end-to-end
 * - The UI re-renders correctly after data changes
 * - nginx routing (SPA fallback, /api proxy) works correctly
 */

// ─── Homepage / Request List ──────────────────────────────────────────────────

test('homepage loads and shows the request list heading', async ({ page }) => {
  await page.goto('/');

  // The page heading should be visible
  await expect(page.getByRole('heading', { name: /service requests/i })).toBeVisible();
});

test('homepage has a link to create a new request', async ({ page }) => {
  await page.goto('/');

  // There should be a button or link to create a new request
  const newRequestLink = page.getByRole('link', { name: /new request/i });
  await expect(newRequestLink).toBeVisible();
});

// ─── Create a new request ─────────────────────────────────────────────────────

test('can fill and submit the new request form', async ({ page }) => {
  await page.goto('/new');

  // Fill the form fields
  await page.getByLabel(/title/i).fill('E2E Test Request');
  await page.getByLabel(/description/i).fill('Created by Playwright system test');
  await page.getByLabel(/requestor email/i).fill('playwright@example.com');

  // Submit
  await page.getByRole('button', { name: /submit|create|save/i }).click();

  // After submission we should be redirected to the list or detail page
  // and the new request title should be visible somewhere
  await expect(page.getByText('E2E Test Request')).toBeVisible();
});

// ─── View request detail ──────────────────────────────────────────────────────

test('clicking a request navigates to the detail page', async ({ page }) => {
  // First create a request so we have something to click on
  await page.goto('/new');
  await page.getByLabel(/title/i).fill('Detail Page Test');
  await page.getByLabel(/description/i).fill('Testing navigation to detail');
  await page.getByLabel(/requestor email/i).fill('detail@example.com');
  await page.getByRole('button', { name: /submit|create|save/i }).click();

  // We should now be on the list or detail page — find the request and click it
  await page.goto('/');
  const requestLink = page.getByText('Detail Page Test').first();
  await requestLink.click();

  // The detail page should show the full description
  await expect(page.getByText('Testing navigation to detail')).toBeVisible();
});

// ─── Update status ────────────────────────────────────────────────────────────

test('can update the status of a request', async ({ page }) => {
  // Create a request
  await page.goto('/new');
  await page.getByLabel(/title/i).fill('Status Update Test');
  await page.getByLabel(/description/i).fill('Will update status via UI');
  await page.getByLabel(/requestor email/i).fill('status@example.com');
  await page.getByRole('button', { name: /submit|create|save/i }).click();

  // After submit, onSuccess navigates to /requests/:id — wait for it
  await page.waitForURL(/\/requests\/.+/);

  // Select a new status and save using the option value (not label text)
  await page.getByRole('combobox').selectOption('in_progress');
  await page.getByRole('button', { name: /update/i }).click();

  // The status badge (data-testid="status-badge") should reflect the new status
  await expect(page.getByTestId('status-badge')).toHaveText(/in.?progress/i);
});

// ─── Search / filter ──────────────────────────────────────────────────────────

test('search filters the request list', async ({ page }) => {
  // Create two distinguishable requests
  const createRequest = async (title: string) => {
    await page.goto('/new');
    await page.getByLabel(/title/i).fill(title);
    await page.getByLabel(/description/i).fill('Search filter test');
    await page.getByLabel(/requestor email/i).fill('search@example.com');
    await page.getByRole('button', { name: /submit|create|save/i }).click();
  };

  await createRequest('UNIQUE-ZEBRA-REQUEST');
  await createRequest('UNIQUE-ALPHA-REQUEST');

  // Go to list and search for one of them
  await page.goto('/');
  await page.getByPlaceholder(/search/i).fill('ZEBRA');

  // Only the ZEBRA request should be visible; ALPHA should be hidden
  await expect(page.getByText('UNIQUE-ZEBRA-REQUEST').first()).toBeVisible();
  await expect(page.getByText('UNIQUE-ALPHA-REQUEST').first()).not.toBeVisible();
});
