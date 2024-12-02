# SPDX-FileCopyrightText: 2022,2024 Robin Schneider <ro.schneider@senec.com>
#
# SPDX-License-Identifier: AGPL-3.0-only

FROM timberio/vector:0.42.0-debian@sha256:60fda41b3830c5b34627581f9c6826df181efe8a18ea2b9718098924e6226d50 AS prod

RUN apt-get -qq update && \
    DEBIAN_FRONTEND=noninteractive apt-get -qq install -y \
        curl \
        git \
        graphviz \
        gron \
        jq \
        make \
        pipx \
        python3 \
        python3-yaml \
        reuse \
        rsync \
        tzdata \
        wget \
        yamllint && \
    ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime && \
    wget https://github.com/mikefarah/yq/releases/download/v4.42.1/yq_linux_amd64 --output-document /usr/local/bin/yq && \
    chmod +x /usr/local/bin/yq && \
    PIPX_HOME=/opt/pipx PIPX_BIN_DIR=/usr/local/bin pipx install pre-commit

# Create user.
RUN adduser user --shell /bin/bash --uid 1000

USER user

# Reset entrypoint as set by timberio/vector image.
ENTRYPOINT []
