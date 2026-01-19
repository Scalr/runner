#!/usr/bin/env bash
#
# Script to bump all versions in ./versions file from their upstream sources.
#
set -euo pipefail

VERSIONS_FILE="./versions"
README_FILE="./README.md"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check required tools
for cmd in curl jq; do
    if ! command -v "$cmd" &> /dev/null; then
        log_error "$cmd is required but not installed."
        exit 1
    fi
done

# Function to get current version from versions file
get_current_version() {
    local key="$1"
    grep "^${key}=" "$VERSIONS_FILE" | cut -d'=' -f2
}

# Function to update version in versions file
update_version() {
    local key="$1"
    local new_version="$2"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/^${key}=.*/${key}=${new_version}/" "$VERSIONS_FILE"
    else
        sed -i "s/^${key}=.*/${key}=${new_version}/" "$VERSIONS_FILE"
    fi
}

# Function to update version in README.md (docker build args)
update_readme_version() {
    local build_arg="$1"
    local new_version="$2"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/--build-arg ${build_arg}=[^ ]*/--build-arg ${build_arg}=${new_version}/" "$README_FILE"
    else
        sed -i "s/--build-arg ${build_arg}=[^ ]*/--build-arg ${build_arg}=${new_version}/" "$README_FILE"
    fi
}

