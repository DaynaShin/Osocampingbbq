// Generate env.js from process.env for static deployments
// Usage: SUPABASE_URL=... SUPABASE_ANON_KEY=... node scripts/generate-env.js

const fs = require('fs');
const path = require('path');

const { SUPABASE_URL, SUPABASE_ANON_KEY } = process.env;

if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
  console.error('[generate-env] Missing SUPABASE_URL or SUPABASE_ANON_KEY');
  process.exit(1);
}

const content = `window.__ENV = {\n  SUPABASE_URL: ${JSON.stringify(SUPABASE_URL)},\n  SUPABASE_ANON_KEY: ${JSON.stringify(SUPABASE_ANON_KEY)}\n};\n`;

const outfile = path.join(process.cwd(), 'env.js');
fs.writeFileSync(outfile, content, 'utf8');
console.log('[generate-env] Wrote env.js');

