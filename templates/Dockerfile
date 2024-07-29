# SPDX-FileCopyrightText: 2022,2024 Robin Schneider <ro.schneider@senec.com>
#
# SPDX-License-Identifier: AGPL-3.0-only

FROM timberio/vector:0.39.0-debian@sha256:f5704c730ea10e0d7272491f4293a596f5ebc695fec64e29d29f5364895ef997 AS prod

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

# Create user.
RUN adduser user --shell /bin/bash --uid 1000

USER user

# Reset entrypoint as set by timberio/vector image.
ENTRYPOINT []
