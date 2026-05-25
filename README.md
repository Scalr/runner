# Runner Image used in Scalr Remote Backend

This is the Git repo of the official runner image.

The image is based on the [`debian:trixie-slim`](https://hub.docker.com/_/debian).

## Included Tools

This environment comes pre-equipped with a comprehensive suite of tools essential for development, operations, and cloud interactions. Here's a breakdown of what's included (full image; the `-slim` variant ships only the basic tools through `jq`):

* **Archivators**:
  * zip - Create and extract ZIP archives
  * tar - Manipulate tar archives
  * gzip - Compress and decompress `.gz` files
* **Encryption**:
  * gnupg - Secure data encryption and signing
* **Git**:
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

The versions for Python, Cloud Clients, Kubectl, and Scalr CLI are specifically pinned and detailed in [versions.json](./versions.json). All other software included in this environment is sourced directly from the Debian Trixie upstream repositories.

## Image Variants

| Image Tag | Contents | Python Version |
|-----------|----------|----------------|
| `scalr/runner:<x.y.z>` | Basic tools + Python + cloud CLIs | Python 3.14.x |
| `scalr/runner:<x.y.z>-python39` | Same as default, with Python 3.9 | Python 3.9.x |
| `scalr/runner:<x.y.z>-slim` | Basic tools only (git, curl, jq, gnupg, etc.) | — |

The `-slim` variant is for workflows that don't need Python or cloud CLIs and
want the smallest possible image.

### Python Distribution (default and `-python39`)

The Python-enabled images use the [standalone Python build](https://github.com/astral-sh/python-build-standalone) provided by the [astral.sh](https://astral.sh/) team.

## Runner Image Building

Builds are driven by [`docker-bake.hcl`](./docker-bake.hcl) (targets, tags,
cache config) and [`versions.json`](./versions.json) (pinned tool versions and
SHA256 checksums). `versions.json` is a native Docker Buildx Bake variable
file containing two maps:

- `versions_base` — Debian base image and digest (used by every target, including `-slim`)
- `versions_full` — extra tools layered on top for the full image (kubectl, gcloud, AWS CLI, Azure CLI, Scalr CLI, Python 3.14, AWS SSM Plugin)
- `versions_python39` — Python 3.9 overrides merged on top of `versions_full` for the `-python39` image

Always pass both files. Every download is verified by SHA256 in the Dockerfile.

Tags use `VERSION` from the environment, defaulting to `dev` for local builds.
There is no `latest` tag — release tags are explicit.

The bake file declares `platforms = ["linux/amd64", "linux/arm64"]` for CI
multi-arch builds. Local builds with Docker's default driver cannot do
multi-platform, so add `--set "*.platform=linux/amd64"` (or your host arch)
and `--load` to every local command.

### Build everything

```bash
VERSION=3.0.0 docker buildx bake -f docker-bake.hcl -f versions.json \
  --set "*.platform=linux/amd64" --load
```

### Build one variant

```bash
VERSION=3.0.0 docker buildx bake -f docker-bake.hcl -f versions.json \
  --set "*.platform=linux/amd64" --load full      # scalr/runner:3.0.0

VERSION=3.0.0 docker buildx bake -f docker-bake.hcl -f versions.json \
  --set "*.platform=linux/amd64" --load python39  # scalr/runner:3.0.0-python39

VERSION=3.0.0 docker buildx bake -f docker-bake.hcl -f versions.json \
  --set "*.platform=linux/amd64" --load slim      # scalr/runner:3.0.0-slim
```

## Bumping Versions

To update all tool versions to their latest releases, run:

```bash
./bump-versions.py
```

This script fetches the latest versions from upstream sources and updates the `versions_base`, `versions_full`, and `versions_python39` maps in [versions.json](./versions.json) (plus the "Included Tools" section of this README). For every tool it also refreshes the per-arch SHA256 checksums used by the Dockerfile to verify each download.

Requirements: `python3` (stdlib only, no `pip install` needed).

GitHub's anonymous API quota is 60 requests/hour. The script makes ~5 calls to
`api.github.com` per run, so frequent reruns may hit `HTTP 403: rate limit exceeded`.
Export `GITHUB_TOKEN` (or `GH_TOKEN`) to lift the limit to 5000/hour:

```bash
GITHUB_TOKEN=$(gh auth token) ./bump-versions.py
```
