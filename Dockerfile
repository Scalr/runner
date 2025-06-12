# Runner Image for the Scalr remote backend
# --------------------------------------------
#
# Note: This is a PUBLIC image, it should not contain any sensitive data.

FROM debian:trixie-slim

ARG TARGETARCH

SHELL ["/bin/bash", "-o", "pipefail", "-euxc"]

# Base Software
RUN <<EOT
  # Install base software
  apt-get update -y
  apt-get install -y --no-install-recommends \
    wget curl ca-certificates \
    git-core git-lfs openssh-client \
    jq \
    gnupg \
    zip unzip \
    lsb-release
  [ "${TARGETARCH}" = "amd64" ] && SESSION_MANAGER_ARCH="64bit" || SESSION_MANAGER_ARCH="arm64"
  curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_${SESSION_MANAGER_ARCH}/session-manager-plugin.deb" -o "session-manager-plugin.deb"
  dpkg -i session-manager-plugin.deb
  # Cleanup
  rm session-manager-plugin.deb
  apt-get clean
  apt-get autoremove -y
  rm -rf /var/lib/apt/lists/*
  find /usr -name __pycache__ -type d -exec rm -rf {} +
EOT

# Install python standalone build.
ARG PYTHON_VERSION
LABEL python.version=${PYTHON_VERSION}
ENV PIP_ROOT_USER_ACTION=ignore
RUN <<EOT
  # See: https://gregoryszorc.com/docs/python-build-standalone/main/running.html#extracting-distributions
  export VERSION="${PYTHON_VERSION}"
  export RELEASE="20250517"
  apt-get update -y
  apt-get install -y --no-install-recommends zstd binutils
  [ "${TARGETARCH}" = "amd64" ] && export OPTIONS="x86_64-unknown-linux-gnu-pgo+lto-full"
  [ "${TARGETARCH}" = "arm64" ] && export OPTIONS="aarch64-unknown-linux-gnu-lto-full"
  curl -L -o python.tar.zst "https://github.com/astral-sh/python-build-standalone/releases/download/${RELEASE}/cpython-${VERSION}+${RELEASE}-${OPTIONS}.tar.zst"
  tar --zstd -xf python.tar.zst
  cp -rp python/install/* /usr
  rm python.tar.zst
  rm -rf python
  # Strip debug symbols from shared libraries.
  strip -d /usr/lib/libpython3.13.so
  # Remove unneeded packages.
  rm -rf /usr/lib/Tix* /usr/lib/tcl* /usr/lib/tk* /usr/lib/itcl* /usr/lib/thread*
  rm -rf /usr/lib/libpython3.13.a
  rm -rf "/usr/lib/python3.13/config-3.13-$(uname -m)-linux-gnu"
  rm -rf /usr/lib/python3.13/ensurepip
  rm -rf /usr/lib/python3.13/tkinker
  rm -rf /usr/lib/python3.13/test
  # Cleanup.
  apt-get remove -y zstd binutils
  apt-get clean
  apt-get autoremove -y
  rm -rf /var/lib/apt/lists/*
  find /usr -name __pycache__ -type d -exec rm -rf {} +
EOT

# Kubectl
ARG KUBECTL_VERSION
LABEL kubectl.version=${KUBECTL_VERSION}
RUN <<EOT
  curl -L -o /usr/local/bin/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl"
  chmod a+x /usr/local/bin/kubectl
EOT

# GCloud
ARG GCLOUD_VERSION
LABEL gcloud.version=${GCLOUD_VERSION}
# Our terraform runs are running in terraform container, where home dir (HOME env var) is /tmp,
# therefore all pip binaries are installing under /tmp/.local/bin
ENV PATH=/usr/local/google-cloud-sdk/bin:/tmp/.local/bin:$PATH
RUN <<EOT
  [ "${TARGETARCH}" = "amd64" ] && GCLOUD_ARCH="x86_64" || GCLOUD_ARCH="arm"
  curl -fsSL "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-${GCLOUD_VERSION}-linux-${GCLOUD_ARCH}.tar.gz" -o google-cloud-sdk.tar.gz
  tar -C /usr/local -zxf google-cloud-sdk.tar.gz
  rm -rf google-cloud-sdk.tar.gz
  gcloud components install \
    alpha beta \
    gke-gcloud-auth-plugin
  # Cleanup
  rm -rf /usr/local/google-cloud-sdk/.install/.backup
  find /usr/local/google-cloud-sdk -name __pycache__ -type d -exec rm -rf {} +
EOT

# AWS CLI
ARG AWS_CLI_VERSION
LABEL aws-cli.version=${AWS_CLI_VERSION}
RUN <<EOT
  [ "${TARGETARCH}" = "amd64" ] && AWS_CLI_ARCH="x86_64" || AWS_CLI_ARCH="aarch64"
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-${AWS_CLI_ARCH}-${AWS_CLI_VERSION}.zip" -o awscli.zip
  unzip -q awscli.zip
  ./aws/install
  # Cleanup
  rm -rf aws awscli.zip
EOT

# Azure CLI
ARG AZURE_CLI_VERSION
LABEL azure-cli.version=${AZURE_CLI_VERSION}
RUN <<EOT
  AZ_DIST=bookworm
  mkdir -p /etc/apt/keyrings
  curl -sLS https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | tee /etc/apt/keyrings/microsoft.gpg > /dev/null
  chmod go+r /etc/apt/keyrings/microsoft.gpg
  echo "Types: deb
URIs: https://packages.microsoft.com/repos/azure-cli/
Suites: ${AZ_DIST}
Components: main
Architectures: $(dpkg --print-architecture)
Signed-by: /etc/apt/keyrings/microsoft.gpg" | tee /etc/apt/sources.list.d/azure-cli.sources
  apt-get update
  apt-get install -y --no-install-recommends "azure-cli=${AZURE_CLI_VERSION}-1~${AZ_DIST}"
  # Cleanup
  apt-get clean
  apt-get autoremove -y
  rm -rf /var/lib/apt/lists/*
  find /opt/az/lib/python* -regextype grep -regex ".*/tests\?" -exec rm -rf {} +
  find /opt/az -name __pycache__ -type d -exec rm -rf {} +
EOT

# Scalr CLI
ARG SCALR_CLI_VERSION
LABEL scalr-cli.version=${SCALR_CLI_VERSION}
RUN <<EOT
  curl -fsSL "https://github.com/Scalr/scalr-cli/releases/download/v${SCALR_CLI_VERSION}/scalr-cli_${SCALR_CLI_VERSION}_linux_${TARGETARCH}.zip" -o scalr_cli.zip
  unzip -q scalr_cli.zip
  mv ./scalr /usr/local/bin/scalr
  # Cleanup
  rm -rf scalr_cli.zip
EOT

ENTRYPOINT ["/bin/bash"]
