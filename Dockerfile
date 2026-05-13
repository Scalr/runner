# Runner Image for the Scalr remote backend
# --------------------------------------------
#
# Note: This is a PUBLIC image, it should not contain any sensitive data.

FROM debian:trixie-slim@sha256:109e2c65005bf160609e4ba6acf7783752f8502ad218e298253428690b9eaa4b

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
  # Cleanup
  apt-get clean
  apt-get autoremove -y
  rm -rf /var/lib/apt/lists/*
  find /usr -name __pycache__ -type d -exec rm -rf {} +
EOT

# Install python standalone build.
ARG PYTHON_VERSION
ARG PYTHON_RELEASE
ARG PYTHON_SHA256_AMD64
ARG PYTHON_SHA256_ARM64
LABEL python.version=${PYTHON_VERSION}
ENV PIP_ROOT_USER_ACTION=ignore

RUN <<EOT
  # See: https://gregoryszorc.com/docs/python-build-standalone/main/running.html#extracting-distributions
  export VERSION="${PYTHON_VERSION}"
  export RELEASE="${PYTHON_RELEASE}"
  # Extract major.minor version (e.g., 3.x from 3.x.y)
  export PY_MINOR="${VERSION%.*}"
  apt-get update -y
  apt-get install -y --no-install-recommends zstd binutils
  [ "${TARGETARCH}" = "amd64" ] && export OPTIONS="x86_64-unknown-linux-gnu-pgo+lto-full" PY_SHA256="${PYTHON_SHA256_AMD64}"
  [ "${TARGETARCH}" = "arm64" ] && export OPTIONS="aarch64-unknown-linux-gnu-pgo+lto-full" PY_SHA256="${PYTHON_SHA256_ARM64}"
  curl -fsSL -o python.tar.zst "https://github.com/astral-sh/python-build-standalone/releases/download/${RELEASE}/cpython-${VERSION}+${RELEASE}-${OPTIONS}.tar.zst"
  echo "${PY_SHA256}  python.tar.zst" | sha256sum -c -
  tar --zstd -xf python.tar.zst
  cp -rp python/install/* /usr
  rm python.tar.zst
  rm -rf python
  # Strip debug symbols from shared libraries.
  strip -d /usr/lib/libpython${PY_MINOR}.so
  # Remove unneeded packages.
  rm -rf /usr/lib/Tix* /usr/lib/tcl* /usr/lib/tk* /usr/lib/itcl* /usr/lib/thread*
  rm -rf /usr/lib/libpython${PY_MINOR}.a
  rm -rf "/usr/lib/python${PY_MINOR}/config-${PY_MINOR}-$(uname -m)-linux-gnu"
  rm -rf /usr/lib/python${PY_MINOR}/ensurepip
  rm -rf /usr/lib/python${PY_MINOR}/tkinter
  rm -rf /usr/lib/python${PY_MINOR}/test
  # Cleanup.
  apt-get remove -y zstd binutils
  apt-get clean
  apt-get autoremove -y
  rm -rf /var/lib/apt/lists/*
  find /usr -name __pycache__ -type d -exec rm -rf {} +
EOT

# Kubectl
ARG KUBECTL_VERSION
ARG KUBECTL_SHA256_AMD64
ARG KUBECTL_SHA256_ARM64
LABEL kubectl.version=${KUBECTL_VERSION}
RUN <<EOT
  [ "${TARGETARCH}" = "amd64" ] && KUBECTL_SHA256="${KUBECTL_SHA256_AMD64}" || KUBECTL_SHA256="${KUBECTL_SHA256_ARM64}"
  curl -fsSL -o /usr/local/bin/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl"
  echo "${KUBECTL_SHA256}  /usr/local/bin/kubectl" | sha256sum -c -
  chmod a+x /usr/local/bin/kubectl
EOT

# GCloud
ARG GCLOUD_VERSION
ARG GCLOUD_SHA256_AMD64
ARG GCLOUD_SHA256_ARM64
LABEL gcloud.version=${GCLOUD_VERSION}
# Our terraform runs are running in terraform container, where home dir (HOME env var) is /tmp,
# therefore all pip binaries are installing under /tmp/.local/bin
ENV PATH=/usr/local/google-cloud-sdk/bin:/tmp/.local/bin:$PATH
RUN <<EOT
  [ "${TARGETARCH}" = "amd64" ] && GCLOUD_ARCH="x86_64" GCLOUD_SHA256="${GCLOUD_SHA256_AMD64}" || GCLOUD_ARCH="arm" GCLOUD_SHA256="${GCLOUD_SHA256_ARM64}"
  curl -fsSL "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-${GCLOUD_VERSION}-linux-${GCLOUD_ARCH}.tar.gz" -o google-cloud-sdk.tar.gz
  echo "${GCLOUD_SHA256}  google-cloud-sdk.tar.gz" | sha256sum -c -
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
ARG AWS_CLI_SHA256_AMD64
ARG AWS_CLI_SHA256_ARM64
LABEL aws-cli.version=${AWS_CLI_VERSION}
RUN <<EOT
  [ "${TARGETARCH}" = "amd64" ] && AWS_CLI_ARCH="x86_64" AWS_CLI_SHA256="${AWS_CLI_SHA256_AMD64}" || AWS_CLI_ARCH="aarch64" AWS_CLI_SHA256="${AWS_CLI_SHA256_ARM64}"
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-${AWS_CLI_ARCH}-${AWS_CLI_VERSION}.zip" -o awscli.zip
  echo "${AWS_CLI_SHA256}  awscli.zip" | sha256sum -c -
  unzip -q awscli.zip
  ./aws/install
  # Cleanup
  rm -rf aws awscli.zip
EOT

# AWS Session Manager Plugin
ARG AWS_SSM_PLUGIN_VERSION
ARG AWS_SSM_PLUGIN_SHA256_AMD64
ARG AWS_SSM_PLUGIN_SHA256_ARM64
LABEL aws-ssm-plugin.version=${AWS_SSM_PLUGIN_VERSION}
RUN <<EOT
  [ "${TARGETARCH}" = "amd64" ] && SSM_ARCH="64bit" SSM_SHA256="${AWS_SSM_PLUGIN_SHA256_AMD64}" || SSM_ARCH="arm64" SSM_SHA256="${AWS_SSM_PLUGIN_SHA256_ARM64}"
  curl -fsSL -o session-manager-plugin.deb \
    "https://s3.amazonaws.com/session-manager-downloads/plugin/${AWS_SSM_PLUGIN_VERSION}/ubuntu_${SSM_ARCH}/session-manager-plugin.deb"
  echo "${SSM_SHA256}  session-manager-plugin.deb" | sha256sum -c -
  dpkg -i session-manager-plugin.deb
  rm session-manager-plugin.deb
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
ARG SCALR_CLI_SHA256_AMD64
ARG SCALR_CLI_SHA256_ARM64
LABEL scalr-cli.version=${SCALR_CLI_VERSION}
RUN <<EOT
  [ "${TARGETARCH}" = "amd64" ] && SCALR_CLI_SHA256="${SCALR_CLI_SHA256_AMD64}" || SCALR_CLI_SHA256="${SCALR_CLI_SHA256_ARM64}"
  curl -fsSL "https://github.com/Scalr/scalr-cli/releases/download/v${SCALR_CLI_VERSION}/scalr-cli_${SCALR_CLI_VERSION}_linux_${TARGETARCH}.zip" -o scalr_cli.zip
  echo "${SCALR_CLI_SHA256}  scalr_cli.zip" | sha256sum -c -
  unzip -q scalr_cli.zip
  mv ./scalr /usr/local/bin/scalr
  # Cleanup
  rm -rf scalr_cli.zip
EOT

# Add the scalr user (optional; used when running the container with UID 1000).
RUN useradd -u 1000 -m scalr

# Security hardening: strip privilege-escalation surface inherited from the base image.
# Must run last so it cannot be undone by a later layer.
RUN <<EOT
  # Remove su/sudo and account/password/login management tools.
  rm -f \
    /bin/su /usr/bin/su \
    /bin/sudo /usr/bin/sudo /usr/sbin/sudo \
    /usr/bin/passwd /usr/sbin/chpasswd \
    /usr/bin/chsh /usr/bin/chfn \
    /usr/bin/newgrp /usr/bin/gpasswd \
    /usr/bin/chage /usr/bin/expiry \
    /usr/sbin/unix_chkpwd /usr/sbin/pam_timestamp_check \
    /usr/sbin/useradd /usr/sbin/userdel /usr/sbin/usermod \
    /usr/sbin/groupadd /usr/sbin/groupdel /usr/sbin/groupmod \
    /usr/sbin/adduser /usr/sbin/addgroup \
    /usr/sbin/deluser /usr/sbin/delgroup \
    /usr/sbin/visudo \
    /bin/mount /usr/bin/mount \
    /bin/umount /usr/bin/umount
  # Strip SUID/SGID bits from every remaining file (defense-in-depth).
  find / -xdev \( -perm -4000 -o -perm -2000 \) -type f -exec chmod a-s {} + 2>/dev/null || true
EOT

ENTRYPOINT ["/usr/bin/bash"]
