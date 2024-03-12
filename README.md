<!--
SPDX-FileCopyrightText: 2021 Robin Schneider <robin.schneider@geberit.com>

SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Event processing framework

This is a opinionated event processing framework with focus on log parsing that is implemented
using [vector.dev](https://vector.dev/). Logstash has been used previously for the task.

## Terminology

* Event: A log "line" or set of metrics. Events always have a timestamp from when they originate attached to them.
* Host: Device from which events originate/are emitted. It does not necessarily have to have an IP address. Think about sensors that are attached via a bus to a controller that than has an IP address. In this example, the sensor would be the host.
* Observer: As defined by ECS. The controller from the example above is an "observer".
* Agent: A program on a host shipping events to entrance (if in use) or directly to the aggregator. The agent could also run on the observer if the host is unsuitable/undesirable to run the agent. Corresponds to the Vector agent role, see below.
* Entrance: A program on a dedicated server that provides the interface for third parties to send logs to. It is the first component of the log collection system. Corresponds to the Vector entrance role, see below.
* Aggregator: A program on a dedicated server that reads, parses, enriches and forwards events (usually to a search engine for analysis). Corresponds to the Vector aggregator role, see below.
* Untrusted field: A unvalidated field from a host.
* Trusted field: A field based on data from the aggregator or a validated untrusted field.

## Design principles

* DRY (don't repeat yourself).

  Adding support for additional log types should only require
  to implement the specific bits of that type, nothing more.
  This is necessary to keep it maintainable even with a high number of
  supported log types.

* Modular.

  The implementation should be contained in a module to make it easy to share
  or keep it private while sharing other parts.

* Trustworthy events.

  Events from hosts are considered untrusted. This is because in the case of a
  compromise, systems could send faked events, possibly under the name of other
  hosts.

  Untrusted fields should be validated against other sources and
  warnings/errors should be included in the parsed events to help analysts to
  recognize faked data.

* Based on the [Elastic Common Schema (ECS)](https://www.elastic.co/what-is/ecs).

* Robustness.

* Processing is tested.

  The unit testing feature of Vector for configuration is used heavily and is the preferred way of testing.

  A second option for testing (integration testing) is supported by the
  framework. This comes in handy to avoid to have to copy logs of fields to
  code. Instead, git diff and commit can be used to "accept" a test output.

  Integration tests were historically needed because of issues with Vector when
  unit testing across multiple components.

## Differences to logstash-config-integration-testing

This framework is based on the experience gained with
[logstash-config-integration-testing](https://github.com/ypid/logstash-config-integration-testing)
The following noticeable differences exist:

* Faster tests. Only needs one second to run, compared to 1+ minute with Logstash. It could
  run in 400 milliseconds. What makes it slow is not vector, but the
  conversion from NDJSON to gron because for each line, a separate gron process
  has to be invoked currently.

* Integration test output is converted to gron for easy diffing. Before ECS,
  nested fields were not so common. Now that we make heavy use of nested
  fields, diffs of nested fields have to be readable. This is achieved by gron
  which includes the full path of each field in the same line.

* All log inputs are JSON in the integration testing. Raw log lines are not
  supported. Reasons: Every input event has a unique `event.sequence` that is
  used as ID to match an event input with the output event it may generated.
  A second reason is that the `event.module` field is no longer derived from
  the input filename but can optionally be included in events to influence the
  event routing to modules. This allows to test the behavior without any
  pre-selection.

* Letting an event hit every module is avoided by routing events based on
  `event.module` to the correct module that can handle the event.
  With Logstash, each "module" (it was called `5_filter` config back then) had an
  if-condition that was evaluated for every event.

## Requirements

* GNU/Linux host. MacOS is also known to work but not officially supported.
* Installed and basic knowledge: See ./templates/Dockerfile
* Vector.dev, v0.36.1.

## Usage

This framework is intended to be integrated as git submodule into a internal
git repo. Relative symlinks should be used to make use of parts of the
framework.

```Shell
git init log_collection
cd log_collection
git submodule add https://github.com/ypid/event-processing-framework.git
./event-processing-framework/helpers/initialize_internal_project "vector-config"
```

Files below `vector-config/config/` that are regular files (not symlinks)
should be edited to make vector do what you need it to do.

## Vector roles

Vector is so flexible that it can be used in different "roles". The concept of
roles was introduced in the [Vector
docs](https://vector.dev/docs/setup/deployment/roles/).

This framework uses the agent and aggregator roles exactly as Vector defined them. Additionally, the framework defines the following additional roles:

* Entrance: The purpose of the entrance is to provide an interface for external hosts (outside the log collection) to send logs to. This is only needed when a event queuing/buffering system like Kafka is used before the aggregator. In case of Kafka, agents could also send events directly to Kafka, but the Vector entrance provides the following advantages over exposing Kafka directly:

  * Capture source IP of the agent as seen by the entrance.
  * Capture client certs metadata for later verification of the host.name.
  * High precision `event.created` timestamp (mostly relevant for syslog because there the agent is not another vector instance).
  * Allows to do "application-level firewalling" for log inputs at the earliest stage before it hits Kafka.

  The Vector entrance should have the following properties:

  * Capture metadata of the host that send logs to it.
  * Do as little as possible: No modification/parsing of the original event.
    This allows to reimport events using Kafka if for example parsing in the aggregator had a bug.

What role a vector instances services is only defined by the configuration that the instance is fed. The framework supports you to write, test and deploy dedicated configs for the agent, entrance and aggregator role. The framework also supports sharing common functions between roles. For example how Vector internal logs are handled.

## Module design principles

The term module and its definition is borrowed from Elastic Filebeat/Ingest
pipelines (see
[Filebeat module overview docs](https://www.elastic.co/guide/en/beats/filebeat/current/filebeat-modules-overview.html)).
A module is meant to encapsulate parsing of logs from one vendor. Lets take as
an example a network Firewall appliance like OPNsense. It will have different
datasets (ECS `event.dataset`) but the overall log structure is usually similar.
The module would be named "opnsense" in this example and all events would have
the field `event.module` set to "opnsense".

A module consists of the following files of which only the first file is strictly required:

* `config/transform_module_{{ event.module }}.yaml`
* `tests/integration/input/module_{{ event.module }}.json`
* `tests/integration/output/dataset_{{ event.dataset }}__sequence_{{ any 17 digit number }}.gron`
* `tests/unit/test_module_{{ event.module }}.yaml`

Modules should ensure that all fields are put below a fieldset named by the
value of `event.dataset`.
Then the module should move/transform fields to corresponding fields as defined
by ECS. Fields that are not handled by the module or have no representation in
ECS yet should stay under the custom fieldset.

## Special fields

* `event.module` should be set by the aggregator if possible and the
  `event.module` field that an agent might send should only be used if the
  aggregator cannot make that choice based on trusted fields.
  For example, when a CMDB defines what a brand/model a host is using the
  `host.type` field.

* `event.dataset`, same as `event.module` except of one difference:
  `event.dataset` should only be set when it is determined. Meaning that it is
  optional in the pre processing. In the module transform code, `event.dataset`
  should be set in all cases. If the module cannot determine it, it should set
  `{{ event.module }}.other`. This can simplify pre processing in case a module
  can determine the dataset based on parts of the event content.

* `event.sequence` is used in integration testing to allow easy correlation
  between input and processed output events.

*  `__` is meant to hold metadata fields (ideally also valid ECS fields if
   possible) that should not be output. Usually, those are additional fields
   that are only needed to derive other fields.

   The convention is borrowed from Python where it is used as variable prefix
   for internal private variables that cannot be accessed from the outside.
   The same is true here. Anything below `__` is not meant to leave a Vector
   instance. The only exception are integration and unit tests.

   Two underscores are also technically required instead of just one because
   with one, the field `index` in the following template cannot be templated:

    ```YAML
    sinks:

      sink_elasticsearch_logging_cluster:
        type: 'elasticsearch'
        inputs: ['transform_remap']
        encoding:
          except_fields: ['__']
        index: '{{ __._index_name }}'
    ```

    TODO: Does it work with `{{ .__._index_name }}`?

* `__._id` is the first 23 characters of a HMAC-SHA256 fingerprint. See
  https://www.elastic.co/blog/logstash-lessons-handling-duplicates why that is
  useful.

  The framework and modules take care of only using the raw message that was
  transmitted by the host as fingerprint input. This is needed to have
  proper deduplication with something like Elasticsearch. For example, when a
  host sends the exact same log twice, it is deduplicated into one and in
  fact, the last event overwrites the previous one. Overwriting does not
  actually change the parsed log (other than `event.inguested`) because we use
  a cryptographically strong hash function which has certain guarantees.

  Deduplication can be done with a SHA2-256 fingerprint alone. The reason the
  fingerprint is implemented as HMAC is that this gives us additional
  properties basically for free.
  The only thing you will have to do is generate a secret key and provide it as
  `.__.hmac_secret_key` to `transform_postprocess_all`. See
  `transform_private.yaml` for an example.

  As long as `event.original` (or more specifically, all inputs to the HMAC
  function) is available this allows to reprocess events and cryptographically
  proof the following:

  1. The `event.original` was processed by the framework and not injected
     into a destination of the framework (e. g. Elasticsearch) without going
     through the framework.
  2. The `event.original` was not altered outside of the framework.
  3. `event.original` can be parsed again by the framework or manually by
     reading `event.original`. For all fields that are extracted from
     `event.original`, 1. and 2. also applies.

  This holds true as long as the secret key is kept private.

* `__.enabled_preprocessors.journald` if set to true, will translate journald
  tags into ECS.

* `__.enabled_preprocessors.syslog_minimal` if set to true, will do a minimum
  amount of syslog parsing when "full" syslog parsing failed.

  By minimal we mean the `<134> ` syslog PRI field that basically everyone has agreed to send.

* `__.enabled_preprocessors.syslog_lax` if set to false, will write parse
  failures and parse warnings to the document.

* `__.enabled_preprocessors."decode outer json"` if set to true, it is assumed
  that the source component provides a message string field that is JSON encoded.
  This is basically the same as setting
  [decoding.codec](https://vector.dev/docs/reference/configuration/sources/kafka/#decoding.codec)
  to `json`. However, it has the advantage that metadata fields of the sink
  component and message content is kept strictly separate.
  Another advantage is that it handles pipeline error better.
  For example, if a Kafka message is `{"broken json": 1` (closing `}` missing),
  `decode outer json` is able to continue processing with the encoded JSON as
  string while `decoding.codec` inevitably fails, logs an error and **drops
  the event**.

* `__.source.*` contains metadata of the Vector source component where the
  event was read from.

## When to write unit tests vs. integration tests?

Every module should have one integration test. If the module only produces a
small number of fields, every other code path of the module should be tested
with unit tests. If the module produces a large number of fields from a
structured log, practical aspects of not having to copy/format lots of
asserts get more important and integration tests should be preferred.

## Pipeline errors and warnings

Values for the `tags` field should be very short. The function name that failed
is not needed because that is already contained in the long version. Examples:

* `parse_warning: grok`
* `parse_failure: syslog`

The long version should go to `log.flags`:

* `parse_warning: grok. Leaving the inner message unparsed. Error: [...]`

There are two levels. `parse_failure` is set for all major failures, for
example, the main grok pattern or syslog decoding fails. `parse_warning` is set
for all minor issues that can be recovered from or some fallback value can be
set.

## Committed to the highest standards

Same as Vector itself, this framework is committed to the highest standards.
The following conventions are followed:

* [REUSE Specification 3.0](https://reuse.software/spec/)
* [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/)
* [RFC 3339](https://datatracker.ietf.org/doc/html/rfc3339)
* [YAML 1.2](https://yaml.org/) (preferred over TOML)
* CI tests using GitLab CI

## Documentation

Addresses and names that are reserved for documentation are used exclusively
for the purpose of correctness and to avoid leaking internal identifiers.

If for an identifier, no range is reserved for documentation then the
value is replaced by a random one with the same format. If the value has a
checksum or [check digits](https://en.wikipedia.org/wiki/Check_digit), those
might not be valid anymore. If validation for this is added later, the value
check digits might need to be fixed later.

Ref: https://github.com/ansible/ansible/issues/17479

### MAC (rfc7042)

https://tools.ietf.org/html/rfc7042#page-7

The following values have been assigned for use in documentation:

* 00:00:5E:00:53:00 through
  00:00:5E:00:53:FF for unicast
* 01:00:5E:90:10:00 through
  01:00:5E:90:10:FF for multicast.

### IP: IPv6 (rfc3849)

https://tools.ietf.org/html/rfc3849

* 2001:db8::/32

### Legacy IP: IPv4 (rfc5737)

https://tools.ietf.org/html/rfc5737

* 192.0.2.0/24
* 198.51.100.0/24
* 203.0.113.0/24

### Domains (rfc2606)

https://tools.ietf.org/html/rfc2606

* "example.net", "example.com", "example.org" reserved example second level domain names
* "example" TLDs for testing and documentation examples

### Hostnames

There seems to be no reserved hostnames or recommendations. The following hostnames are used by this project:

* myhostname
* myotherhostname

### Pod names

There seems to be no reserved pod names or recommendations. The following pod names are used by this project:

* mypodname

### Usernames and logins

There seems to be no reserved usernames and logins. The following strings are used by this project:

* ADDomain\\myadminuser
* myadminuser
* bofh23
* bofh42

### Software version numbers

There seems to be no reserved software version numbers. The following once are used by this project:

* 9.99.9

### Others

Some types are too uncommon to pick a catchy anonymized string here. In those
cases, just use "my_something" for example "my_notification_contact_or_group".
You should use "my-something" if underscores are not allowed as field value to
not confuse parsing.

## TODO

* Drop all Rsyslog support/special handling of Rsyslog fields. There should be
  no use case more for Rsyslog.

* Prevent that `.__` is modified by decoding JSON.

* Ingest pipeline modifications:
  * WIP: Derive event.severity from log.level. It seems Filebeat/Ingest pipeline modules only populate log.level without the numerical event.severity.
  * WIP: @timestamp QA
  * WIP: host.name QA
  * WIP: observer.name QA
  * Do not overwrite observer.type.

* Write command to initialize a new internal project directory. (Setup symlinks, generate hmac_secret_key)

* If original log does not contain year the timestamp parsing assumes the current year. This could be optimized to use better (fixed) sources for the year such as event.created.

* 192.0.2.1 SD is silently dropped in 77644905279723940.

* CI: Require all commits in a merge request to have a green pipeline before merging. Requires a workaround in GitLab, see https://gitlab.com/gitlab-org/gitlab/-/issues/15007

* Why does `./tests/integration/output/dataset_openvpn.vpn__sequence_15405430208467776.gron` not have `event.sequence` from `offset` input? Vector internally messes up `event.sequence` with `offset`. If the `offset` input field is changed to string, it is used. I suspect a wired Vector bug. Retest once upgraded to latest Vector version. The issue only effects the integration tests. It is not an issue when running in a real environment like prod.

* Never emit `._something`. Example where this currently happens: `._CMDLINE` Because OpenSearch complains with: "Field names beginning with _ are not supported."
