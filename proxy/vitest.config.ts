import { cloudflareTest } from '@cloudflare/vitest-pool-workers';
import { defineConfig } from 'vitest/config';

export default defineConfig({
  plugins: [
    cloudflareTest({
      wrangler: { configPath: './wrangler.jsonc' },
      // Fixed dummy secrets for a hermetic, reproducible test run — not
      // read from `.dev.vars` (that file is for a developer's own real
      // `wrangler dev` session, and shouldn't need to exist for `npm
      // test` to pass in CI or on a fresh checkout).
      miniflare: {
        bindings: {
          ANTHROPIC_API_KEY: 'test-anthropic-key',
          APP_TOKEN: 'test-app-token',
        },
      },
    }),
  ],
});
