SHELL := /bin/bash

.PHONY: preflight install localstack-up kind-up tf-apply tf-destroy deploy flows down clean status

preflight:
	bash scripts/00-preflight.sh

install:
	bash scripts/01-install-deps.sh

localstack-up:
	bash scripts/02-start-localstack.sh

tf-apply:
	bash scripts/03-terraform-apply.sh

kind-up:
	bash scripts/04-create-kind-cluster.sh

deploy:
	bash scripts/05-deploy-stack.sh

flows:
	bash scripts/06-register-flows.sh

status:
	bash scripts/status.sh

tf-destroy:
	cd terraform && terraform destroy -auto-approve

down:
	bash scripts/99-teardown.sh

# Full run, phase by phase. Intended to be run interactively the first time
# so you can catch and report back any failure before the next phase starts.
up: preflight install localstack-up tf-apply kind-up deploy flows
	@echo ""
	@echo "=== Stack is up. Run 'make status' for endpoints. ==="
