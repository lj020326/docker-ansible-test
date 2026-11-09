# Dockerfile for ansible-test container
# This Dockerfile builds a custom ansible-test container image.
# It allows specifying Ansible core and Python versions via build arguments.

#=============================================================================
# 1. CORE BUILD CONFIGURATION
#=============================================================================
ARG PYTHON_VERSION="3.13"
ARG DEBIAN_VERSION="bookworm"
FROM python:${PYTHON_VERSION}-slim-${DEBIAN_VERSION} AS builder

ENV YQ_VERSION=v4.53.2
ENV YQ_BINARY=yq_linux_amd64

# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends unzip tar curl \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /out/usr/local/bin

# ADD auto-extracts local archives, saving extract layers
ADD files/${YQ_BINARY}_${YQ_VERSION}.tar.gz /tmp/

RUN mv /tmp/${YQ_BINARY} /out/usr/local/bin/yq || mv /tmp/*${YQ_BINARY}* /out/usr/local/bin/yq

# Ensure everything is executable
RUN chmod +x /out/usr/local/bin/*

#=============================================================================
# 3. CONSOLIDATED RUNTIME IMAGE
#=============================================================================
FROM python:${PYTHON_VERSION}-slim-${DEBIAN_VERSION}

ARG ANSIBLE_CORE_VERSION="latest"

LABEL maintainer="Lee Johnson <ljohnson@dettonville.org>"
LABEL description="Custom Ansible Test Container for Ansible Core ${ANSIBLE_CORE_VERSION} and Python ${PYTHON_VERSION}"

ARG BUILD_DATE
ARG BUILD_ID=devel
LABEL build=$BUILD_ID

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Etc/UTC \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    container=docker \
    VIRTUAL_ENV=/opt/venv \
    PIP_NO_CACHE_DIR=1

ENV PATH="${VIRTUAL_ENV}/bin:${PATH}"

ARG user=jenkins
ARG group=jenkins
ARG uid=1001
ARG gid=1001
ARG DOCKER_GID=1102

# Switch default shell to bash so pipefail is recognized globally across RUN statements
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Setup Docker Group, Jenkins User, and APT Configuration
RUN groupadd -g "${DOCKER_GID}" docker && \
    groupadd -g "${gid}" "${group}" && \
    useradd -l -c "Jenkins user" --shell /bin/bash -d /home/"${user}" -u "${uid}" -g "${gid}" -m "${user}" && \
    usermod -aG sudo,docker "${user}" && \
    printf 'APT::Install-Suggests "0";\nAPT::Install-Recommends "0";\n' > /etc/apt/apt.conf.d/00-docker

# Combined APT Installation Layer
# hadolint ignore=DL3008
RUN set -o pipefail && \
    apt-get update -qqy && \
    apt-get -qqy --no-install-recommends install \
      apt-transport-https apt-utils ca-certificates \
      bash tar zip unzip xorriso \
      curl git git-lfs \
      locales tzdata netbase \
      tree less jq rsync \
      dnsutils iproute2 iputils-ping inetutils-telnet \
      openssh-client ssh-askpass sshpass \
      gpg gpg-agent gnupg2 \
      shellcheck groff rlwrap \
      build-essential patch genisoimage dirmngr openssl \
      libxml2-dev libxslt1-dev \
      zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev \
      libpq-dev libmariadb-dev libsasl2-dev libldap2-dev \
      libssl-dev libsqlite3-dev libreadline-dev libffi-dev \
      libbz2-dev uuid-dev default-mysql-client && \
    sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen && \
    install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    chmod a+r /etc/apt/keyrings/docker.gpg && \
    echo "deb [arch=\"$(dpkg --print-architecture)\" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo "\"$VERSION_CODENAME\"") stable" > /etc/apt/sources.list.d/docker.list && \
    apt-get update && apt-get install -y --no-install-recommends docker-ce-cli docker-compose-plugin docker-buildx-plugin docker-model-plugin && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

#=============================================================================
# 4. RUNTIME DEPENDENCY INGESTION
#=============================================================================
COPY --from=builder /out/usr/local/bin/ /usr/local/bin/

# Setup Virtual Environment and Python packages
WORKDIR /tmp
# hadolint ignore=DL3013
RUN python3 -m venv "$VIRTUAL_ENV" && pip install --no-cache-dir --upgrade pip wheel setuptools

RUN echo "Install ansible-core with ANSIBLE_CORE_VERSION: ${ANSIBLE_CORE_VERSION}"

# Install ansible-core and ansible-test.
# ansible-test is included as part of the ansible-core package.
# Use the specified ANSIBLE_CORE_VERSION.
# hadolint ignore=DL3013
RUN set -o pipefail && \
    pip install --disable-pip-version-check --upgrade pip \
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
            ;; \
        *) \
            # Use compatible release operator to get the latest patch version for a given minor version (e.g., 2.14.x)
            # Ensure the variable is not empty before attempting the install
            if [ -z "${ANSIBLE_CORE_VERSION}" ]; then \
                echo "Error: ANSIBLE_CORE_VERSION is empty for compatible release installation."; \
                exit 1; \
            fi; \
            MAJOR_MINOR=$(echo "${ANSIBLE_CORE_VERSION}" | cut -d. -f1,2); \
            NEXT_MINOR=$(echo "${ANSIBLE_CORE_VERSION}" | awk -F. '{print $2 + 1}'); \
            UPPER_BOUND="${MAJOR_MINOR%.*}.${NEXT_MINOR}"; \
            pip install --disable-pip-version-check "ansible-core>=${ANSIBLE_CORE_VERSION},<${UPPER_BOUND}"; \
            ;; \
    esac \
    && pip install --disable-pip-version-check pytest flake8


# Configure Multiarch Contexts
RUN for user_home in /root "/home/${user}"; do \
        mkdir -p "${user_home}/.ssh" && \
        mkdir -p "${user_home}/.docker/buildx/instances" && \
        echo '{"name":"multiarch-builder","driver":"docker-container","nodes":[{"name":"multiarch-builder0","endpoint":"unix:///var/run/docker.sock","platforms":null,"flags":[],"env":null,"driver-opts":null}]}' \
        > "${user_home}/.docker/buildx/instances/multiarch-builder" && \
        mkdir -p "${user_home}/.docker" && \
        echo '{"currentContext":"default"}' \
        > "${user_home}/.docker/config.json" && \
        mkdir -p "${user_home}/.ansible/collections" && \
        chown -R "${user}:${user}" "${user_home}/.docker" "${user_home}/.ansible" || true; \
    done

ENV HOME=/home/${user}
WORKDIR ${HOME}
USER ${user}

# You can add an entrypoint here if you want to define a default command,
# but leaving it flexible allows the Jenkins pipeline to execute specific
# ansible-test commands directly.
# ENTRYPOINT ["ansible-test"]

# Fallback default command
#CMD ["/bin/bash"]
