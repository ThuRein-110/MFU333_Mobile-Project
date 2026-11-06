#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root/frontend"
flutter pub get
flutter build web --release --no-web-resources-cdn --no-wasm-dry-run

node - "$project_root" <<'JS'
const fs = require('node:fs');
const path = require('node:path');
const root = process.argv[2];
const target = path.join(root, 'backend/mfu-reg-backend/public');
fs.mkdirSync(target, { recursive: true });
fs.cpSync(path.join(root, 'frontend/build/web'), target, { recursive: true });
console.log('Flutter web build copied to the backend public directory.');
JS
