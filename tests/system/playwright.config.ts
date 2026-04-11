import { defineConfig, devices } from '@playwright/test';

// The app URL — override with BASE_URL env var in CI or other environments
const BASE_URL = process.env.BASE_URL ?? 'http://localhost:3000';

export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  // Retry once locally, twice in CI — flaky network/animation timing can cause
  // transient failures in E2E tests
  retries: process.env.CI ? 2 : 1,
  workers: process.env.CI ? 1 : undefined,
  reporter: [['list'], ['html', { open: 'never' }]],

  use: {
    baseURL: BASE_URL,
    // Record a trace on every retry so you can inspect failures visually
    trace: 'on-first-retry',
    // Screenshot on failure
    screenshot: 'only-on-failure',
  },

  projects: [
    {
      // Run locally against Chromium only — fast feedback
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
    // Uncomment in CI to run cross-browser:
    // { name: 'firefox', use: { ...devices['Desktop Firefox'] } },
    // { name: 'webkit',  use: { ...devices['Desktop Safari'] } },
  ],
});
