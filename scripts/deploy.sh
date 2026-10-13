#!/usr/bin/env bash
set -euo pipefail

revision="${1:?Expected a Git commit SHA}"
[[ "$revision" =~ ^[0-9a-f]{40}$ ]] || { echo 'Invalid commit SHA' >&2; exit 1; }
docker compose version
deploy_dir="$HOME/apps/miraitowa-hub"
mkdir -p "$HOME/apps"
if [[ ! -d "$deploy_dir" ]]; then
  git clone https://github.com/Miraitowa-la/miraitowa-hub.git "$deploy_dir"
fi
cd "$deploy_dir"
[[ "$(git remote get-url origin)" == 'https://github.com/Miraitowa-la/miraitowa-hub.git' ]]
git fetch origin "$revision"
git checkout --detach "$revision"
export REVISION="$revision"
docker compose up --build --detach --wait --wait-timeout 120
deployed_revision="$(curl --fail --silent --show-error http://127.0.0.1:8080/revision.txt)"
[[ "$deployed_revision" == "$revision" ]] || { echo 'Deployed revision does not match' >&2; exit 1; }
echo "Deployed $revision successfully"
