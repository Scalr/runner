# Runner image used in Scalr remote backend.

This is the Git repo of the official runner image.

The image is based on the [`debian:bullseye-slim`](https://hub.docker.com/_/debian),
and contains the following software:

* Archivators - zip, tar, gzip
* Encryption - gnupg
* Git (2.30.2) - core, LFS, ssh/http transports
* HTTP clients - curl, wget, ca-certificates
* JSON - jq
* Python (3.11.2)
* Cloud clients (latest versions):
  * AWS CLI
  * Azure CLI
  * GCloud - Stable, Alpha, and Beta components. Kubectl authenticator
* Kubectl (latest version)
* Scalr CLI
