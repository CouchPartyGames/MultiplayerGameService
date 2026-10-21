#!/usr/bin/env bash
# Draws an architecture diagram of each given root module with TerraVision
# (https://github.com/patrickchugh/terravision). Paths are relative to the current
# directory. With no arguments, every root module under terraform/envs/ is drawn.
#
# Each root module is planned against empty local state, so the diagram shows every
# resource the code defines and the real state is never read or locked. The run keeps
# its own Terraform data directory (.terraform-diagram/), so the module's .terraform/
# and backend setup are left alone, and it reads .terraform.lock.hcl without changing
# it. The providers still authenticate during plan, so sign in to an account on the
# same cloud first; any read-only account works.
#
# Variables come from terraform.tfvars when it exists, else terraform.tfvars.example.
# DIAGRAM_DIR sets the output directory (default terraform/.diagrams) and
# DIAGRAM_FORMATS the TerraVision formats (default "png svg"). Each diagram is named
# after its root module directory.
set -euo pipefail

if ! command -v terraform >/dev/null 2>&1; then
  echo "terraform not found; install it with terraform/tools/terraform-install.sh" >&2
  exit 1
fi
if ! command -v terravision >/dev/null 2>&1; then
  echo "terravision not found; install it with: uv tool install --python 3.12 terravision" >&2
  exit 1
fi
if ! command -v dot >/dev/null 2>&1; then
  echo "dot not found; install Graphviz, e.g. sudo apt install graphviz or brew install graphviz" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
: "${DIAGRAM_DIR:=${ROOT}/terraform/.diagrams}"
: "${DIAGRAM_FORMATS:=png svg}"
mkdir -p "$DIAGRAM_DIR"
DIAGRAM_DIR="$(cd "$DIAGRAM_DIR" && pwd)"

if [ "$#" -eq 0 ]; then
  set -- "$ROOT"/terraform/envs/*/
fi

# Runs in a subshell so the EXIT trap removes this module's override and plan files.
# Bash ignores errexit in a function called from a condition, so the caller turns it off
# and the subshell turns it back on.
draw() (
  set -e
  dir="$(cd "$1" && pwd)"
  name="$(basename "$dir")"
  override="${dir}/backend_override.tf"
  if [ -e "$override" ]; then
    echo "${override} already exists; move it aside and rerun" >&2
    exit 1
  fi

  work="$(mktemp -d)"
  trap 'rm -rf "$work" "$override"' EXIT
  export TF_DATA_DIR="${dir}/.terraform-diagram"

  cat >"$override" <<EOF
terraform {
  backend "local" {
    path = "${work}/terraform.tfstate"
  }
}
EOF

  varfile=()
  if [ ! -f "${dir}/terraform.tfvars" ] && [ -f "${dir}/terraform.tfvars.example" ]; then
    varfile=(-var-file=terraform.tfvars.example)
  fi

  terraform -chdir="$dir" init -input=false -reconfigure -lockfile=readonly >/dev/null
  terraform -chdir="$dir" plan -input=false -lock=false ${varfile[@]+"${varfile[@]}"} -out="${work}/tfplan" >/dev/null
  terraform -chdir="$dir" show -json "${work}/tfplan" >"${work}/plan.json"
  terraform -chdir="$dir" graph >"${work}/graph.dot"

  # Run TerraVision in the temp dir so any scratch files it writes stay out of the repo.
  cd "$work"
  for format in $DIAGRAM_FORMATS; do
    terravision draw --source "$dir" --planfile plan.json --graphfile graph.dot \
      --format "$format" --outfile "${DIAGRAM_DIR}/${name}"
  done
)

status=0
for dir in "$@"; do
  echo "terravision: ${dir%/}"
  set +e
  draw "$dir"
  rc=$?
  set -e
  [ "$rc" -eq 0 ] || status=1
done
echo "diagrams: ${DIAGRAM_DIR}"
exit "$status"