# Function to update Python version in Included Tools section
# Format: Python ([v3.13.3](https://www.python.org/downloads/release/python-3133/))
update_readme_python() {
    local new_version="$1"
    local version_no_dots="${new_version//./}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' -E "s|Python \(\[v[0-9.]+\]\(https://www\.python\.org/downloads/release/python-[0-9]+/\)\)|Python ([v${new_version}](https://www.python.org/downloads/release/python-${version_no_dots}/))|" "$README_FILE"
    else
        sed -i -E "s|Python \(\[v[0-9.]+\]\(https://www\.python\.org/downloads/release/python-[0-9]+/\)\)|Python ([v${new_version}](https://www.python.org/downloads/release/python-${version_no_dots}/))|" "$README_FILE"
    fi
}

# Function to update AWS CLI version in Included Tools section
# Format: AWS CLI ([2.27.1](https://github.com/aws/aws-cli/releases/tag/2.27.32))
update_readme_aws() {
    local new_version="$1"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' -E "s|AWS CLI \(\[[0-9.]+\]\(https://github\.com/aws/aws-cli/releases/tag/[0-9.]+\)\)|AWS CLI ([${new_version}](https://github.com/aws/aws-cli/releases/tag/${new_version}))|" "$README_FILE"
    else
        sed -i -E "s|AWS CLI \(\[[0-9.]+\]\(https://github\.com/aws/aws-cli/releases/tag/[0-9.]+\)\)|AWS CLI ([${new_version}](https://github.com/aws/aws-cli/releases/tag/${new_version}))|" "$README_FILE"
    fi
}

# Function to update Azure CLI version in Included Tools section
# Format: Azure CLI ([2.71.0](https://github.com/Azure/azure-cli/releases/tag/azure-cli-2.74.0))
update_readme_azure() {
    local new_version="$1"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' -E "s|Azure CLI \(\[[0-9.]+\]\(https://github\.com/Azure/azure-cli/releases/tag/azure-cli-[0-9.]+\)\)|Azure CLI ([${new_version}](https://github.com/Azure/azure-cli/releases/tag/azure-cli-${new_version}))|" "$README_FILE"
    else
        sed -i -E "s|Azure CLI \(\[[0-9.]+\]\(https://github\.com/Azure/azure-cli/releases/tag/azure-cli-[0-9.]+\)\)|Azure CLI ([${new_version}](https://github.com/Azure/azure-cli/releases/tag/azure-cli-${new_version}))|" "$README_FILE"
    fi
}

# Function to update Google Cloud SDK version in Included Tools section
# Format: Google Cloud SDK ([525.0.0](https://cloud.google.com/sdk/docs/release-notes#52500_2025-06-03))
update_readme_gcloud() {
    local new_version="$1"
    local version_no_dots="${new_version//./}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' -E "s|Google Cloud SDK \(\[[0-9.]+\]\(https://cloud\.google\.com/sdk/docs/release-notes#[^)]+\)\)|Google Cloud SDK ([${new_version}](https://cloud.google.com/sdk/docs/release-notes#${version_no_dots}))|" "$README_FILE"
    else
        sed -i -E "s|Google Cloud SDK \(\[[0-9.]+\]\(https://cloud\.google\.com/sdk/docs/release-notes#[^)]+\)\)|Google Cloud SDK ([${new_version}](https://cloud.google.com/sdk/docs/release-notes#${version_no_dots}))|" "$README_FILE"
    fi
}

# Function to update Kubectl version in Included Tools section
# Format: Kubectl ([0.33.1](https://github.com/kubernetes/kubectl/releases/tag/v0.33.1))
# Note: kubectl repo uses v0.x.y versioning matching k8s minor version
update_readme_kubectl() {
    local new_version="$1"  # e.g., v1.35.0
    # Convert v1.35.0 to 0.35.0 for kubectl repo versioning
    local kubectl_version="${new_version//v1./0.}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' -E "s|Kubectl \(\[[0-9.]+\]\(https://github\.com/kubernetes/kubectl/releases/tag/v[0-9.]+\)\)|Kubectl ([${kubectl_version}](https://github.com/kubernetes/kubectl/releases/tag/v${kubectl_version}))|" "$README_FILE"
    else
        sed -i -E "s|Kubectl \(\[[0-9.]+\]\(https://github\.com/kubernetes/kubectl/releases/tag/v[0-9.]+\)\)|Kubectl ([${kubectl_version}](https://github.com/kubernetes/kubectl/releases/tag/v${kubectl_version}))|" "$README_FILE"
    fi
}

# Function to update Scalr CLI version in Included Tools section
# Format: Scalr CLI ([0.17.1](https://github.com/Scalr/scalr-cli/releases/tag/v0.17.1))
update_readme_scalr() {
    local new_version="$1"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' -E "s|Scalr CLI \(\[[0-9.]+\]\(https://github\.com/Scalr/scalr-cli/releases/tag/v[0-9.]+\)\)|Scalr CLI ([${new_version}](https://github.com/Scalr/scalr-cli/releases/tag/v${new_version}))|" "$README_FILE"
    else
        sed -i -E "s|Scalr CLI \(\[[0-9.]+\]\(https://github\.com/Scalr/scalr-cli/releases/tag/v[0-9.]+\)\)|Scalr CLI ([${new_version}](https://github.com/Scalr/scalr-cli/releases/tag/v${new_version}))|" "$README_FILE"
    fi
}

# Fetch latest kubectl version
get_latest_kubectl() {
    curl -sL https://dl.k8s.io/release/stable.txt
}

# Fetch latest gcloud version
get_latest_gcloud() {
    # Get latest version from Google Cloud SDK release notes page
    curl -sL "https://cloud.google.com/sdk/docs/release-notes" 2>/dev/null | \
        grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo ""
}

# Fetch latest AWS CLI v2 version
get_latest_aws_cli() {
    curl -sL "https://api.github.com/repos/aws/aws-cli/tags" | \
        jq -r '.[].name | select(startswith("2."))' | head -1
}

# Fetch latest Azure CLI version
get_latest_azure_cli() {
    curl -sL "https://api.github.com/repos/Azure/azure-cli/releases/latest" | \
        jq -r '.tag_name' | sed 's/^azure-cli-//'
}

# Fetch latest Scalr CLI version
get_latest_scalr_cli() {
    curl -sL "https://api.github.com/repos/Scalr/scalr-cli/releases/latest" | \
        jq -r '.tag_name' | sed 's/^v//'
}

# Fetch latest Python version and release from python-build-standalone
# Returns: "version release" (e.g., "3.13.11 20260114")
get_latest_python_info() {
    local release_info
    release_info=$(curl -sL "https://api.github.com/repos/astral-sh/python-build-standalone/releases/latest")
    local version release
    version=$(echo "$release_info" | jq -r '.assets[].name' | grep -oE 'cpython-3\.13\.[0-9]+' | sed 's/cpython-//' | head -1)
    release=$(echo "$release_info" | jq -r '.tag_name')
    echo "$version $release"
}

# Track changes (compatible with bash 3.x)
CHANGES=""
CHANGES_COUNT=0

add_change() {
    local key="$1"
    local old_ver="$2"
    local new_ver="$3"
    if [[ -n "$CHANGES" ]]; then
        CHANGES="${CHANGES}|${key}:${old_ver}:${new_ver}"
    else
        CHANGES="${key}:${old_ver}:${new_ver}"
    fi
    CHANGES_COUNT=$((CHANGES_COUNT + 1))
}

log_info "Fetching latest versions..."

# Kubectl
CURRENT_KUBECTL=$(get_current_version "kubectl")
LATEST_KUBECTL=$(get_latest_kubectl)
if [[ -n "$LATEST_KUBECTL" && "$CURRENT_KUBECTL" != "$LATEST_KUBECTL" ]]; then
    log_info "kubectl: $CURRENT_KUBECTL -> $LATEST_KUBECTL"
    update_version "kubectl" "$LATEST_KUBECTL"
    update_readme_version "KUBECTL_VERSION" "$LATEST_KUBECTL"
    update_readme_kubectl "$LATEST_KUBECTL"
    add_change "kubectl" "$CURRENT_KUBECTL" "$LATEST_KUBECTL"
else
    log_info "kubectl: $CURRENT_KUBECTL (up to date)"
fi

# GCloud
CURRENT_GCLOUD=$(get_current_version "gcloud")
LATEST_GCLOUD=$(get_latest_gcloud)
if [[ -n "$LATEST_GCLOUD" && "$CURRENT_GCLOUD" != "$LATEST_GCLOUD" ]]; then
    log_info "gcloud: $CURRENT_GCLOUD -> $LATEST_GCLOUD"
    update_version "gcloud" "$LATEST_GCLOUD"
    update_readme_version "GCLOUD_VERSION" "$LATEST_GCLOUD"
    update_readme_gcloud "$LATEST_GCLOUD"
    add_change "gcloud" "$CURRENT_GCLOUD" "$LATEST_GCLOUD"
else
    log_info "gcloud: $CURRENT_GCLOUD (up to date)"
fi

# AWS CLI
CURRENT_AWS=$(get_current_version "aws_cli")
LATEST_AWS=$(get_latest_aws_cli)
if [[ -n "$LATEST_AWS" && "$CURRENT_AWS" != "$LATEST_AWS" ]]; then
    log_info "aws_cli: $CURRENT_AWS -> $LATEST_AWS"
    update_version "aws_cli" "$LATEST_AWS"
    update_readme_version "AWS_CLI_VERSION" "$LATEST_AWS"
    update_readme_aws "$LATEST_AWS"
    add_change "aws_cli" "$CURRENT_AWS" "$LATEST_AWS"
else
    log_info "aws_cli: $CURRENT_AWS (up to date)"
fi

# Azure CLI
CURRENT_AZURE=$(get_current_version "azure_cli")
LATEST_AZURE=$(get_latest_azure_cli)
if [[ -n "$LATEST_AZURE" && "$CURRENT_AZURE" != "$LATEST_AZURE" ]]; then
    log_info "azure_cli: $CURRENT_AZURE -> $LATEST_AZURE"
    update_version "azure_cli" "$LATEST_AZURE"
    update_readme_version "AZURE_CLI_VERSION" "$LATEST_AZURE"
    update_readme_azure "$LATEST_AZURE"
    add_change "azure_cli" "$CURRENT_AZURE" "$LATEST_AZURE"
else
    log_info "azure_cli: $CURRENT_AZURE (up to date)"
fi

# Scalr CLI
CURRENT_SCALR=$(get_current_version "scalr_cli")
LATEST_SCALR=$(get_latest_scalr_cli)
if [[ -n "$LATEST_SCALR" && "$CURRENT_SCALR" != "$LATEST_SCALR" ]]; then
    log_info "scalr_cli: $CURRENT_SCALR -> $LATEST_SCALR"
    update_version "scalr_cli" "$LATEST_SCALR"
    update_readme_version "SCALR_CLI_VERSION" "$LATEST_SCALR"
    update_readme_scalr "$LATEST_SCALR"
    add_change "scalr_cli" "$CURRENT_SCALR" "$LATEST_SCALR"
else
    log_info "scalr_cli: $CURRENT_SCALR (up to date)"
fi

# Python (version and release)
CURRENT_PYTHON=$(get_current_version "python")
CURRENT_PYTHON_RELEASE=$(get_current_version "python_release")
read -r LATEST_PYTHON LATEST_PYTHON_RELEASE <<< "$(get_latest_python_info)"
if [[ -n "$LATEST_PYTHON" && "$CURRENT_PYTHON" != "$LATEST_PYTHON" ]]; then
    log_info "python: $CURRENT_PYTHON -> $LATEST_PYTHON"
    update_version "python" "$LATEST_PYTHON"
    update_readme_version "PYTHON_VERSION" "$LATEST_PYTHON"
    update_readme_python "$LATEST_PYTHON"
    add_change "python" "$CURRENT_PYTHON" "$LATEST_PYTHON"
else
    log_info "python: $CURRENT_PYTHON (up to date)"
fi
if [[ -n "$LATEST_PYTHON_RELEASE" && "$CURRENT_PYTHON_RELEASE" != "$LATEST_PYTHON_RELEASE" ]]; then
    log_info "python_release: $CURRENT_PYTHON_RELEASE -> $LATEST_PYTHON_RELEASE"
    update_version "python_release" "$LATEST_PYTHON_RELEASE"
    update_readme_version "PYTHON_RELEASE" "$LATEST_PYTHON_RELEASE"
    add_change "python_release" "$CURRENT_PYTHON_RELEASE" "$LATEST_PYTHON_RELEASE"
else
    log_info "python_release: $CURRENT_PYTHON_RELEASE (up to date)"
fi

# Print summary
if [[ $CHANGES_COUNT -gt 0 ]]; then
    echo ""
    log_info "Summary of changes:"
    IFS='|' read -ra CHANGE_ARRAY <<< "$CHANGES"
    for change in "${CHANGE_ARRAY[@]}"; do
        IFS=':' read -ra PARTS <<< "$change"
        echo "  - ${PARTS[0]}: ${PARTS[1]} -> ${PARTS[2]}"
    done
else
    log_info "All versions are up to date."
fi

echo ""
log_info "Done!"
