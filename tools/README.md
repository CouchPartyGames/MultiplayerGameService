# Developer tools

Installers for developer CLIs used across the repository. Each script runs on Linux or macOS (amd64 or arm64), downloads the official GitHub release, verifies its SHA-256 checksum, and installs to `INSTALL_DIR` (default: `~/.local/bin`) without `sudo`.

| Script | Purpose |
| --- | --- |
| `prek-install.sh` | Install [prek](https://github.com/j178/prek), the hook runner this repository uses in place of pre-commit. On Linux it installs the statically linked musl build, which runs on any distro. Version set by `PREK_VERSION` (default: `latest`). |
| `yamlfmt-install.sh` | Install [yamlfmt](https://github.com/google/yamlfmt). Version set by `YAMLFMT_VERSION` (default: `latest`). |

```bash
# Install the latest release
./tools/prek-install.sh

# Install a specific version (the leading "v" is optional)
PREK_VERSION=0.5.6 ./tools/prek-install.sh

# Install somewhere other than ~/.local/bin
INSTALL_DIR=/usr/local/bin ./tools/prek-install.sh
```

If `INSTALL_DIR` is not on `PATH`, the script prints a note. Add the directory to your shell profile.

## Pre-commit hooks with prek

The repository's hooks run with prek, not pre-commit. They are split across two configs:

| Config | Hooks | Docs |
| --- | --- | --- |
| `.pre-commit-config.yaml` | yamllint, Helm, and chart-testing | `helm/README.md` |
| `terraform/.pre-commit-config.yaml` | TFLint, `terraform fmt`, `terraform validate`, and `terraform test` | `terraform/README.md` |
| `digger/.pre-commit-config.yaml` | yamllint and yamlfmt | `digger/README.md` |

prek finds the nested config automatically (workspace mode) and runs its hooks from `terraform/`. Plain pre-commit reads only the root config, so it would silently skip the Terraform hooks. The hooks call local binaries such as `terraform`, `tflint`, `helm`, and `ct`, so install those with their scripts first.

Run these commands from the repository root:

| Task | Command |
| --- | --- |
| Install the Git hook, once per clone | `prek install` |
| Run every hook on all files | `prek run --all-files` |
| Run hooks on specific files | `prek run --files <files>` |
| Run only the Terraform hooks | `prek run terraform/ --all-files` |
| Run one hook from the Terraform config | `prek run terraform:terraform_fmt --all-files` |
| Run the manual chart install test | `prek run ct-install --stage manual` |
| List discovered configs and hooks | `prek list` |
| Skip the Terraform hooks for one commit | `PREK_SKIP=terraform/ git commit` |

After adding or moving a config, stage it and run `prek run --all-files --refresh` so prek picks it up.

If you previously ran `pre-commit install`, run `prek install --force` instead. Without `--force`, prek moves pre-commit's Git hook to `.git/hooks/pre-commit.legacy` and runs it after its own, so the root hooks run twice.
