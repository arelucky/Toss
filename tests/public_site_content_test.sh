#!/usr/bin/env bash
set -euo pipefail

site_root="$(cd "$(dirname "$0")/.." && pwd)/public-site"

test -f "$site_root/index.html"
test -f "$site_root/privacy.html"
test -f "$site_root/assets/site.css"

rg -q 'tossritual\.support@proton\.me' "$site_root/index.html" "$site_root/privacy.html"
rg -q 'href="privacy\.html"' "$site_root/index.html"
rg -q 'Sign in with Apple' "$site_root/privacy.html"
rg -q 'Supabase' "$site_root/privacy.html"
rg -q '不出售个人信息' "$site_root/privacy.html"
