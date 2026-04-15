# Runner Image for the Scalr remote backend
# --------------------------------------------
#
# Note: This is a PUBLIC image, it should not contain any sensitive data.

FROM debian:trixie-slim AS base

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
ARG PYTHON_RELEASE
ENV PIP_ROOT_USER_ACTION=ignore

RUN <<EOT
  # See: https://gregoryszorc.com/docs/python-build-standalone/main/running.html#extracting-distributions
  export VERSION="${PYTHON_VERSION}"
  export RELEASE="${PYTHON_RELEASE}"
  # Extract major.minor version (e.g., 3.13 from 3.13.11)
  export PY_MINOR="${VERSION%.*}"
  apt-get update -y
  apt-get install -y --no-install-recommends zstd binutils
  [ "${TARGETARCH}" = "amd64" ] && export OPTIONS="x86_64-unknown-linux-gnu-pgo+lto-full"
  [ "${TARGETARCH}" = "arm64" ] && export OPTIONS="aarch64-unknown-linux-gnu-pgo+lto-full"
  curl -L -o python.tar.zst "https://github.com/astral-sh/python-build-standalone/releases/download/${RELEASE}/cpython-${VERSION}+${RELEASE}-${OPTIONS}.tar.zst"
  tar --zstd -xf python.tar.zst
  cp -rp python/install/* /usr
  rm python.tar.zst
  rm -rf python
  # Strip debug symbols from shared libraries.
  strip -d /usr/lib/libpython${PY_MINOR}.so
  # Remove unneeded packages.
  rm -rf /usr/lib/Tix* /usr/lib/tcl* /usr/lib/tk* /usr/lib/itcl* /usr/lib/thread*
  # Remove leftover Tcl/Tk shared libraries (not cleaned by the glob above).
  rm -f /usr/lib/libtcl9.0.so /usr/lib/libtcl9tk9.0.so
  rm -rf /usr/lib/libpython${PY_MINOR}.a
  rm -rf "/usr/lib/python${PY_MINOR}/config-${PY_MINOR}-$(uname -m)-linux-gnu"
  rm -rf /usr/lib/python${PY_MINOR}/ensurepip
  rm -rf /usr/lib/python${PY_MINOR}/tkinter
  rm -rf /usr/lib/python${PY_MINOR}/test
  # Additional stdlib removals (not needed at runtime).
  rm -rf /usr/lib/python${PY_MINOR}/distutils
  rm -rf /usr/lib/python${PY_MINOR}/lib2to3
  rm -rf /usr/lib/python${PY_MINOR}/idlelib
  rm -rf /usr/lib/python${PY_MINOR}/turtledemo
  # Cleanup.
  apt-get remove -y zstd binutils
  apt-get clean
  apt-get autoremove -y
  rm -rf /var/lib/apt/lists/*
  find /usr -name __pycache__ -type d -exec rm -rf {} +
EOT

# Kubectl
ARG KUBECTL_VERSION
RUN <<EOT
  curl -L -o /usr/local/bin/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl"
  chmod a+x /usr/local/bin/kubectl
EOT

# GCloud
ARG GCLOUD_VERSION
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
  rm -rf /usr/local/google-cloud-sdk/help
  rm -rf /usr/local/google-cloud-sdk/data/cli/sdk-component-manager-*
  # Remove installer artefacts not needed in a container.
  rm -f /usr/local/google-cloud-sdk/RELEASE_NOTES
  rm -f /usr/local/google-cloud-sdk/install.bat
  rm -f /usr/local/google-cloud-sdk/install.sh
  rm -rf /usr/local/google-cloud-sdk/deb
  rm -rf /usr/local/google-cloud-sdk/rpm
  find /usr/local/google-cloud-sdk -name __pycache__ -type d -exec rm -rf {} +
EOT

# AWS CLI
ARG AWS_CLI_VERSION
RUN <<EOT
  [ "${TARGETARCH}" = "amd64" ] && AWS_CLI_ARCH="x86_64" || AWS_CLI_ARCH="aarch64"
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-${AWS_CLI_ARCH}-${AWS_CLI_VERSION}.zip" -o awscli.zip
  unzip -q awscli.zip
  ./aws/install
  # Cleanup
  rm -rf aws awscli.zip
  # Remove documentation (25 MB) — only used by 'aws help'.
  find /usr/local/aws-cli -name "examples" -type d -exec rm -rf {} +
  # Remove shell completion binary (8.5 MB) — not useful in a CI runner.
  find /usr/local/aws-cli -name "aws_completer" -delete
EOT

# Azure CLI
ARG AZURE_CLI_VERSION
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
  find /opt/az/lib/python*/site-packages -name "*.dist-info" -type d -exec rm -rf {} +
  find /opt/az/lib/python*/site-packages -name "*.pyi" -delete
  # Remove pip and setuptools — not needed for running Azure CLI.
  find /opt/az/lib/python*/site-packages -maxdepth 1 -name "pip" -type d -exec rm -rf {} +
  find /opt/az/lib/python*/site-packages -maxdepth 1 -name "setuptools" -type d -exec rm -rf {} +
  find /opt/az -name __pycache__ -type d -exec rm -rf {} +
EOT

# Scalr CLI
ARG SCALR_CLI_VERSION
RUN <<EOT
  curl -fsSL "https://github.com/Scalr/scalr-cli/releases/download/v${SCALR_CLI_VERSION}/scalr-cli_${SCALR_CLI_VERSION}_linux_${TARGETARCH}.zip" -o scalr_cli.zip
  unzip -q scalr_cli.zip
  mv ./scalr /usr/local/bin/scalr
  # Cleanup
  rm -rf scalr_cli.zip
EOT

# Add the scalr user (optional; used when running the container with UID 1000).
RUN useradd -u 1000 -m scalr

FROM scratch

ARG PYTHON_VERSION
ARG KUBECTL_VERSION
ARG GCLOUD_VERSION
ARG AWS_CLI_VERSION
ARG AZURE_CLI_VERSION
ARG SCALR_CLI_VERSION

LABEL python.version=${PYTHON_VERSION}
LABEL kubectl.version=${KUBECTL_VERSION}
LABEL gcloud.version=${GCLOUD_VERSION}
LABEL aws-cli.version=${AWS_CLI_VERSION}
LABEL azure-cli.version=${AZURE_CLI_VERSION}
LABEL scalr-cli.version=${SCALR_CLI_VERSION}

ENV PIP_ROOT_USER_ACTION=ignore
ENV PATH=/usr/local/google-cloud-sdk/bin:/tmp/.local/bin:$PATH

COPY --from=base / /

ENTRYPOINT ["/usr/bin/bash"]
