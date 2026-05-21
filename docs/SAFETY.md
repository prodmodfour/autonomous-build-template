# Safety Notes

This template is designed to reduce the risk of autonomous build mistakes.

## Built-in safety behaviours

The build loop:

* refuses to start with a dirty working tree
* refuses uncustomised templates by default
* locks to avoid concurrent runs
* checks upstream before and after each cycle
* pushes each successful cycle's commit by default unless `--no-push` is passed
* stops if the agent leaves uncommitted changes
* stops if no commit is produced
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

## Cloud safety

Do not add automated cloud mutation commands unless a project specifically requires it and has a clearly documented safety model.

Risky commands include:

* `terraform apply`
* `terraform destroy`
* `terraform import`
* cloud deploy commands
* destructive CLI operations
