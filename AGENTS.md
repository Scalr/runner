# runner

`scalr/runner` runs Terraform and OpenTofu tasks, including tasks in the self-hosted Scalr agent. Docker Hub variants: `full`, `python39`, `slim`.

## Changelog

Update [CHANGELOG.md](CHANGELOG.md) during development for changes that affect image users:

- Include changes to the base image, Python, CLI tools, system packages, variants, tags, runtime behavior, and bundled software security.
- Skip CI, registry mirrors, repository tools, documentation, and refactors that leave the image unchanged.

Describe the effect on users.

### Format

- Add entries to the top release section. If its git tag exists, start the next version.
- Heading: `## [X.Y.Z](https://github.com/Scalr/runner/tree/X.Y.Z) (Unreleased)`.
- End each section with a compare link: `[Full Changelog](https://github.com/Scalr/runner/compare/<previous>...X.Y.Z)`.
- Use sections in this order: `Added`, `Changed`, `Deprecated`, `Removed`, `Fixed`, `Security`. Omit empty sections.
- Show upgrades as `old → new`. Keep upstream version prefixes, such as `v1.37.1`.
- List CLI upgrades under `Updated CLI tools to latest versions:` as nested bullets.
- Include the image reference and pinned snapshot digest for base image changes.
- For patched or custom-built dependencies, name what was patched and the patched versions.

## Release

The git tag sets the version. Use `X.Y.Z` without a `v` prefix.

1. Merge release changes into `main`. Add required changelog entries under `(Unreleased)`.
2. Open a PR to replace `Unreleased` with today's date (`YYYY-MM-DD`). Check that the heading and compare link match the release version.
3. After the PR merges, tag its merge commit on `main` and push the tag: `git tag X.Y.Z <merge-commit>` and `git push origin X.Y.Z`.

The tag runs [release.yaml](.github/workflows/release.yaml) to publish all variants to Docker Hub and GAR mirrors. GAR also gets `v`-prefixed aliases.

## Markdown Style

Write in [Simplified Technical English](https://www.asd-ste100.org/) (ASD-STE100). Use short sentences, simple words, active voice and one meaning for each word.
