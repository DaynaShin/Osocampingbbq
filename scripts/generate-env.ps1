Param(
  [Parameter(Mandatory=$false)][string]$OutFile = "env.js"
)

if (-not $env:SUPABASE_URL -or -not $env:SUPABASE_ANON_KEY) {
  Write-Error "[generate-env.ps1] SUPABASE_URL or SUPABASE_ANON_KEY is missing"
  exit 1
}

$content = @"
window.__ENV = {
  SUPABASE_URL: "$($env:SUPABASE_URL)",
  SUPABASE_ANON_KEY: "$($env:SUPABASE_ANON_KEY)"
};
"@

Set-Content -Path $OutFile -Value $content -Encoding UTF8
Write-Output "[generate-env.ps1] Wrote $OutFile"

