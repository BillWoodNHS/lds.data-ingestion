# Convenience targets; each is a thin wrapper so the same commands run locally and in pipelines.
ENV ?= dev

.PHONY: setup validate generate check local build deploy-dry-run

setup:            ## create .venv and install the engine, dbt and the Snowflake CLI
	git submodule update --init
	python3 -m venv .venv && . .venv/bin/activate && pip install -r requirements.txt
	pipx install "snowflake-cli>=3.34,<4" || echo "Install pipx to get the Snowflake CLI (needed only to deploy)"

validate:         ## validate all manifests
	lds-engine validate

generate:         ## regenerate snowflake/ and models/lds_ingest/ from the manifests
	lds-engine generate

check:            ## fail if generated files are out of date
	lds-engine check

local:            ## full local run on DuckDB (no Snowflake)
	scripts/local.sh

build:            ## render deployable SQL for ENV into build/ENV
	lds-engine build --env $(ENV)

deploy-dry-run:   ## show what scripts/deploy.sh would run for ENV
	scripts/deploy.sh $(ENV) --dry-run
