# Copyright 2017 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This Dockerfile will build an image that is configured
# to run Fluentd with an Elasticsearch plug-in and the
# provided configuration file.
# The image acts as an executable for the binary /usr/sbin/td-agent.
# Note that fluentd is run with root permission to allow access to
# log files with root only access under /var/log/containers/*

# 1. Install & configure dependencies.
# 2. Install fluentd via ruby.
# 3. Remove build dependencies.
# 4. Cleanup leftover caches & files.

FROM ruby:3.4.4-slim AS builder

ARG DEBIAN_FRONTEND=noninteractive

COPY Gemfile /Gemfile

SHELL ["/bin/bash", "-e", "-o", "pipefail", "-c"]

# hadolint ignore=DL3008,DL3028
RUN apt-get update && \
    apt-get install -y --no-install-recommends g++ gcc make && \
    rm -rf /var/lib/apt/lists/* && \
    echo 'gem: --no-document' >> /etc/gemrc && \
    gem install --file Gemfile

FROM ruby:3.4.4-slim

ARG DEBIAN_FRONTEND=noninteractive

# Copy the Fluentd configuration file for logging Docker container logs.
COPY fluent.conf /etc/fluent/fluent.conf
COPY entrypoint.sh /entrypoint.sh
COPY --from=builder /usr/local/bundle/ /usr/local/bundle 

SHELL ["/bin/bash", "-e", "-o", "pipefail", "-c"]

# hadolint ignore=DL3008
RUN apt-get update && \
    apt-get install -y --no-install-recommends libjemalloc2 && \
    apt-get clean -y && \
    ulimit -n 65536 && \
    rm -rf \
        /var/cache/debconf/* \
        /var/lib/apt/lists/* \
        /var/log/* \
        /var/tmp/* \
        rm -rf /tmp/*

# Expose prometheus metrics.
EXPOSE 80

#checkov:skip=CKV_DOCKER_2:We don't need Docker HEALTHCHECK in kubernetes
#checkov:skip=CKV_DOCKER_3:root user used

# Start Fluentd to pick up our config that watches Docker container logs.
CMD ["/entrypoint.sh"]
