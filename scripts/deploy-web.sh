#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bash "$project_root/scripts/build-web.sh"
cd "$project_root/backend/mfu-reg-backend"
npm ci --no-audit --no-fund
npm test
npx --yes vercel@65.12.0 project inspect --non-interactive
npx --yes vercel@65.12.0 deploy --prod
