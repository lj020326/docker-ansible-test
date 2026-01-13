# Dockerfile for ansible-test container
# This Dockerfile builds a custom ansible-test container image.
# It allows specifying Ansible core and Python versions via build arguments.

# ARG instructions used in FROM must come before the FROM instruction
ARG PYTHON_VERSION="3.12"

# Use a Python base image that matches the desired Python version
# We use a slim Debian-based image for smaller size.
FROM python:${PYTHON_VERSION}-slim-bullseye

ARG ANSIBLE_CORE_VERSION="latest"

LABEL maintainer="Lee Johnson <ljohnson@dettonville.org>"
LABEL description="Custom Ansible Test Container for Ansible Core ${ANSIBLE_CORE_VERSION} and Python ${PYTHON_VERSION}"

ARG BUILD_DATE
ARG BUILD_ID=devel
LABEL build=$BUILD_ID

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/ansible/bin" \
    # Set PIP_NO_CACHE_DIR to prevent pip from caching packages inside the image
    PIP_NO_CACHE_DIR=1

ENV PATH="/root/.local/bin:${PATH}"

## ref: https://github.com/pypa/pip/issues/11179#issuecomment-1152766374
ENV PIP_ROOT_USER_ACTION=ignore

## https://github.com/mikefarah/yq#install
ENV YQ_VERSION=v4.2.0
ENV YQ_BINARY=yq_linux_amd64

# Update package lists and install necessary build tools and common dependencies.
# These are essential for compiling some Python packages and for general test execution.
# Add any other system-level dependencies your specific Ansible collections might require.
# For example, if your collections interact with AWS, Azure, databases, etc., you might need:
# apt-get install -y --no-install-recommends libssl-dev libffi-dev openssh-client
RUN apt-get update \
    && apt-get install -y apt-utils \
    && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        bash \
        git \
        curl \
        wget \
        tree \
        jq \
        ssh-client \
        shellcheck \
        locales \
        # Docker-in-docker dependencies
        gnupg \
        dirmngr \
        sshpass \
        # Common libraries for Python modules (e.g., for cryptography, database connectors)
        libpq-dev \
        # libmysqlclient-dev \
        libmariadb-dev \
        # python-ldap dependencies
        build-essential \
        libsasl2-dev \
        libldap2-dev \
        libssl-dev \
    # Add more if needed, e.g., python3-dev for some native extensions
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Generate and set the locale
RUN sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
    && locale-gen

# Set environment variables for the locale
ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

# --- Start Docker-in-Docker (DinD) support installation ---
# Install Docker CLI to enable running docker commands inside this container.
# This is crucial for scenarios like 'ansible-test units --docker' which
# require interacting with a Docker daemon.
RUN apt-get update \
    && install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && chmod a+r /etc/apt/keyrings/docker.gpg \
    && echo \
        "deb [arch=\"$(dpkg --print-architecture)\" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
        $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y --no-install-recommends docker-ce-cli **docker-compose-plugin** \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean
# --- End Docker-in-Docker (DinD) support installation ---

RUN python -m pip install --upgrade pip

## 'yq' required for ansible inventory tests
## ref: https://github.com/mikefarah/yq#install
## ref: https://askubuntu.com/questions/72663/how-to-make-wget-retry-download-if-speed-goes-below-certain-threshold
#RUN wget -q https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq &&\
#    chmod +x /usr/local/bin/yq
#RUN wget -q https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/${YQ_BINARY}.tar.gz -O - |\
#  tar xz && mv ${YQ_BINARY} /usr/local/bin/yq
RUN wget -c --tries=5 --read-timeout=5 -q https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/${YQ_BINARY}.tar.gz -O - |\
  tar xz && mv ${YQ_BINARY} /usr/local/bin/yq

# Set the working user for the rest of the build and runtime to 'root'
# as your desired UID is 0.
USER root

RUN echo "Install ansible-core with ANSIBLE_CORE_VERSION: ${ANSIBLE_CORE_VERSION}"

# Install ansible-core and ansible-test.
# ansible-test is included as part of the ansible-core package.
# Use the specified ANSIBLE_CORE_VERSION.
#RUN pip install --user --upgrade pip \
RUN pip install --disable-pip-version-check --upgrade pip \
    && case "${ANSIBLE_CORE_VERSION}" in \
        latest) \
            pip install "ansible-core"; \
            ;; \
        devel) \
            # For 'devel', you might need to pull directly from Ansible's Git repo.
            # For simplicity, we'll treat 'devel' as 'latest' for this basic Dockerfile,
            # installing the latest published ansible-core.
#            set -x; \
            python -m pip install " https://github.com/ansible/ansible/archive/devel.tar.gz" --disable-pip-version-check --user; \
#            pip install "ansible-core"; \
#            set +x; \
            ;; \
        *) \
            # Use compatible release operator to get the latest patch version for a given minor version (e.g., 2.14.x)
            # Ensure the variable is not empty before attempting the install
            if [ -z "${ANSIBLE_CORE_VERSION}" ]; then \
                echo "Error: ANSIBLE_CORE_VERSION is empty for compatible release installation."; \
                exit 1; \
            fi; \
#            set -x; \
#            python -m pip install " https://github.com/ansible/ansible/archive/stable-${ANSIBLE_CORE_VERSION}.tar.gz" --disable-pip-version-check --user; \
#            pip install "ansible-core~=${ANSIBLE_CORE_VERSION}"; \
            MAJOR_MINOR=$(echo "${ANSIBLE_CORE_VERSION}" | cut -d. -f1,2); \
            NEXT_MINOR=$(echo "${ANSIBLE_CORE_VERSION}" | awk -F. '{print $2 + 1}'); \
            UPPER_BOUND="${MAJOR_MINOR%.*}.${NEXT_MINOR}"; \
            pip install --disable-pip-version-check "ansible-core>=${ANSIBLE_CORE_VERSION},<${UPPER_BOUND}"; \
#            set +x; \
            ;; \
    esac \
    && pip install --disable-pip-version-check pytest flake8
#    && pip install --user pytest flake8

# Create the default Ansible collections directory to ensure
# `ansible-galaxy collection list` can run without errors.
# The `ansible-test` tool and other Ansible commands expect this path to exist.
RUN mkdir -p /root/.ansible/collections

# Create a working directory for Ansible project files
WORKDIR /ansible_project

# You can add an entrypoint here if you want to define a default command,
# but leaving it flexible allows the Jenkins pipeline to execute specific
# ansible-test commands directly.
# ENTRYPOINT ["ansible-test"]
