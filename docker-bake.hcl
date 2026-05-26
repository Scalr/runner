# Docker Buildx Bake file for the Scalr runner image.
#
# Build all variants:
#   docker buildx bake -f docker-bake.hcl -f versions.json
#
# Build one variant:
#   docker buildx bake -f docker-bake.hcl -f versions.json full
#   docker buildx bake -f docker-bake.hcl -f versions.json python39
#   docker buildx bake -f docker-bake.hcl -f versions.json slim
#
# Override the version tag (defaults to "dev" for local builds):
#   VERSION=3.0.0 docker buildx bake -f docker-bake.hcl -f versions.json full

variable "VERSION" {
  default = "dev"
}

# Versions and SHA256 checksums for tools installed inside the image.
# Populated from versions.json (a native bake variable file) and maintained
# by ./bump-versions.py.
#   versions_base     — base layer (Debian base digest); used by every target
#   versions_full     — extra tools for the full image (kubectl, cloud CLIs, Python 3.14, …)
#   versions_python39 — overrides merged on top for the -python39 image
variable "versions_base" {
  default = {}
}
variable "versions_full" {
  default = {}
}
variable "versions_python39" {
  default = {}
}

group "default" {
  targets = ["full", "python39", "slim"]
}

target "full" {
  target    = "full"
  platforms = ["linux/amd64", "linux/arm64"]
  args      = merge(versions_base, versions_full)
  tags      = ["scalr/runner:${VERSION}"]
}

target "python39" {
  target    = "full"
  platforms = ["linux/amd64", "linux/arm64"]
  args      = merge(versions_base, versions_full, versions_python39)
  tags      = ["scalr/runner:${VERSION}-python39"]
}

target "slim" {
  target    = "slim"
  platforms = ["linux/amd64", "linux/arm64"]
  args      = versions_base
  tags      = ["scalr/runner:${VERSION}-slim"]
}
