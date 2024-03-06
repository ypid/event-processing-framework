# SPDX-FileCopyrightText: 2022,2024 Robin Schneider <ro.schneider@senec.com>
#
# SPDX-License-Identifier: AGPL-3.0-only

FROM timberio/vector:0.36.0-debian AS prod

ARG VECTOR_DEV_VERSION="0.36.0-1"
LABEL dev.vector.version="$VECTOR_DEV_VERSION"

RUN apt-get -qq update && \
    DEBIAN_FRONTEND=noninteractive apt-get -qq install -y \
        curl \
        git \
        graphviz \
        gron \
        jq \
        make \
        python3 \
        python3-yaml \
        reuse \
        rsync \
        tzdata \
        wget \
        yamllint && \
    ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime && \
    wget https://github.com/mikefarah/yq/releases/download/v4.42.1/yq_linux_amd64 --output-document /usr/local/bin/yq && \
    chmod +x /usr/local/bin/yq

# Reset entrypoint as set by timberio/vector image.
ENTRYPOINT []
