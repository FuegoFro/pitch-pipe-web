#!/usr/bin/env bash
set -euo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# build
cd "${DIR}"
pnpm build

DEPLOY_URL="git@github.com:FuegoFro/pitch-pipe-web.git"

# navigate into the build output directory and push to remote
cd "${DIR}/dist"
git init
git add -A
git commit -m 'deploy'
# Deploy to https://fuegofro.github.io/pitch-pipe-web/
git push -f "${DEPLOY_URL}" HEAD:gh-pages
