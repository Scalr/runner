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
  * Python ([v3.14.5](https://www.python.org/downloads/release/python-3145/)) - General-purpose programming language (release)
  * jq - Command-line JSON processor
* **Cloud Clients**
  * AWS CLI ([2.34.45](https://github.com/aws/aws-cli/releases/tag/2.34.45)) - Amazon Web Services CLI.
  * Azure CLI ([2.86.0](https://github.com/Azure/azure-cli/releases/tag/azure-cli-2.86.0)) - Microsoft Azure CLI.
  * Google Cloud SDK ([568.0.0](https://cloud.google.com/sdk/docs/release-notes#56800)) - Stable, Alpha, Beta components. Includes kubectl authenticator.
  * Kubectl ([0.36.1](https://github.com/kubernetes/kubectl/releases/tag/v0.36.1)) - Kubernetes CLI.
  * Scalr CLI ([0.18.0](https://github.com/Scalr/scalr-cli/releases/tag/v0.18.0)) - The command-line to communicate with the Scalr API.

The versions for Python, Cloud Clients, Kubectl, and Scalr CLI are specifically pinned and detailed in the [versions](./versions) file. All other software included in this environment is sourced directly from the Debian Trixie upstream repositories.

## Python Distribution

The environment uses the [standalone Python build](https://github.com/astral-sh/python-build-standalone) provided by the [astral.sh](https://astral.sh/) team.

Two Python variants are available:

| Image Tag | Python Version |
|-----------|----------------|
| `scalr/runner:<x.y.z>` | Python 3.14.x |
| `scalr/runner:<x.y.z>-python39` | Python 3.9.x |

## Runner Image Building

All tool versions and SHA256 checksums are stored as `KEY=value` lines:

- [`versions`](./versions) — defaults (kubectl, gcloud, AWS CLI, Azure CLI, Scalr CLI, Python 3.14, AWS SSM Plugin)
- [`versions_python39`](./versions_python39) — Python 3.9 overrides (consumed only by the `-python39` image)

The snippet below forwards every entry as a `--build-arg`, so each download is
verified against a hash pinned in this repo.

### Default image (Python 3.14)

```bash
docker buildx build \
  $(grep -v '^#' versions | grep -v '^$' | xargs -I {} echo --build-arg={}) \
  --platform linux/amd64 \
  -t scalr/runner:latest --load .
```

### Python 3.9 variant

Pass both files; later args override earlier ones, so `versions_python39`
replaces the `PYTHON_*` keys from `versions`:

```bash
docker buildx build \
  $(grep -v '^#' versions          | grep -v '^$' | xargs -I {} echo --build-arg={}) \
  $(grep -v '^#' versions_python39 | grep -v '^$' | xargs -I {} echo --build-arg={}) \
  --platform linux/amd64 \
  -t scalr/runner:latest-python39 --load .
```

## Bumping Versions

To update all tool versions to their latest releases, run:

```bash
./bump-versions.py
```

This script fetches the latest versions from upstream sources and updates the [versions](./versions) and [versions_python39](./versions_python39) files (plus the "Included Tools" section of this README). For every tool it also refreshes the per-arch SHA256 checksums used by the Dockerfile to verify each download.

Requirements: `python3` (stdlib only, no `pip install` needed).

GitHub's anonymous API quota is 60 requests/hour. The script makes ~5 calls to
`api.github.com` per run, so frequent reruns may hit `HTTP 403: rate limit exceeded`.
Export `GITHUB_TOKEN` (or `GH_TOKEN`) to lift the limit to 5000/hour:

```bash
GITHUB_TOKEN=$(gh auth token) ./bump-versions.py
```
