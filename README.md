# Runner Image used in Scalr Remote Backend.

This is the Git repo of the official runner image.

The image is based on the [`debian:bookworm-slim`](https://hub.docker.com/_/debian),
and contains the following software:

* Archivators - zip, tar, gzip
* Encryption - gnupg
* Git (2.39.5) - core, LFS, ssh/http transports
* HTTP clients - curl, wget, ca-certificates
* JSON - jq
* Python (3.11.2)
* Cloud clients (see [versions](./versions)):
  * AWS CLI
  * Azure CLI
  * GCloud - Stable, Alpha, and Beta components. Kubectl authenticator
* Kubectl (latest version)
* Scalr CLI

## Runner Image Building

```bash
docker buildx build \
  --build-arg KUBECTL_VERSION=v1.33.0 \
  --build-arg GCLOUD_VERSION=519.0.0 \
  --build-arg AWS_CLI_VERSION=2.27.1 \
  --build-arg AZURE_CLI_VERSION=2.71.0 \
  --build-arg SCALR_CLI_VERSION=0.17.0 \
  --platform linux/amd64 \
  -t runner:latest --load .
```