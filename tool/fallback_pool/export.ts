/**
 * `scripts/fallback_pool.sh build <date>…`: reads the raw sets fetched from KV
 * (`tool/fallback_pool/raw/set-<date>.json`) and the owner's corrections
 * (`tool/fallback_pool/corrections.json`), converts them (`convert.ts`) and,
 * only when all of them pass, writes the pool asset and the review file. Reads
 * and writes local files only: it never talks to Cloudflare.
 */
import { readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { convert, parseCorrections } from './convert';

const root = process.cwd();
const dates = process.argv.slice(2);
const raws = [];
for (const date of dates) {
  const file = path.join(root, 'tool/fallback_pool/raw', `set-${date}.json`);
  let text = '';
  try {
    text = await readFile(file, 'utf8');
  } catch {
    text = '';
  }
  raws.push({ date, text });
}

function fail(problems: readonly string[]): never {
  console.error('Not written. Problems:');
  for (const p of problems) console.error(`  - ${p}`);
  process.exit(1);
}

const correctionsFile = path.join(root, 'tool/fallback_pool/corrections.json');
let correctionsText: string;
try {
  correctionsText = await readFile(correctionsFile, 'utf8');
} catch {
  fail([`corrections: cannot read ${path.relative(root, correctionsFile)}`]);
}
const parsed = parseCorrections(correctionsText);
if (parsed.problems.length > 0) fail(parsed.problems);

const result = convert(raws, parsed.corrections);
if (!result.pool || !result.review) fail(result.problems);
await writeFile(path.join(root, 'assets/daily_test_fallback/pool.json'), `${JSON.stringify(result.pool, null, 2)}\n`);
await writeFile(path.join(root, 'tool/fallback_pool/review.md'), result.review);
console.log(
  `Wrote assets/daily_test_fallback/pool.json (${result.pool.sets.length} sets, ${parsed.corrections.length} owner corrections) and tool/fallback_pool/review.md.`,
);
