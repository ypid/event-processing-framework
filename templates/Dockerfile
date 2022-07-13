# SPDX-FileCopyrightText: 2022 Robin Schneider <ro.schneider@senec.com>
#
# SPDX-License-Identifier: AGPL-3.0-only

FROM ubuntu:20.04 AS prod

RUN apt-get -qq update \
    && apt-get -qq install -y extrepo \
    && extrepo enable vector \
    && apt-get -qq update \
    && DEBIAN_FRONTEND=noninteractive apt-get -qq install -y vector=0.22.3-1 yamllint make git rsync jq gron tzdata python3 python3-yaml graphviz \
    && DEBIAN_FRONTEND=noninteractive apt-get -qq install --no-install-recommends python3-pip \
    && pip3 install reuse \
    && ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime
