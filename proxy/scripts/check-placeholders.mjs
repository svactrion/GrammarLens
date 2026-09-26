// Runs before `npm run deploy`: refuses to deploy while wrangler.jsonc still
// has an unfilled placeholder (such as the DAILY_SETS_KV namespace id, which
// the owner creates at D1). A plain `npx wrangler deploy` skips this check.
import { readFileSync } from 'node:fs';

const config = readFileSync(new URL('../wrangler.jsonc', import.meta.url), 'utf8');
const placeholders = config.match(/REPLACE_WITH_[A-Z0-9_]+/g);
if (placeholders) {
  console.error(
    `Refusing to deploy: wrangler.jsonc still contains ${[...new Set(placeholders)].join(', ')}. ` +
      'Create the resource and paste its id first (see docs/1.1.0-shared-daily-test.md, D1 checklist).',
  );
  process.exit(1);
}
