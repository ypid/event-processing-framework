# SPDX-FileCopyrightText: 2021 Robin Schneider <robin.schneider@geberit.com>
#
# SPDX-License-Identifier: AGPL-3.0-only

AGGREGATOR_CONFIG_FILES := config/prod_role_aggregator.yaml config/prod_module_*.yaml config/settings.yaml config/transform_*.yaml
AGENT_CONFIG_FILES := config/prod_role_agent.yaml config/prod_module_*.yaml config/settings.yaml

# Generate docs as part of tests to have changes in the component graph in the diff.
# As the component graph is based on wildcards against a work in progress
# naming schema, such changes are difficult to predict otherwise.
.PHONY: test
test: validate test-unit test-integration docs test-prevent-organization-internals-leak
	@echo "** All quick tests passed. Consider running 'make test-extended' next."

.PHONY: test-all
test-all: test test-extended

.PHONY: test-extended
test-extended: test-reuse-spec
	@echo "** All extended tests passed."

.PHONY: test-reuse-spec
test-reuse-spec:
	@reuse lint

.PHONY: test-prevent-organization-internals-leak
test-prevent-organization-internals-leak:
	command -v find_organization_internal_strings >/dev/null 2>&1 && find_organization_internal_strings

.PHONY: validate
validate: validate-aggregator validate-agents
	@echo "** Validation passed."

.PHONY: validate-aggregator
validate-aggregator: $(AGGREGATOR_CONFIG_FILES)
	@vector validate --no-environment $^

.PHONY: validate-agents
validate-agents: $(AGENT_CONFIG_FILES)
	vector validate --no-environment $^

.PHONY: test-unit
test-unit: tests/unit/*.yaml config/transform_*.yaml
	vector test $^
	@echo "** Unit tests passed."

.PHONY: test-unit-debug
test-unit-debug: tests/unit/*.yaml config/transform_*.yaml
	vector test $^ | sed --quiet --regexp-extended 's/^\s+output: \{/{/p;' | head -n 1 | gron --stream

.PHONY: test-integration
test-integration: tests/integration/test_setup.yaml config/settings.yaml config/transform_*.yaml
	@rm -rf tests/integration/output /tmp/vector-config_stdout.log
	@mkdir -p tests/integration/output
	@echo vector --quiet --config $^
	@jq --compact-output '.' tests/integration/input/*.json | TEST_MODE=true vector --quiet --color always --config $^ > /tmp/vector-config_stdout.log || vector --color always --config $^
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
.PHONY: sort-input-files
sort-input-files:
	for file in ./tests/integration/input/*.json; do \
		shuf --input-range 10000000000000000-99999999999999999 --head-count 100 | jq --null-input --raw-input --sort-keys --slurpfile stream "$$file" '$$stream[] | . * {"event": {"sequence": (.event.sequence // (input|tonumber)) }}' > /tmp/input_with_updated_event_sequence.json; \
		mv /tmp/input_with_updated_event_sequence.json "$$file"; \
	done

.PHONY: docs
docs: docs/aggregator.puml docs/agents.puml

docs/aggregator.puml: ./docs/tools/gen_component_diagram $(AGGREGATOR_CONFIG_FILES)
	"$<" --config $(AGGREGATOR_CONFIG_FILES) > "$@"

docs/agents.puml: ./docs/tools/gen_component_diagram $(AGENTS_CONFIG_FILES)
	"$<" --config $(AGENT_CONFIG_FILES) > "$@"

.PHONY: install-aggregator
install-aggregator: $(AGGREGATOR_CONFIG_FILES)
	rm $(DESTDIR)/etc/vector/prod -rf
	install -d $(DESTDIR)/etc/vector/prod/config.d
	install -m 0644 $^ $(DESTDIR)/etc/vector/prod/config.d
	rsync --ignore-existing deploy/env_file /etc/default/vector
	chmod 0640 /etc/default/vector
	install --owner=vector --group=adm --mode 0750 --directory /var/log/vector

# On Windows, install with:
# & "C:/Program Files/Vector/bin/vector.exe" service install --config-dir "C:/Program Files/Vector/config/prod/config.d"
.PHONY: install-agent
install-agent: $(AGENT_CONFIG_FILES)
	rm $(DESTDIR)/tmp/vector-agent -rf
	install -d $(DESTDIR)/tmp/vector-agent
	install --mode 0644 $^ $(DESTDIR)/tmp/vector-agent
