#!/usr/bin/env bash
set -euo pipefail

TAP="kingdave100/tap"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

current_branch="$(git branch --show-current)"
if [[ "${current_branch}" != "main" ]]
then
  echo "Run this script from the main branch." >&2
  exit 1
fi

working_tree="$(git status --porcelain)"
if [[ -n "${working_tree}" ]]
then
  echo "Working tree is not clean; commit or stash changes before checking updates." >&2
  exit 1
fi

git fetch origin main --quiet
local_head="$(git rev-parse HEAD)"
remote_head="$(git rev-parse origin/main)"
if [[ "${local_head}" != "${remote_head}" ]]
then
  echo "Local main is not up to date with origin/main. Run 'git pull --ff-only' first." >&2
  exit 1
fi

run_livecheck() {
  local result stderr_file attempt
  stderr_file="$(mktemp)"
  for attempt in 1 2 3
  do
    if result=$(brew livecheck "$@" 2>"${stderr_file}")
    then
      rm -f "${stderr_file}"
      printf '%s\n' "${result}"
      return 0
    fi
    if [[ "${attempt}" -lt 3 ]]
    then
      echo "Livecheck attempt ${attempt} failed; retrying in 15 seconds..." >&2
      sleep 15
    fi
  done
  echo "Error: brew livecheck failed for: $*" >&2
  cat "${stderr_file}" >&2
  rm -f "${stderr_file}"
  return 1
}

echo "Checking ${TAP} for newer versions..."
CASKS="$(run_livecheck --tap "${TAP}" --cask --newer-only --json |
  jq -r '.[] | "\(.cask) \(.version.latest)"')"
FORMULAE="$(run_livecheck --tap "${TAP}" --formula --newer-only --json |
  jq -r '.[] | "\(.formula) \(.version.latest)"')"

if [[ -z "${CASKS}${FORMULAE}" ]]
then
  echo "Everything is up to date."
  exit 0
fi

bump() {
  local type="$1" name="$2" version="$3"
  echo "Bumping ${type} ${name} to ${version}"
  if [[ "${type}" == "formula" && "${name}" == "equilotl-cli" ]]
  then
    python3 .github/scripts/bump-equilotl.py "${version}"
  else
    brew "bump-${type}-pr" --write-only --no-browse \
      --version="${version}" "${TAP}/${name}"
  fi

  if ! git diff --quiet
  then
    git add Formula Casks
    git commit -m "${name} ${version}"
  fi
}

while read -r name version
do
  [[ -n "${name:-}" ]] && bump cask "${name}" "${version}"
done <<<"${CASKS}"

while read -r name version
do
  [[ -n "${name:-}" ]] && bump formula "${name}" "${version}"
done <<<"${FORMULAE}"

local_head="$(git rev-parse HEAD)"
remote_head="$(git rev-parse origin/main)"
if [[ "${local_head}" != "${remote_head}" ]]
then
  git push origin HEAD:main
  echo "Update(s) pushed to origin/main."
else
  echo "No file changes were needed."
fi
