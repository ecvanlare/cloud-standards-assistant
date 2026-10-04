SHELL := /bin/bash
.SHELLFLAGS := -euo pipefail -c
.DEFAULT_GOAL := help

.PHONY: help lint validate check

help: ## List targets
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-10s %s\n", $$1, $$2}'

lint: ## shellcheck, ruff, actionlint, golden set schema
	shellcheck $$(git ls-files '*.sh')
	ruff check $$(git ls-files '*.py')
	actionlint
	python3 eval/scripts/validate-golden-set.py --min-rows 50

validate: ## terraform fmt and validate for every root
	terraform fmt -check -recursive terraform
	for dir in terraform/envs/*; do \
	  terraform -chdir=$$dir init -backend=false -input=false >/dev/null && terraform -chdir=$$dir validate; \
	done

check: lint validate ## Everything CI runs before Azure
