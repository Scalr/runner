# Runner Image used in Scalr Remote Backend

This is the Git repo of the official runner image.

The image is based on the [`debian:trixie-slim`](https://hub.docker.com/_/debian).

## Included Tools

This environment comes pre-equipped with a comprehensive suite of tools essential for development, operations, and cloud interactions. Here's a breakdown of what's included:

* **Archivators**:
  * zip - Create and extract ZIP archives
  * tar - Manipulate tar archives
  * gzip - Compress and decompress `.gz` files
* **Encryption**:
  * gnupg - Secure data encryption and signing
* **Git (v2.47.2)**:
  * Core Git functionality
  * Git LFS (Large File Storage)
  * SSH and HTTP transport protocols
* **HTTP Clients**:
  * curl - Data transfer with URLs
  * wget - File downloads from the web
  * ca-certificates - Trusted CA certificates
* **Programming Languages**
  * Python ([v3.13.3](https://www.python.org/downloads/release/python-3133/)) - General-purpose programming language (release)
  * jq - Command-line JSON processor
* **Cloud Clients**
  * AWS CLI ([2.27.1](https://github.com/aws/aws-cli/releases/tag/2.27.32)) - Amazon Web Services CLI.
  * Azure CLI ([2.71.0](https://github.com/Azure/azure-cli/releases/tag/azure-cli-2.74.0)) - Microsoft Azure CLI.
  * Google Cloud SDK ([525.0.0](https://cloud.google.com/sdk/docs/release-notes#52500_2025-06-03)) - Stable, Alpha, Beta components. Includes kubectl authenticator.
  * Kubectl ([0.33.1](https://github.com/kubernetes/kubectl/releases/tag/v0.33.1)) - Kubernetes CLI.
  * Scalr CLI ([0.17.1](https://github.com/Scalr/scalr-cli/releases/tag/v0.17.1)) - The command-line to communicate with the Scalr API.

The versions for Python, Cloud Clients, Kubectl, and Scalr CLI are specifically pinned and detailed in the [versions](./versions) file. All other software included in this environment is sourced directly from the Debian Trixie upstream repositories.

## Python Distribution

The environment uses the [standalone Python build](https://github.com/astral-sh/python-build-standalone) provided by the [astral.sh](https://astral.sh/) team.

## Runner Image Building

```bash
docker buildx build \
  --build-arg PYTHON_VERSION=3.13.3 \
  --build-arg KUBECTL_VERSION=v1.33.1 \
  --build-arg GCLOUD_VERSION=525.0.0 \
  --build-arg AWS_CLI_VERSION=2.27.1 \
  --build-arg AZURE_CLI_VERSION=2.71.0 \
  --build-arg SCALR_CLI_VERSION=0.17.1 \
  --platform linux/amd64 \
  -t scalr/runner:latest --load .
```

## Bumping Versions

To update all tool versions to their latest releases, run:

```bash
./bump-versions.sh
```

This script fetches the latest versions from upstream sources and updates the [versions](./versions) file and README.md.

Requirements: `curl` and `jq`.
