# Scalr Runner Image

This repository hosts the build pipeline for the runner images used by the OpenTofu/Terraform 
remote operations backend of the Scalr platform and [on-prem Scalr Agents](https://docs.scalr.io/docs/run-environment#runner-image).

## Contents

- [Image Variants](#image-variants)
- [Included Tools](#included-tools)
  - [Base Software](#base-software)
  - [Added in the full image](#added-in-the-full-image)
  - [Added in the `-python39` image](#added-in-the--python39-image)
  - [Runtime user](#runtime-user)
- [Building the Images](#building-the-images)
- [Bumping Versions](#bumping-versions)

## Image Variants

Two image families are published from this repository, one per base distro:

| Family | Base image | Dockerfile | Docker Hub repository |
| ------ | ---------- | ---------- | --------------------- |
| Debian | [`debian:trixie-slim`](https://hub.docker.com/_/debian) | [`Dockerfile.debian`](./Dockerfile.debian) | `scalr/runner` |
| Ubuntu | [`ubuntu:26.04`](https://hub.docker.com/_/ubuntu) | [`Dockerfile.ubuntu`](./Dockerfile.ubuntu) | `scalr/runner-ubuntu` |

Each family ships the same three variants (`<repo>` is `scalr/runner` or
`scalr/runner-ubuntu`):

- `<repo>:<x.y.z>-slim` — slim image: a minimal set of tools.
- `<repo>:<x.y.z>` — full image: the slim set plus cloud CLIs (AWS, Azure, gcloud, kubectl, scalr-cli) and Python 3.14.
- `<repo>:<x.y.z>-python39` — same as the full image, but with Python 3.9 instead of 3.14 (for legacy workflows).

Base images are pinned by digest in [versions.json](./versions.json), and
every variant is published as a multi-arch manifest for `linux/amd64` and
`linux/arm64`.

Releases are driven by git tags carrying the distro as a prefix:
`debian/<x.y.z>` triggers [release-debian.yaml](./.github/workflows/release-debian.yaml)
and `ubuntu/<x.y.z>` triggers [release-ubuntu.yaml](./.github/workflows/release-ubuntu.yaml).
The prefix is stripped before it is used as the image tag, so the tag
`debian/0.5.0` publishes `scalr/runner:0.5.0`. The two families are versioned
and released independently.

## Included Tools

The images provide a set of tools commonly used in IaC workflows, grouped
below by the variant they appear in.

### Base Software

Present in all variants. These come from the pinned base image snapshot
referenced by `DEBIAN_BASE_DIGEST` / `UBUNTU_BASE_DIGEST` in
[versions.json](./versions.json), so their exact versions are whatever that
snapshot pins.

* **Archive tools**:
  * `tar` — manipulate tar archives (from the base image)
  * `gzip` — compress and decompress `.gz` files (from the base image)
  * `zip`, `unzip` — create and extract ZIP archives
* **Encryption**:
  * `gnupg` — secure data encryption and signing
* **Git**:
  * `git-core` — core Git
  * `git-lfs` — Large File Storage extension
  * `openssh-client` — SSH transport for Git over SSH
* **HTTP / network**:
  * `curl` — data transfer with URLs
  * `wget` — file downloads from the web
  * `ca-certificates` — trusted CA bundle
* **System / misc**:
  * `jq` — command-line JSON processor
  * `lsb-release` — Linux Standard Base release info
  * `bash` (default shell / entrypoint)

### Added in the full image

These are pinned by exact version + SHA256 in
[versions.json](./versions.json) and downloaded during the build. The
versions below are the current pins (kept in sync with `versions.json` by
`bump-versions.py`):

* **Programming language**
  * Python ([v3.14.6](https://www.python.org/downloads/release/python-3146/)) — [standalone CPython build](https://github.com/astral-sh/python-build-standalone) from [astral.sh](https://astral.sh/)
* **Cloud CLIs**
  * AWS CLI ([2.35.22](https://github.com/aws/aws-cli/releases/tag/2.35.22)) — Amazon Web Services CLI
  * AWS Session Manager Plugin — SSM session support for the AWS CLI
  * Azure CLI ([2.88.0](https://github.com/Azure/azure-cli/releases/tag/azure-cli-2.88.0)) — Microsoft Azure CLI
  * Google Cloud SDK ([575.0.1](https://cloud.google.com/sdk/docs/release-notes#57501)) — `gcloud` with `alpha`, `beta`, and `gke-gcloud-auth-plugin` components
  * Kubectl ([0.36.2](https://github.com/kubernetes/kubectl/releases/tag/v0.36.2)) — Kubernetes CLI
  * Scalr CLI ([0.18.0](https://github.com/Scalr/scalr-cli/releases/tag/v0.18.0)) — command-line client for the Scalr API

### Added in the `-python39` image

Same as the full image, with Python 3.14 replaced by Python 3.9 (currently
[v3.9.25](https://www.python.org/downloads/release/python-3925/)).

**Google Cloud SDK pin.** Newer `gcloud` releases dropped Python 3.9
support, so the SDK is pinned to `564.0.0` (the last version that still
works on Python 3.9) via the `versions_python39` map. `bump-versions.py`
does not auto-bump this pin — if you ever change it, recompute the
per-arch SHA256s for the new version by hand. The full (Python 3.14)
image continues to track the latest gcloud release.

### Runtime user

A non-root user `scalr` with uid/gid `1000` is created in the base layer
and is therefore present in all variants.

## Building the Images

Builds are driven by [`docker-bake.hcl`](./docker-bake.hcl) (targets, tags,
cache config) and [`versions.json`](./versions.json) (pinned tool versions
and SHA256 checksums). `versions.json` is a native Docker Buildx Bake
variable file containing four maps:

- `versions_debian` — Debian base image and digest (used by every `debian-*` target, including `-slim`)
- `versions_ubuntu` — Ubuntu base image and digest (used by every `ubuntu-*` target, including `-slim`)
- `versions_full` — extra tools layered on top for the full image (kubectl, gcloud, AWS CLI, Azure CLI, Scalr CLI, Python 3.14, AWS SSM Plugin); shared by both distros
- `versions_python39` — Python 3.9 overrides merged on top of `versions_full` for the `-python39` image

Bake exposes one target per distro/variant pair — `debian-full`,
`debian-python39`, `debian-slim`, `ubuntu-full`, `ubuntu-python39`,
`ubuntu-slim` — plus a `debian` and an `ubuntu` group that builds all three
variants of that family. The default group builds both families.

Always pass both files. Every download is verified by SHA256 in the
Dockerfiles.

Tags use `VERSION` from the environment, defaulting to `dev` for local
builds.

The bake file declares `platforms = ["linux/amd64", "linux/arm64"]` for CI
multi-arch builds. Local builds with Docker's default driver cannot do
multi-platform, so add `--set "*.platform=linux/amd64"` (or your host arch)
and `--load` to every local command.

### Build everything (both distros, all variants)

```bash
VERSION=dev docker buildx bake -f docker-bake.hcl -f versions.json \
  --set "*.platform=linux/amd64" --load
```

### Build one distro

```bash
# scalr/runner:dev, :dev-python39, :dev-slim
VERSION=dev docker buildx bake -f docker-bake.hcl -f versions.json \
  --set "*.platform=linux/amd64" --load debian

# scalr/runner-ubuntu:dev, :dev-python39, :dev-slim
VERSION=dev docker buildx bake -f docker-bake.hcl -f versions.json \
  --set "*.platform=linux/amd64" --load ubuntu
```

### Build one variant

```bash
# scalr/runner:dev
VERSION=dev docker buildx bake -f docker-bake.hcl -f versions.json \
  --set "*.platform=linux/amd64" --load debian-full

# scalr/runner:dev-python39
VERSION=dev docker buildx bake -f docker-bake.hcl -f versions.json \
  --set "*.platform=linux/amd64" --load debian-python39

# scalr/runner-ubuntu:dev-slim
VERSION=dev docker buildx bake -f docker-bake.hcl -f versions.json \
  --set "*.platform=linux/amd64" --load ubuntu-slim
```

## Bumping Versions

To update all tool versions to their latest releases, run:

```bash
./bump-versions.py
```

This script fetches the latest versions from upstream sources and updates
the `versions_debian`, `versions_ubuntu`, `versions_full`, and
`versions_python39` maps in [versions.json](./versions.json) (plus the
[Included Tools](#included-tools) section of this README). Both base image
digests are re-pinned; tool versions are shared by both distros. For every
tool it also refreshes the per-arch SHA256 checksums used by the Dockerfiles
to verify each download.

Requirements: `python3` (stdlib only, no `pip install` needed).

GitHub's anonymous API quota is 60 requests/hour. The script makes ~5 calls
to `api.github.com` per run, so frequent reruns may hit `HTTP 403: rate
limit exceeded`. Export `GITHUB_TOKEN` (or `GH_TOKEN`) to lift the limit to
5000/hour:

```bash
GITHUB_TOKEN=$(gh auth token) ./bump-versions.py
```
