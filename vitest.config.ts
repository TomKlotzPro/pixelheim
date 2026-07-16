import { defineConfig } from "vitest/config";

// Unit tests live next to the pure modules they cover; the e2e suite in
// e2e/ belongs to Playwright and must stay out of vitest's glob.
export default defineConfig({
  test: {
    include: ["src/**/*.test.ts"],
  },
});
