# SPDX-FileCopyrightText: 2021 Robin Schneider <robin.schneider@geberit.com>
#
# SPDX-License-Identifier: AGPL-3.0-only

SHELL := /bin/bash -o nounset -o pipefail -o errexit
MAKEFLAGS += --no-builtin-rules
.SUFFIXES:

AGENT_CONFIG_FILES            ?= config/settings.yaml config/prod_module_*.yaml config/prod_role_agent.yaml
AGENT_K8S_CONFIG_FILES        ?= config/settings.yaml config/prod_module_*.yaml config/prod_role_agent_k8s.yaml config/prod_role_agent_sink.yaml
ENTRANCE_CONFIG_FILES         ?= config/settings.yaml config/prod_module_*.yaml config/prod_role_entrance_and_pull.yaml config/prod_role_entrance.yaml
PULL_CONFIG_FILES             ?= config/settings.yaml config/prod_module_*.yaml config/prod_role_entrance_and_pull.yaml config/prod_role_pull.yaml
AGGREGATOR_CONFIG_FILES       ?= config/settings.yaml config/prod_module_*.yaml config/prod_role_aggregator.yaml config/transform_*.yaml

# Entrance and pull might share components so they cannot be in be loaded into the same vector test run.
UNIT_TEST_CONFIG_FILES ?= tests/unit/*.yaml $(AGGREGATOR_CONFIG_FILES) $(ENTRANCE_CONFIG_FILES)

INTEGRATION_TEST_CONFIG_FILES ?= config/settings.yaml tests/integration/test_setup.yaml config/transform_*.yaml

# This Makefile supports overwriding its targets, see
# https://stackoverflow.com/questions/11958626/make-file-warning-overriding-commands-for-target/49804748
# Because of this the default target has to be set explicitly here.
default: test-all

# All tests that are quick should run here.
# Generate docs as part of tests to have changes in the component graph in the diff.
# As the component graph is based on wildcards against a work in progress
# naming schema, such changes are difficult to predict otherwise.
.PHONY: test-default
test-default: validate test-public test-unit test-integration test-initialize_internal_project docs

.PHONY: test-public
test-public: test-prevent-organization-internals-leak

.PHONY: test-all-default
test-all-default: test

# Only print software versions of relevant software used in the framework.
.PHONY: print-software-versions-default
print-software-versions-default:
	@vector --version
	@yq --version
	@pre-commit --version

.PHONY: test-pre-commit
test-pre-commit:
	@pre-commit run --all-files

.PHONY: test-initialize_internal_project
test-initialize_internal_project:
	if test -r codemeta.json && yq --output-format=json --exit-status eval '.name == "Event processing framework"' codemeta.json >/dev/null; then \
		rm -rf tests/initialize_internal_project && \
		git -c init.defaultBranch=main init tests/initialize_internal_project && \
		git -C tests/initialize_internal_project config user.email "you@example.com" && \
		git -C tests/initialize_internal_project config user.name "Your Name" && \
		helpers/initialize_internal_project tests/initialize_internal_project && \
		git -C tests/initialize_internal_project checkout -b feat/test && \
		git -C tests/initialize_internal_project add . && \
		git -C tests/initialize_internal_project commit -m "Initial commit" && \
		$(MAKE) --directory tests/initialize_internal_project test \
	; fi

.PHONY: test-prevent-organization-internals-leak-default
test-prevent-organization-internals-leak-default:
	command -v find_organization_internal_strings >/dev/null 2>&1 && find_organization_internal_strings || :

.PHONY: validate-default
validate-default: validate-agents validate-agent-k8s validate-entrance validate-pull validate-aggregator
	@echo "** Validation passed."

.PHONY: validate-agents-default
validate-agents-default: $(AGENT_CONFIG_FILES)
	vector validate --no-environment $^

validate-agent-k8s: export VECTOR_AGENT_VECTOR_SINK_ADDRESS = dummy
validate-agent-k8s: export VECTOR_TLS_CA = dummy
validate-agent-k8s: export VECTOR_TLS_CRT = dummy
validate-agent-k8s: export VECTOR_TLS_KEY = dummy

.PHONY: validate-agent-k8s-default
validate-agent-k8s-default: $(AGENT_K8S_CONFIG_FILES)
	vector validate --no-environment $^

validate-entrance-default: export VECTOR_HOSTNAME = dummy-hostname

.PHONY: validate-entrance-default
validate-entrance-default: $(ENTRANCE_CONFIG_FILES)
	@vector validate --no-environment $^

validate-pull-default: export VECTOR_HOSTNAME = dummy-hostname
validate-pull-default: export VECTOR_AWS_SES_SQS_QUEUE_URL = dummy-sqs-queue

.PHONY: validate-pull-default
validate-pull-default: $(PULL_CONFIG_FILES)
	@vector validate --no-environment $^

validate-aggregator-default: export VECTOR_HOSTNAME = dummy-hostname
validate-aggregator-default: export ELASTICSEARCH_URL = dummy-url
validate-aggregator-default: export ELASTICSEARCH_USER = dummy-username
validate-aggregator-default: export ELASTICSEARCH_PASSWORD = dummy-password

.PHONY: validate-aggregator-default
validate-aggregator-default: $(AGGREGATOR_CONFIG_FILES)
	@vector validate --no-environment $^

test-unit%: export VECTOR_HOSTNAME = dummy-hostname
test-unit%: export ELASTICSEARCH_URL = dummy-url
test-unit%: export ELASTICSEARCH_USER = dummy-username
test-unit%: export ELASTICSEARCH_PASSWORD = dummy-password

.PHONY: test-unit-default
# TODO: Using build/unit_test.yaml instead of $(UNIT_TEST_CONFIG_FILES) is a
# performance improvement workaround. There must be a better way that is also
# faster.
test-unit-default: build/unit_test.yaml
	time vector test $^
	@echo "** Unit tests passed."

.PHONY: test-unit-debug-default
test-unit-debug-default: $(UNIT_TEST_CONFIG_FILES)
	time vector test $^ | sed --quiet --regexp-extended 's/^\s+\{/{/p;' | head -n 1 | gron --stream

.PHONY: test-integration-default
test-integration-default: $(INTEGRATION_TEST_CONFIG_FILES)
	@rm -rf tests/integration/output /tmp/vector-config_stdout.log
	@mkdir -p tests/integration/output
	@echo vector --quiet --config $(shell echo $^ | sed --regexp-extended 's/\s+/,/g;')
	@jq --compact-output '.' tests/integration/input/*.json | TEST_MODE=true vector --quiet --color always --config $(shell echo $^ | sed --regexp-extended 's/\s+/,/g;') > /tmp/vector-config_stdout.log || vector --color always --config $(shell echo $^ | sed --regexp-extended 's/\s+/,/g;')
	@grep -v '^{' /tmp/vector-config_stdout.log || :
	@grep '^{' /tmp/vector-config_stdout.log | ./tests/tools/ndjson2multiple_files '"dataset_" + (.event.dataset // "unknown") + "__sequence_" + (.event.sequence|tostring)' tests/integration/output
	@git add tests/integration/output
	@if git diff --cached --quiet --exit-code HEAD -- tests/integration/output; then \
		echo "** Integration tests passed."; \
	else \
		echo "** Integration tests failed. Please review the changes below and decide if they are OK."; \
	fi
	@git --no-pager diff --cached --exit-code -- tests/integration/output

# * Random number and one file per module so it works with multiple developers and
#   distributed setups.
# * Big number so you can search for it.
# jq somehow overwrites `.offset`. Some wired bug I don’t want to dig down.
# Instead, the below shuf | jq stuff shall be rewritten in Python.
# Work was started in ./helpers/integration_test_input_helper
.PHONY: sort-input-files-default
sort-input-files-default:
	for file in $$(find ./tests/integration/input/ -type f -iname '*.json'); do \
		shuf --input-range 100000000000-999999999999 --head-count 100 | jq --null-input --raw-input --sort-keys --slurpfile stream "$$file" '$$stream[] | . * {"event": {"sequence": (.event.sequence // (input|tonumber)) }}' > /tmp/input_with_updated_event_sequence.json; \
		mv /tmp/input_with_updated_event_sequence.json "$$file"; \
	done


define generate_dot_file
	vector graph --config $(shell echo $(1) | sed --regexp-extended 's/\s+/,/g;')
endef
docs/:
	mkdir -p docs/
docs/agent.dot: $(AGENT_CONFIG_FILES) | docs/
	$(call generate_dot_file,$^) > "$@"

docs/agent_k8s.dot: export VECTOR_AGENT_VECTOR_SINK_ADDRESS = dummy
docs/agent_k8s.dot: export VECTOR_TLS_CA = dummy
docs/agent_k8s.dot: export VECTOR_TLS_CRT = dummy
docs/agent_k8s.dot: export VECTOR_TLS_KEY = dummy
docs/agent_k8s.dot: $(AGENT_K8S_CONFIG_FILES) | docs/
	$(call generate_dot_file,$^) > "$@"

docs/entrance.dot: export VECTOR_HOSTNAME = dummy-hostname
docs/entrance.dot: $(ENTRANCE_CONFIG_FILES) | docs/
	$(call generate_dot_file,$^) > "$@"

docs/pull.dot: export VECTOR_HOSTNAME = dummy-hostname
docs/pull.dot: export VECTOR_AWS_SES_SQS_QUEUE_URL = dummy-sqs-queue
docs/pull.dot: $(PULL_CONFIG_FILES) | docs/
	$(call generate_dot_file,$^) > "$@"

docs/aggregator.dot: export VECTOR_HOSTNAME = dummy-hostname
docs/aggregator.dot: export ELASTICSEARCH_URL = dummy-url
docs/aggregator.dot: export ELASTICSEARCH_USER = dummy-username
docs/aggregator.dot: export ELASTICSEARCH_PASSWORD = dummy-password
docs/aggregator.dot: $(AGGREGATOR_CONFIG_FILES) | docs/
	$(call generate_dot_file,$^) > "$@"

.PHONY: docs-default
docs-default: docs/agent.dot docs/agent_k8s.dot docs/entrance.dot docs/pull.dot docs/aggregator.dot
.PHONY: docs-full-default
docs-full-default: docs/agent.svg docs/entrance.svg docs/pull.svg docs/aggregator.svg


.PHONY: run-agent-default
run-agent-default: $(AGENT_CONFIG_FILES)
	vector --color always --config $(shell echo $^ | sed --regexp-extended 's/\s+/,/g;')

.PHONY: run-entrance-default
run-entrance-default: $(ENTRANCE_CONFIG_FILES)
	vector --color always --config $(shell echo $^ | sed --regexp-extended 's/\s+/,/g;')

.PHONY: run-pull-default
run-pull-default: $(PULL_CONFIG_FILES)
	vector --color always --config $(shell echo $^ | sed --regexp-extended 's/\s+/,/g;')

.PHONY: run-aggregator-default
run-aggregator-default: $(AGGREGATOR_CONFIG_FILES)
	vector --color always --config $(shell echo $^ | sed --regexp-extended 's/\s+/,/g;')


define merge_yaml_and_add_info_header
	git_remote="$(CI_PROJECT_URL)"; \
	if [[ -z "$$git_remote" ]]; then \
		git_remote="$$(git remote get-url origin)"; \
		if [[ "$git_remote" == http*"@"* ]]; then echo "Password/basic auth credentials potentially contained in git remote URL. Either remove credentials from URL or change merge_yaml_and_add_info_header in the Makefile." >&2; exit 1; fi \
	fi; \
	yq eval-all "(. | ... comments=\"\") as \$$item ireduce ({}; . * \$$item) | . head_comment=\"This file was generated. Make your changes at the source instead. Version: $(shell git describe --always --dirty). Ref: $$git_remote\" " $(1)
endef
build/:
	mkdir -p build/
build/agent.yaml: $(AGENT_CONFIG_FILES) | build/
	$(call merge_yaml_and_add_info_header,$^) > "$@"
build/agent_k8s.yaml: $(AGENT_K8S_CONFIG_FILES) | build/
	$(call merge_yaml_and_add_info_header,$^) > "$@"
build/entrance.yaml: $(ENTRANCE_CONFIG_FILES) | build/
	$(call merge_yaml_and_add_info_header,$^) > "$@"
build/pull.yaml: $(PULL_CONFIG_FILES) | build/
	$(call merge_yaml_and_add_info_header,$^) > "$@"
build/aggregator.yaml: $(AGGREGATOR_CONFIG_FILES) | build/
	$(call merge_yaml_and_add_info_header,$^) > "$@"
build/unit_test.yaml: $(UNIT_TEST_CONFIG_FILES) | build/
	$(call merge_yaml_and_add_info_header,$^) > "$@"

.PHONY: build-default
build-default: build/agent.yaml build/agent_k8s.yaml build/entrance.yaml build/pull.yaml build/aggregator.yaml


.PHONY: clean-default
clean-default:
	rm -rf ./build ./docs/*.dot ./docs/*.svg ./tests/initialize_internal_project

# On Windows, install with:
# & "C:/Program Files/Vector/bin/vector.exe" service install --config-dir "C:/Program Files/Vector/config/prod/config.d"
.PHONY: install-agent-default
install-agent-default: $(AGENT_CONFIG_FILES)
	rm $(DESTDIR)/tmp/vector-agent -rf
	install -d $(DESTDIR)/tmp/vector-agent
	install --mode 0644 $^ $(DESTDIR)/tmp/vector-agent

.PHONY: install-aggregator-default
install-aggregator-default: $(AGGREGATOR_CONFIG_FILES)
	rm $(DESTDIR)/etc/vector/aggregator -rf
	install -d $(DESTDIR)/etc/vector/aggregator/config.d
	install -m 0644 $^ $(DESTDIR)/etc/vector/aggregator/config.d
	rsync --ignore-existing deploy/env_file /etc/default/vector
	chmod 0640 /etc/default/vector
	install --owner=vector --group=root --mode 0750 --directory /var/log/vector

%: %-default
	@true

%.svg: %.dot
	dot "$<" -Tsvg > "$@"
