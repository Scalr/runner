# Docker Buildx Bake file for the Scalr runner images.
#
# Two image families are built from this repository, one per base distro:
#   - Debian (Dockerfile.debian) -> scalr/runner
#   - Ubuntu (Dockerfile.ubuntu) -> scalr/runner-ubuntu
#
# Each family ships the same three variants: full, python39 and slim.
#
# Build everything (both distros, all variants):
#   docker buildx bake -f docker-bake.hcl -f versions.json
#
# Build one distro:
#   docker buildx bake -f docker-bake.hcl -f versions.json debian
#   docker buildx bake -f docker-bake.hcl -f versions.json ubuntu
#
# Build one target:
#   docker buildx bake -f docker-bake.hcl -f versions.json debian-full
#   docker buildx bake -f docker-bake.hcl -f versions.json ubuntu-slim
#
# Override the version tag (defaults to "dev" for local builds):
#   VERSION=3.0.0 docker buildx bake -f docker-bake.hcl -f versions.json debian-full

variable "VERSION" {
  default = "dev"
}

# Repository names for each distro family.
variable "IMAGE_DEBIAN" {
  default = "scalr/runner"
}
variable "IMAGE_UBUNTU" {
  default = "scalr/runner-ubuntu"
}

# Versions and SHA256 checksums for tools installed inside the images.
# Populated from versions.json (a native bake variable file) and maintained
# by ./bump-versions.py.
#   versions_debian   — Debian base image + digest; used by every debian-* target
#   versions_ubuntu   — Ubuntu base image + digest; used by every ubuntu-* target
#   versions_full     — extra tools for the full image (kubectl, cloud CLIs, Python 3.14, …)
#   versions_python39 — overrides merged on top for the -python39 image
variable "versions_debian" {
  default = {}
}
variable "versions_ubuntu" {
  default = {}
}
variable "versions_full" {
  default = {}
}
variable "versions_python39" {
  default = {}
}

group "default" {
  targets = ["debian", "ubuntu"]
}

group "debian" {
  targets = ["debian-full", "debian-python39", "debian-slim"]
}

group "ubuntu" {
  targets = ["ubuntu-full", "ubuntu-python39", "ubuntu-slim"]
}

# Shared settings for every published target.
target "_common" {
  platforms = ["linux/amd64", "linux/arm64"]
}

# --- Debian (scalr/runner) --------------------------------------------------

target "_debian" {
  inherits   = ["_common"]
  dockerfile = "Dockerfile.debian"
}

target "debian-full" {
  inherits = ["_debian"]
  target   = "full"
  args     = merge(versions_debian, versions_full)
  tags     = ["${IMAGE_DEBIAN}:${VERSION}", "${IMAGE_DEBIAN}:v${VERSION}"]
}

target "debian-python39" {
  inherits = ["_debian"]
  target   = "full"
  args     = merge(versions_debian, versions_full, versions_python39)
  tags     = ["${IMAGE_DEBIAN}:${VERSION}-python39", "${IMAGE_DEBIAN}:v${VERSION}-python39"]
}

target "debian-slim" {
  inherits = ["_debian"]
  target   = "slim"
  args     = versions_debian
  tags     = ["${IMAGE_DEBIAN}:${VERSION}-slim", "${IMAGE_DEBIAN}:v${VERSION}-slim"]
}

# --- Ubuntu (scalr/runner-ubuntu) -------------------------------------------

target "_ubuntu" {
  inherits   = ["_common"]
  dockerfile = "Dockerfile.ubuntu"
}

target "ubuntu-full" {
  inherits = ["_ubuntu"]
  target   = "full"
  args     = merge(versions_ubuntu, versions_full)
  tags     = ["${IMAGE_UBUNTU}:${VERSION}", "${IMAGE_UBUNTU}:v${VERSION}"]
}

target "ubuntu-python39" {
  inherits = ["_ubuntu"]
  target   = "full"
  args     = merge(versions_ubuntu, versions_full, versions_python39)
  tags     = ["${IMAGE_UBUNTU}:${VERSION}-python39", "${IMAGE_UBUNTU}:v${VERSION}-python39"]
}

target "ubuntu-slim" {
  inherits = ["_ubuntu"]
  target   = "slim"
  args     = versions_ubuntu
  tags     = ["${IMAGE_UBUNTU}:${VERSION}-slim", "${IMAGE_UBUNTU}:v${VERSION}-slim"]
}
