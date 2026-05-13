#!/usr/bin/env python3
"""Bump tool versions in ./versions and refresh pinned SHA256 checksums.

For every tool that has a discoverable upstream version index, this script
fetches the latest release, updates ./versions, and refreshes the per-arch
SHA256 checksums the Dockerfile uses to verify each download. The AWS
Session Manager Plugin version stays manually pinned (no upstream version
index) but its SHAs are still refreshed against the pinned version.

Stdlib only — no pip dependencies.
"""

from __future__ import annotations

import hashlib
import json
import logging
import os
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path
from typing import Callable

VERSIONS_FILE = Path("versions")
PYTHON39_FILE = Path("versions_python39")
README_FILE = Path("README.md")
UA = "bump-versions.py (https://github.com/Scalr/runner)"
# Optional auth — GitHub's unauthenticated API quota is 60/hour per IP;
# 5000/hour with any valid token. CI sets GITHUB_TOKEN automatically.
GITHUB_TOKEN = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")


logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger("bump-versions")


# --- HTTP / hash helpers ----------------------------------------------------


def _request(url: str) -> urllib.request.Request:
    headers = {"User-Agent": UA}
    if GITHUB_TOKEN and "api.github.com" in url:
        headers["Authorization"] = f"Bearer {GITHUB_TOKEN}"
    return urllib.request.Request(url, headers=headers)


def http_get_text(url: str) -> str:
    with urllib.request.urlopen(_request(url), timeout=60) as resp:
        return resp.read().decode()


def http_get_json(url: str):
    return json.loads(http_get_text(url))


