import { defineConfig } from '@playwright/test'

export default defineConfig({
  testDir: 'e2e',
  fullyParallel: true,
  retries: process.env.CI ? 1 : 0,
  reporter: process.env.CI ? 'github' : 'list',
  use: {
    baseURL: 'http://localhost:4173/pixelheim/',
    viewport: { width: 1024, height: 768 },
    permissions: ['clipboard-read', 'clipboard-write'],
  },
  webServer: {
    // Tests run against the production build, since that is what ships.
    command: 'pnpm build && pnpm preview --port 4173 --strictPort',
    url: 'http://localhost:4173/pixelheim/',
    reuseExistingServer: !process.env.CI,
  },
})
