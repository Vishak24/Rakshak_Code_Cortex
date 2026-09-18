.PHONY: test build layer deploy deploy-dry deploy-infra warm seed verify demo clean

API_BASE ?= https://aksdwfbnn5.execute-api.ap-south-1.amazonaws.com

test:
	python3 -m pytest tests -q

build: test
	bash backend/build/build_zips.sh

layer:
	python3 deploy/deploy.py --layer --dry-run
	python3 deploy/deploy.py --layer

deploy: build
	python3 deploy/deploy.py

deploy-dry: build
	python3 deploy/deploy.py --dry-run

deploy-infra: build
	python3 deploy/deploy.py --create-infra

warm:
	@curl -s -o /dev/null "$(API_BASE)/health"
	@curl -s -o /dev/null "$(API_BASE)/patrols"
	@curl -s -o /dev/null -X POST "$(API_BASE)/predict" -H 'Content-Type: application/json' -d '{"pincode":"600017"}'
	@curl -s -o /dev/null "$(API_BASE)/dashboard/snapshot"
	@echo "warmed"

seed:
	AWS_PROFILE=agent-toolkit python3 scripts/seed_demo_state.py --apply --clear-active

verify:
	bash deploy/verify.sh $(API_BASE)

demo: warm
	bash scripts/launch_demo.sh

clean:
	rm -rf backend/build/dist backend/build/layer/python .pytest_cache **/__pycache__