def compute_sha256_url(url: str) -> str:
    """Stream URL through SHA256 without holding the whole file in memory."""
    h = hashlib.sha256()
    with urllib.request.urlopen(_request(url), timeout=300) as resp:
        for chunk in iter(lambda: resp.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def fetch_text_sha(url: str) -> str:
    """Sidecar .sha256 file (single hash, optional trailing filename)."""
    return http_get_text(url).strip().split()[0]


def fetch_sha_from_sumsfile(sums_url: str, asset: str) -> str:
    """SHA256SUMS-style file: '<hash>  <filename>' lines."""
    for line in http_get_text(sums_url).splitlines():
        parts = line.split()
        if len(parts) >= 2 and parts[1] == asset:
            return parts[0]
    raise RuntimeError(f"{asset} not found in {sums_url}")


# --- versions file I/O ------------------------------------------------------


def read_versions(path: Path = VERSIONS_FILE) -> dict[str, str]:
    out: dict[str, str] = {}
    if not path.exists():
        return out
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, _, v = line.partition("=")
        out[k] = v
    return out


def write_value(key: str, value: str, path: Path = VERSIONS_FILE) -> None:
    """Update an existing key= line in-place, or append if missing."""
    lines = path.read_text().splitlines() if path.exists() else []
    new_line = f"{key}={value}"
    for i, line in enumerate(lines):
        if line.startswith(f"{key}="):
            lines[i] = new_line
            break
    else:
        lines.append(new_line)
    path.write_text("\n".join(lines) + "\n")


# --- README pretty-section updaters -----------------------------------------


def _readme_sub(pattern: str, replacement: str) -> None:
    content = README_FILE.read_text()
    new, n = re.subn(pattern, replacement, content, count=1)
    if n == 0:
        log.warning(f"README: no match for /{pattern}/")
        return
    README_FILE.write_text(new)


def update_readme_python(version: str) -> None:
    no_dots = version.replace(".", "")
    _readme_sub(
        r"Python \(\[v[0-9.]+\]\(https://www\.python\.org/downloads/release/python-[0-9]+/\)\)",
        f"Python ([v{version}](https://www.python.org/downloads/release/python-{no_dots}/))",
    )


def update_readme_aws_cli(version: str) -> None:
    _readme_sub(
        r"AWS CLI \(\[[0-9.]+\]\(https://github\.com/aws/aws-cli/releases/tag/[0-9.]+\)\)",
        f"AWS CLI ([{version}](https://github.com/aws/aws-cli/releases/tag/{version}))",
    )


def update_readme_azure_cli(version: str) -> None:
    _readme_sub(
        r"Azure CLI \(\[[0-9.]+\]\(https://github\.com/Azure/azure-cli/releases/tag/azure-cli-[0-9.]+\)\)",
        f"Azure CLI ([{version}](https://github.com/Azure/azure-cli/releases/tag/azure-cli-{version}))",
    )


def update_readme_gcloud(version: str) -> None:
    no_dots = version.replace(".", "")
    _readme_sub(
        r"Google Cloud SDK \(\[[0-9.]+\]\(https://cloud\.google\.com/sdk/docs/release-notes#[^)]+\)\)",
        f"Google Cloud SDK ([{version}](https://cloud.google.com/sdk/docs/release-notes#{no_dots}))",
    )


def update_readme_kubectl(version: str) -> None:
    # version is "v1.36.1"; kubectl repo uses "0.36.1" matching k8s minor.
    repo_ver = version.replace("v1.", "0.", 1)
    _readme_sub(
        r"Kubectl \(\[[0-9.]+\]\(https://github\.com/kubernetes/kubectl/releases/tag/v[0-9.]+\)\)",
        f"Kubectl ([{repo_ver}](https://github.com/kubernetes/kubectl/releases/tag/v{repo_ver}))",
    )


def update_readme_scalr_cli(version: str) -> None:
    _readme_sub(
        r"Scalr CLI \(\[[0-9.]+\]\(https://github\.com/Scalr/scalr-cli/releases/tag/v[0-9.]+\)\)",
        f"Scalr CLI ([{version}](https://github.com/Scalr/scalr-cli/releases/tag/v{version}))",
    )


# --- upstream version fetchers ----------------------------------------------


def get_latest_kubectl() -> str:
    return http_get_text("https://dl.k8s.io/release/stable.txt").strip()


def get_latest_gcloud() -> str:
    html = http_get_text("https://cloud.google.com/sdk/docs/release-notes")
    m = re.search(r"(\d+\.\d+\.\d+)", html)
    return m.group(1) if m else ""


def get_latest_aws_cli() -> str:
    tags = http_get_json("https://api.github.com/repos/aws/aws-cli/tags")
    for t in tags:
        if t["name"].startswith("2."):
            return t["name"]
    return ""


def get_latest_azure_cli() -> str:
    rel = http_get_json("https://api.github.com/repos/Azure/azure-cli/releases/latest")
    return rel["tag_name"].removeprefix("azure-cli-")


def get_latest_scalr_cli() -> str:
    rel = http_get_json("https://api.github.com/repos/Scalr/scalr-cli/releases/latest")
    return rel["tag_name"].removeprefix("v")


def _latest_python_version(series: str) -> tuple[str, str]:
    """Latest (version, release) for the given series (e.g. '3.14' or '3.9').

    Walks recent releases newest-first — python-build-standalone ships
    different CPython series per release, and older series (e.g. 3.9) appear
    only in some releases, so the "latest" release may not carry every series.
    """
    # per_page>10 routinely 504s here — the response is large because each
    # release lists ~100 assets. 10 is plenty: 3.9 appears in most releases.
    releases = http_get_json(
        "https://api.github.com/repos/astral-sh/python-build-standalone/releases?per_page=10"
    )
    pat = re.compile(rf"cpython-({re.escape(series)}\.\d+)")
    for rel in releases:
        for asset in rel.get("assets", []):
            m = pat.search(asset["name"])
            if m:
                return m.group(1), rel["tag_name"]
    return "", ""


def get_latest_python_info() -> tuple[str, str]:
    """Return (version, release), e.g. ('3.14.5', '20260510')."""
    return _latest_python_version("3.14")


def get_latest_python39_info() -> tuple[str, str]:
    """Return (version, release) for the latest 3.9.x in python-build-standalone."""
    return _latest_python_version("3.9")


# --- per-tool SHA refresh ---------------------------------------------------


def refresh_kubectl_shas(version: str) -> None:
    write_value(
        "KUBECTL_SHA256_AMD64",
        fetch_text_sha(
            f"https://dl.k8s.io/release/{version}/bin/linux/amd64/kubectl.sha256"
        ),
    )
    write_value(
        "KUBECTL_SHA256_ARM64",
        fetch_text_sha(
            f"https://dl.k8s.io/release/{version}/bin/linux/arm64/kubectl.sha256"
        ),
    )


def refresh_python_shas(version: str, release: str, path: Path = VERSIONS_FILE) -> None:
    sums = (
        "https://github.com/astral-sh/python-build-standalone/releases/download/"
        f"{release}/SHA256SUMS"
    )
    write_value(
        "PYTHON_SHA256_AMD64",
        fetch_sha_from_sumsfile(
            sums,
            f"cpython-{version}+{release}-x86_64-unknown-linux-gnu-pgo+lto-full.tar.zst",
        ),
        path,
    )
    write_value(
        "PYTHON_SHA256_ARM64",
        fetch_sha_from_sumsfile(
            sums,
            f"cpython-{version}+{release}-aarch64-unknown-linux-gnu-pgo+lto-full.tar.zst",
        ),
        path,
    )


def refresh_gcloud_shas(version: str) -> None:
    base = (
        "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/"
        f"google-cloud-sdk-{version}-linux-"
    )
    write_value("GCLOUD_SHA256_AMD64", compute_sha256_url(f"{base}x86_64.tar.gz"))
    write_value("GCLOUD_SHA256_ARM64", compute_sha256_url(f"{base}arm.tar.gz"))


def refresh_aws_cli_shas(version: str) -> None:
    base = "https://awscli.amazonaws.com/awscli-exe-linux-"
    write_value(
        "AWS_CLI_SHA256_AMD64", compute_sha256_url(f"{base}x86_64-{version}.zip")
    )
    write_value(
        "AWS_CLI_SHA256_ARM64",
        compute_sha256_url(f"{base}aarch64-{version}.zip"),
    )


def refresh_scalr_cli_shas(version: str) -> None:
    sums = (
        f"https://github.com/Scalr/scalr-cli/releases/download/v{version}/"
        f"scalr-cli_{version}_SHA256SUMS"
    )
    write_value(
        "SCALR_CLI_SHA256_AMD64",
        fetch_sha_from_sumsfile(sums, f"scalr-cli_{version}_linux_amd64.zip"),
    )
    write_value(
        "SCALR_CLI_SHA256_ARM64",
        fetch_sha_from_sumsfile(sums, f"scalr-cli_{version}_linux_arm64.zip"),
    )


def refresh_aws_ssm_plugin_shas(version: str) -> None:
    base = f"https://s3.amazonaws.com/session-manager-downloads/plugin/{version}"
    write_value(
        "AWS_SSM_PLUGIN_SHA256_AMD64",
        compute_sha256_url(f"{base}/ubuntu_64bit/session-manager-plugin.deb"),
    )
    write_value(
        "AWS_SSM_PLUGIN_SHA256_ARM64",
        compute_sha256_url(f"{base}/ubuntu_arm64/session-manager-plugin.deb"),
    )


# --- main flow --------------------------------------------------------------


def bump(
    label: str,
    key: str,
    latest: str,
    current: str,
    changes: list[tuple[str, str, str]],
    refresh_shas: Callable[[str], None] | None = None,
    update_readme: Callable[[str], None] | None = None,
) -> bool:
    if latest and current != latest:
        log.info(f"{label}: {current} -> {latest}")
        write_value(key, latest)
        if refresh_shas:
            refresh_shas(latest)
        if update_readme:
            update_readme(latest)
        changes.append((label, current, latest))
        return True
    log.info(f"{label}: {current} (up to date)")
    return False


def main() -> int:
    if not VERSIONS_FILE.exists():
        log.error(f"{VERSIONS_FILE} not found (run from repo root)")
        return 1

    log.info("Fetching latest versions...")
    vs = read_versions()
    changes: list[tuple[str, str, str]] = []

    bump(
        "kubectl",
        "KUBECTL_VERSION",
        get_latest_kubectl(),
        vs.get("KUBECTL_VERSION", ""),
        changes,
        refresh_kubectl_shas,
        update_readme_kubectl,
    )
    bump(
        "gcloud",
        "GCLOUD_VERSION",
        get_latest_gcloud(),
        vs.get("GCLOUD_VERSION", ""),
        changes,
        refresh_gcloud_shas,
        update_readme_gcloud,
    )
    bump(
        "aws_cli",
        "AWS_CLI_VERSION",
        get_latest_aws_cli(),
        vs.get("AWS_CLI_VERSION", ""),
        changes,
        refresh_aws_cli_shas,
        update_readme_aws_cli,
    )
    bump(
        "azure_cli",
        "AZURE_CLI_VERSION",
        get_latest_azure_cli(),
        vs.get("AZURE_CLI_VERSION", ""),
        changes,
        None,
        update_readme_azure_cli,
    )
    bump(
        "scalr_cli",
        "SCALR_CLI_VERSION",
        get_latest_scalr_cli(),
        vs.get("SCALR_CLI_VERSION", ""),
        changes,
        refresh_scalr_cli_shas,
        update_readme_scalr_cli,
    )

    # Python has two coupled fields (version + release) and one SHA refresh.
    cur_v = vs.get("PYTHON_VERSION", "")
    cur_r = vs.get("PYTHON_RELEASE", "")
    lat_v, lat_r = get_latest_python_info()
    py_changed = False
    if lat_v and cur_v != lat_v:
        log.info(f"python: {cur_v} -> {lat_v}")
        write_value("PYTHON_VERSION", lat_v)
        update_readme_python(lat_v)
        changes.append(("python", cur_v, lat_v))
        py_changed = True
    else:
        log.info(f"python: {cur_v} (up to date)")
    if lat_r and cur_r != lat_r:
        log.info(f"python_release: {cur_r} -> {lat_r}")
        write_value("PYTHON_RELEASE", lat_r)
        changes.append(("python_release", cur_r, lat_r))
        py_changed = True
    else:
        log.info(f"python_release: {cur_r} (up to date)")
    if py_changed:
        refresh_python_shas(lat_v, lat_r)

    # Python 3.9 variant — same upstream as 3.14, separate file with plain PYTHON_* keys.
    vs39 = read_versions(PYTHON39_FILE)
    cur_v39 = vs39.get("PYTHON_VERSION", "")
    cur_r39 = vs39.get("PYTHON_RELEASE", "")
    lat_v39, lat_r39 = get_latest_python39_info()
    if not (lat_v39 and lat_r39):
        log.warning("python39: no 3.9 build found in recent python-build-standalone releases; skipping")
    else:
        py39_changed = False
        if cur_v39 != lat_v39:
            log.info(f"python39: {cur_v39} -> {lat_v39}")
            write_value("PYTHON_VERSION", lat_v39, PYTHON39_FILE)
            changes.append(("python39", cur_v39, lat_v39))
            py39_changed = True
        else:
            log.info(f"python39: {cur_v39} (up to date)")
        if cur_r39 != lat_r39:
            log.info(f"python39_release: {cur_r39} -> {lat_r39}")
            write_value("PYTHON_RELEASE", lat_r39, PYTHON39_FILE)
            changes.append(("python39_release", cur_r39, lat_r39))
            py39_changed = True
        else:
            log.info(f"python39_release: {cur_r39} (up to date)")
        if py39_changed:
            refresh_python_shas(lat_v39, lat_r39, PYTHON39_FILE)

    # AWS SSM Plugin: version is manually pinned (no upstream version index),
    # but its SHAs are refreshed in case the pinned version was hand-edited.
    cur_ssm = vs.get("AWS_SSM_PLUGIN_VERSION", "")
    if cur_ssm:
        log.info(f"aws_ssm_plugin: {cur_ssm} (manually pinned; refreshing SHAs)")
        refresh_aws_ssm_plugin_shas(cur_ssm)
    else:
        log.warning(f"aws_ssm_plugin: no version pinned in {VERSIONS_FILE}")

    if changes:
        log.info("Summary of changes:")
        for label, old, new in changes:
            log.info(f"  - {label}: {old} -> {new}")
    else:
        log.info("All versions are up to date.")

    log.info("Done!")

    if changes:
        print()
        for label, old, new in changes:
            print(f"- {label}: {old} -> {new}")

    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except urllib.error.URLError as e:
        log.error(f"network error: {e}")
        sys.exit(1)
    except KeyboardInterrupt:
        sys.exit(130)
