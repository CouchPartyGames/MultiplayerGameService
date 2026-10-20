#!/usr/bin/env bash
# Checks the README.md of each root module under terraform/envs/ against
# terraform/envs/README.template.md, and requires a new "Most Recent Changes"
# entry in every env whose configuration changed, directly or through a child
# module it calls. Paths are relative to terraform/ (a leading "terraform/" is
# stripped), and the script works from any directory.
#
#   env-docs-check.sh [files...]             Staged mode (the prek hook): check the
#                                            envs the given files belong to, and
#                                            require an entry for staged changes.
#   env-docs-check.sh --base <ref> --pr <n>  CI mode: check every env changed since
#                                            <ref>; each needs a new entry with #<n>.
#   env-docs-check.sh --list-affected files  Print the envs the given files affect.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

HEADINGS=("# Purpose" "# Cloud Provider Details" "# Diagram" "# Most Recent Changes")
ENTRY_RE='^[0-9]{2}/[0-9]{2}/[0-9]{4} - .+ \(#([0-9]+|TBD) - .+\)$'

# Required "Key: value" lines under "# Cloud Provider Details", by env name prefix.
provider_keys() {
  case "$1" in
    aws-*) printf '%s\n' "AWS Account" "AWS Region" "AWS VPC" ;;
    azure-*) printf '%s\n' "Azure Subscription" "Azure Region" "Azure VNet" ;;
    gcp-*) printf '%s\n' "GCP Project" "GCP Region" "GCP VPC" ;;
    *) return 1 ;;
  esac
}

# A file changes an env's deployment when it is configuration (not docs or tests).
is_config() {
  [[ "$1" =~ \.(tf|tfvars|hcl)$ && "$1" != */tests/* ]]
}

# Prints the env directories (envs/<name>) that a file belongs to or that call
# the child module it belongs to. Envs without .tf files are skipped.
envs_for() {
  local file="${1#terraform/}" env module
  case "$file" in
    envs/*/*)
      env="$(cut -d/ -f1-2 <<<"$file")"
      compgen -G "${env}/*.tf" >/dev/null && echo "$env"
      ;;
    modules/*/*/*)
      module="$(cut -d/ -f1-3 <<<"$file")"
      { grep -lF "\"../../${module}\"" envs/*/*.tf 2>/dev/null || true; } | xargs -r -n1 dirname
      ;;
  esac
  return 0
}

affected_by() {
  local file
  for file in "$@"; do
    if is_config "$file"; then envs_for "$file"; fi
  done | sort -u
}

# Prints the lines of one "# Heading" section, outside code fences.
section() {
  awk -v want="$2" '
    /^```/ { fence = !fence }
    !fence && /^# / { in_section = ($0 == want); next }
    in_section { print }
  ' "$1"
}

errors=0
fail() {
  echo "$1: $2" >&2
  errors=$((errors + 1))
}

check_structure() {
  local env="$1" readme="$1/README.md" key line date prev=99999999
  if [ ! -f "$readme" ]; then
    fail "$readme" "missing; create it from envs/README.template.md"
    return
  fi

  local found
  found="$(awk '/^```/ { fence = !fence } !fence && /^# /' "$readme")"
  if [ "$found" != "$(printf '%s\n' "${HEADINGS[@]}")" ]; then
    fail "$readme" "top-level headings must be exactly, in order: $(printf "'%s', " "${HEADINGS[@]}" | sed 's/, $//')"
  fi

  local keys
  if keys="$(provider_keys "$(basename "$env")")"; then
    while IFS= read -r key; do
      section "$readme" "# Cloud Provider Details" | grep -qE "^${key}: +[^ ]" ||
        fail "$readme" "missing or empty '${key}:' under # Cloud Provider Details"
    done <<<"$keys"
  else
    fail "$readme" "unknown cloud prefix; expected aws-, azure-, or gcp-"
  fi

  section "$readme" "# Diagram" | grep -q '^```mermaid$' ||
    fail "$readme" "missing a \`\`\`mermaid block under # Diagram"

  local entries=0
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    entries=$((entries + 1))
    if [[ ! "$line" =~ $ENTRY_RE ]]; then
      fail "$readme" "bad changelog line '${line}'; expected 'MM/DD/YYYY - Summary (#PR - Author)'"
      continue
    fi
    date="${line:6:4}${line:0:2}${line:3:2}"
    if [ "$date" -gt "$prev" ]; then
      fail "$readme" "changelog is not newest first at '${line}'"
    fi
    prev="$date"
  done < <(section "$readme" "# Most Recent Changes")
  [ "$entries" -gt 0 ] || fail "$readme" "no entries under # Most Recent Changes"
}

# Prints changelog lines that a git diff adds to an env's README.
added_entries() {
  local env="$1"
  shift
  git diff --no-color --unified=0 "$@" -- "${env}/README.md" |
    sed -n 's/^+\([0-9][0-9]\/[0-9][0-9]\/[0-9]\{4\} - .*\)$/\1/p'
}

mode=staged base="" pr=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --list-affected) shift; affected_by "$@"; exit 0 ;;
    --base) base="$2"; mode=ci; shift 2 ;;
    --pr) pr="$2"; shift 2 ;;
    *) break ;;
  esac
done

if [ "$mode" = ci ]; then
  [ -n "$pr" ] || { echo "--base needs --pr <number>" >&2; exit 2; }
  mapfile -t changed < <(git diff --name-only --relative "${base}...HEAD")
  diff_args=("${base}...HEAD")
  check_envs="$( { affected_by "${changed[@]}"; for f in "${changed[@]}"; do envs_for "$f"; done; } | sort -u)"
else
  # Entries are required for what is staged; prek --all-files passes every file
  # but stages nothing new, so it only runs the structure checks.
  mapfile -t changed < <(git diff --cached --name-only --relative)
  diff_args=(--cached)
  check_envs="$( { affected_by "${changed[@]}"; for f in "$@"; do envs_for "$f"; done; } | sort -u)"
fi

for env in $check_envs; do
  check_structure "$env"
  if [ "$mode" = ci ] && added_entries "$env" "${diff_args[@]}" | grep -q "(#TBD - "; then
    fail "${env}/README.md" "replace #TBD with #${pr} in the new changelog entry"
  fi
done

for env in $(affected_by "${changed[@]}"); do
  entries="$(added_entries "$env" "${diff_args[@]}")"
  if [ -z "$entries" ]; then
    fail "${env}/README.md" "configuration changed but no entry was added under # Most Recent Changes"
  elif [ "$mode" = ci ]; then
    grep -q "(#${pr} - " <<<"$entries" ||
      fail "${env}/README.md" "the new changelog entry must reference this PR (#${pr})"
  fi
done

if [ "$errors" -gt 0 ]; then
  echo "See terraform/envs/README.template.md and the terraform-env-docs skill." >&2
  exit 1
fi
