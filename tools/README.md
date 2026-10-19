# Developer tools

Installers for developer CLIs used across the repository. Each script runs on Linux or macOS (amd64 or arm64), downloads the official GitHub release, verifies its SHA-256 checksum, and installs to `INSTALL_DIR` (default: `~/.local/bin`) without `sudo`.

| Script | Purpose |
| --- | --- |
| `prek-install.sh` | Install [prek](https://github.com/j178/prek), a faster drop-in replacement for pre-commit. On Linux it installs the statically linked musl build, which runs on any distro. Version set by `PREK_VERSION` (default: `latest`). |
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

prek reads the existing `.pre-commit-config.yaml`, so it runs the same hooks as pre-commit (Terraform, yamllint, Helm, and chart-testing; see `terraform/README.md` and `helm/README.md`). Use either tool; you don't need both. The hooks still call local binaries such as `terraform`, `tflint`, `helm`, and `ct`, so install those with their scripts first.

| pre-commit | prek |
| --- | --- |
| `pre-commit install` | `prek install --force` |
| `pre-commit run --all-files` | `prek run --all-files` |
| `pre-commit run --files <files>` | `prek run --files <files>` |
| `pre-commit run ct-install --hook-stage manual` | `prek run ct-install --stage manual` |

If you already ran `pre-commit install`, use `prek install --force`. Without `--force`, prek moves pre-commit's Git hook to `.git/hooks/pre-commit.legacy` and runs it after its own, so every hook runs twice. To switch back to pre-commit, run `prek uninstall` and then `pre-commit install`.
