# SPDX-FileCopyrightText: 2022 Robin Schneider <ro.schneider@senec.com>
#
# SPDX-License-Identifier: AGPL-3.0-only

# Ubuntu does not have kubernetes-client
# FROM ubuntu:22.04 AS prod

FROM debian:11 AS prod

RUN apt-get -qq update \
    && apt-get -qq install -y extrepo \
    && extrepo enable vector \
    && apt-get -qq update \
    && DEBIAN_FRONTEND=noninteractive apt-get -qq install -y vector=0.24.2-1 yamllint wget make git rsync jq gron tzdata python3 python3-yaml graphviz kubernetes-client \
    && DEBIAN_FRONTEND=noninteractive apt-get -qq install --no-install-recommends python3-pip \
    && pip3 install reuse \
    && ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime \
    && wget https://github.com/mikefarah/yq/releases/download/v4.28.1/yq_linux_amd64 --output-document /usr/local/bin/yq \
    && chmod +x /usr/local/bin/yq
