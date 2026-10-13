#!/usr/bin/env bash
set -euo pipefail

# Mock external commands so checks never touch a server or a local checkout.
mkdir() { :; }
cd() { :; }
git() {
  case "$1" in
    clone) [[ "$2" == 'https://github.com/Miraitowa-la/miraitowa-hub.git' ]] ;;
    remote) printf '%s\n' 'https://github.com/Miraitowa-la/miraitowa-hub.git' ;;
    fetch) [[ "$2" == origin && "$3" == "$expected_revision" ]] ;;
    checkout) [[ "$2" == --detach && "$3" == "$expected_revision" ]] ;;
    *) return 1 ;;
  esac
}
docker() {
  [[ "$*" == 'compose version' ]] || {
    [[ "$*" == 'compose up --build --detach --wait --wait-timeout 120' ]]
    [[ "$REVISION" == "$expected_revision" ]]
  }
}
curl() { printf '%s\n' "$returned_revision"; }
export -f mkdir cd git docker curl
export expected_revision=0123456789abcdef0123456789abcdef01234567
export returned_revision="$expected_revision"

"$BASH" scripts/deploy.sh "$expected_revision"
export returned_revision=wrong
if "$BASH" scripts/deploy.sh "$expected_revision" >/dev/null 2>&1; then
  echo 'Revision mismatch was accepted' >&2
  exit 1
fi
if "$BASH" scripts/deploy.sh invalid >/dev/null 2>&1; then
  echo 'Invalid commit SHA was accepted' >&2
  exit 1
fi
echo 'Deployment script checks passed'
