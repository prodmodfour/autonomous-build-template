# Safety Notes

This template is designed to reduce the risk of autonomous build mistakes.

## Built-in safety behaviours

The build loop:

* refuses to start with a dirty working tree
* refuses uncustomised templates by default
* locks to avoid concurrent runs
* checks upstream before and after each cycle, while allowing branches that are already ahead of upstream
* can select an existing branch with `--branch` or create one with `--create-branch`
* pushes each successful cycle's commit by default unless `--no-push` is passed
* sets upstream on first push when the current branch has no upstream but `origin` exists
* restores failed agent runs back to the pre-run clean tree before automatic retry or ticket-splitting recovery
* stops if a failed run cannot be safely restored, or if a successful agent/recovery run leaves uncommitted changes
* splits the current ticket after token/context-length failures and retries other agent failures after the configured delay
* stops if no commit is produced by a successful implementation cycle
* checks only the top-level automation status
* delegates agent invocation to a wrapper script

## File safety

The default checks reject obvious:

* real `.env` files
* Terraform state
* Terraform plan files
* non-example `.tfvars`
* private keys
* access-key-looking values
* suspicious secret assignments in source files

## Limitations

These checks are not a replacement for human review.

Before making a repo public, manually review:

* commits
* README
* docs
* configuration files
* examples
* logs
* generated files
* CI workflows

## Remote repository creation safety

`scripts/create-remote-repo.sh` can create GitHub or GitLab repositories using the authenticated `gh` or `glab` CLI. It requires a clean working tree for non-dry runs, refuses to overwrite an existing local remote unless `--replace-remote` is passed, and supports `--dry-run` for previewing commands.

Review visibility (`private`, `public`, or `internal`) before creating a repository, especially before pushing template-derived or newly generated code.

## Cloud safety

Do not add automated cloud mutation commands unless a project specifically requires it and has a clearly documented safety model.

Risky commands include:

* `terraform apply`
* `terraform destroy`
* `terraform import`
* cloud deploy commands
* destructive CLI operations
