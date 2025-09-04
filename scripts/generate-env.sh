#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${SUPABASE_URL:-}" || -z "${SUPABASE_ANON_KEY:-}" ]]; then
  echo "[generate-env.sh] SUPABASE_URL or SUPABASE_ANON_KEY is missing" >&2
  exit 1
fi

cat > env.js <<EOF
window.__ENV = {
  SUPABASE_URL: "${SUPABASE_URL}",
  SUPABASE_ANON_KEY: "${SUPABASE_ANON_KEY}"
};
EOF

echo "[generate-env.sh] Wrote env.js"

