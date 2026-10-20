---
name: terraform-env-docs
description: "Use when changing anything under terraform/envs/ or terraform/modules/, or when writing an environment README."
---

Every root module in `terraform/envs/<cloud>-<id>/` has a `README.md` built from [`terraform/envs/README.template.md`](../../../terraform/envs/README.template.md), the single source of truth for its headings, provider keys, and changelog line format. `terraform/scripts/env-docs-check.sh` enforces it: locally as the `env-docs-check` prek hook, and in CI as the `env-docs` job. Treat its output as the definition of done.

## Steps

1. **Find the affected envs.** Run `terraform/scripts/env-docs-check.sh --list-affected <changed files>`. A child module change affects every env whose `.tf` files reference `"../../modules/<cloud>/<name>"`; test-only and docs-only changes affect none. Done when you have the list (it may be empty; then skip to step 5).

2. **Update each affected env's README.** Create it from the template if it is missing. Source each value from the configuration, never from memory:
   - **Account / Subscription / Project:** the `provider` block in the env's `versions.tf` (`allowed_account_ids`, `subscription_id`, `project`); the directory suffix matches it.
   - **Region:** the `provider` block, or the env's `main.tf` locals and module arguments, falling back to the child module's variable default.
   - **VPC / VNet:** the name the child module gives it (`"${var.cluster_name}-vnet"` and so on), or, for an AWS VPC ID that only exists after apply, "Created by this configuration (`module.<name>.vpc_id`)".
   - **Purpose:** rewrite it only if the change alters what the environment is for.

3. **Redraw the diagram when resources are added, removed, or rewired.** Keep it a `flowchart` of the resources the env actually creates, including only those enabled by the env's arguments (a resource behind a `count`/flag that defaults off stays out).

4. **Add one changelog line at the top of `# Most Recent Changes`:** `MM/DD/YYYY - <Summary> (#TBD - <Author>)`, with today's date, a past-tense summary of the change in under ten words (`Updated node instance type`), and `<Author>` set to `$TF_DOCS_AUTHOR`, or `git config user.name` when that is unset. Leave existing lines as they are.

5. **Run the check.** `prek run --files <changed files and READMEs>` must show `env docs check ... Passed`. Fix the README until it does.

6. **Commit, push, and open the PR** (use the `pr` skill for the body).

7. **Fill in the PR number.** In every README line this PR added, replace `#TBD` with the PR number from `gh pr create`, commit `docs: add PR number to changelog`, and push. The CI `env-docs` job fails on any `#TBD` and on an entry without this PR's number. Done when that job passes.
