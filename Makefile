SHELL := /bin/bash
.SHELLFLAGS := -euo pipefail -c
.DEFAULT_GOAL := help

ENV ?= dev
TF_DIR := terraform/envs/$(ENV)
PYTHON := .venv/bin/python
TF_ENV := . scripts/tf-env.sh $(ENV)
EVAL_LIMIT ?= 8
QUESTION ?= Per the Azure Security Benchmark, what should I enforce for Key Vault? Which ASB version is current, and what's the latest azurerm provider version I should pin in Terraform?

.PHONY: help venv init plan deploy teardown search agent smoke demo eval eval-full lint validate check

help: ## List targets
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-10s %s\n", $$1, $$2}'

venv: ## Create .venv with the Python dependencies
	python3 -m venv .venv
	$(PYTHON) -m pip install --quiet --upgrade pip
	$(PYTHON) -m pip install --quiet -r scripts/requirements.txt

init: ## terraform init for ENV against the remote state
	terraform -chdir=$(TF_DIR) init -input=false -backend-config=backend.hcl

plan: ## terraform plan for ENV (local terraform.tfvars)
	terraform -chdir=$(TF_DIR) plan -input=false

deploy: ## Run the deploy workflow for ENV on the current branch
	gh workflow run deploy.yml --ref "$$(git branch --show-current)" -f target=$(ENV)

teardown: ## Run the teardown workflow for ENV (needs CONFIRM=ENV)
	@[[ "$(CONFIRM)" == "$(ENV)" ]] || { echo "Set CONFIRM=$(ENV) to tear down $(ENV)"; exit 1; }
	gh workflow run teardown.yml -f environment=$(ENV) -f confirm=$(ENV)

search: ## Fetch, upload and index the corpus in ENV
	$(TF_ENV) && search/scripts/publish.sh all

agent: ## Publish a new agent version in ENV
	$(TF_ENV) && $(PYTHON) agents/scripts/deploy_agent.py

smoke: ## Health, Functions and one multi-tool answer with a trace_id
	$(TF_ENV) && \
	curl -fsS --retry 12 --retry-delay 5 --retry-all-errors "$$SERVING_URL/health" | jq -c . && \
	curl -fsS --retry 3 "$$FUNCTION_BASE_URL/asb/version" | jq -c . && \
	curl -fsS --retry 3 "$$REGISTRY_FUNCTION_BASE_URL/terraform/azurerm/versions" | jq -c '{latest}' && \
	curl -fsS -o /dev/null "$$SERVING_URL/" && \
	jq -n --arg q "$(QUESTION)" '{question: $$q}' \
	  | curl -fsS --max-time 180 -H 'Content-Type: application/json' -d @- "$$SERVING_URL/api/ask" \
	  | jq -e '{status, tool_path, trace_id, answer: .answer[0:300]} | select(.status == "completed" and .trace_id != null)'

demo: ## Ask the agent QUESTION directly and print the tool calls
	$(TF_ENV) && $(PYTHON) agents/scripts/run_demo.py --question "$(QUESTION)"

eval: ## Foundry eval on EVAL_LIMIT golden rows, gated by eval/thresholds.json
	$(TF_ENV) && \
	$(PYTHON) eval/scripts/export-foundry-dataset.py --limit $(EVAL_LIMIT) && \
	$(PYTHON) eval/scripts/run-foundry-eval.py --dataset-name csa-golden-smoke --gate eval/thresholds.json

eval-full: ## Foundry eval on the full golden set with agent evaluators (no gate)
	$(TF_ENV) && \
	$(PYTHON) eval/scripts/export-foundry-dataset.py && \
	$(PYTHON) eval/scripts/run-foundry-eval.py --dataset-name csa-golden-full --with-agent-evaluators

lint: ## shellcheck, ruff, actionlint, golden set schema
	shellcheck $$(git ls-files '*.sh')
	ruff check $$(git ls-files '*.py')
	actionlint
	python3 eval/scripts/validate-golden-set.py --min-rows 50

validate: ## terraform fmt and validate for every root
	terraform fmt -check -recursive terraform
	for dir in terraform/envs/* terraform/bootstrap/github-oidc; do \
	  terraform -chdir=$$dir init -backend=false -input=false >/dev/null && terraform -chdir=$$dir validate; \
	done

check: lint validate ## Everything CI runs before Azure
