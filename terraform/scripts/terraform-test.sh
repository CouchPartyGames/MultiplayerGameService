#!/usr/bin/env bash
# Runs `terraform test` in each configuration under terraform/ that contains one
# of the given files and has a tests/ directory. File paths are relative to the
# current directory; prek runs the hook from terraform/ and passes the changed
# files relative to it. With no arguments, every child module with tests is run.
# The tests use mock providers, so they need no cloud credentials and create no
# resources.
set -euo pipefail

if ! command -v terraform >/dev/null 2>&1; then
  echo "terraform not found; install it with terraform/tools/terraform-install.sh" >&2
  exit 1
fi

if [ "$#" -eq 0 ]; then
  cd "$(dirname "${BASH_SOURCE[0]}")/.."
  set -- modules/*/*/versions.tf
fi

# Map each file to its configuration directory; files under tests/ belong to the parent.
declare -A CONFIGS=()
for file in "$@"; do
  dir="$(dirname "$file")"
  if [ "$(basename "$dir")" = "tests" ]; then
    dir="$(dirname "$dir")"
  fi
  if [ -d "${dir}/tests" ]; then
    CONFIGS["$dir"]=1
  fi
done

status=0
for config in "${!CONFIGS[@]}"; do
  echo "terraform test: ${config}"
  if [ ! -d "${config}/.terraform" ]; then
    terraform -chdir="$config" init -backend=false -input=false >/dev/null || { status=1; continue; }
  fi
  terraform -chdir="$config" test -no-color || status=1
done
exit "$status"
