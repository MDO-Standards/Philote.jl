# Release Process

This document describes how to create releases for Philote.jl.

## Overview

Releases are automated via GitHub Actions and triggered by merging pull requests with specific labels.

## Release Types

### Stable Release
Create a stable release by adding these labels to your PR:
- `release` (required)
- One of: `major`, `minor`, or `patch` (required)

Example: PR with labels `release` + `minor` will create version `0.2.0` (if current is `0.1.x`)

### Prerelease
Create a prerelease by adding these labels to your PR:
- `prerelease` (required)
- One of: `major`, `minor`, or `patch` (required)
- One of: `alpha`, `beta`, or `rc` (required)

Example: PR with labels `prerelease` + `minor` + `beta` will create version `0.2.0-beta.1`

## Version Bumping

The workflow automatically calculates the new version based on labels:

- **major**: Increments major version (1.0.0 → 2.0.0), resets minor and patch to 0
- **minor**: Increments minor version (0.1.0 → 0.2.0), resets patch to 0
- **patch**: Increments patch version (0.1.0 → 0.1.1)

For prereleases, the prerelease number is automatically incremented if a prerelease of that type already exists for the version.

## What the Workflow Does

When a labeled PR is merged to `main`, the workflow:

1. **Validates labels**: Ensures correct combination of labels
2. **Calculates new version**: Based on current version and labels
3. **Updates Project.toml**: Changes the `version` field
4. **Updates CHANGELOG.md**: 
   - For stable releases: Renames [Unreleased] to new version, adds new [Unreleased] section
   - For prereleases: Adds new version section after [Unreleased]
5. **Commits changes**: Pushes updated files to `main`
6. **Creates git tag**: Tags the commit with `vX.Y.Z`
7. **Creates GitHub Release**: With changelog content

## CI/CD Pipeline

### On every push/PR to main:
1. **Lint**: Checks code formatting with JuliaFormatter
2. **Build & Test**: Tests on Julia 1.6 (LTS), 1.9, and latest on Ubuntu, macOS, Windows
3. **Coverage**: Uploads coverage reports

### On labeled PR merge:
4. **Release**: Automated version bump and release creation

## Example Workflow

### Creating a minor release (0.1.0 → 0.2.0)

1. Create a PR with your changes
2. Add labels: `release`, `minor`
3. Get PR reviewed and approved
4. Merge PR to `main`
5. GitHub Actions automatically:
   - Updates version to `0.2.0` in Project.toml
   - Updates CHANGELOG.md
   - Creates tag `v0.2.0`
   - Creates GitHub release

### Creating a beta prerelease (0.1.0 → 0.2.0-beta.1)

1. Create a PR with your changes
2. Add labels: `prerelease`, `minor`, `beta`
3. Merge PR to `main`
4. GitHub Actions automatically:
   - Updates version to `0.2.0-beta.1` in Project.toml
   - Updates CHANGELOG.md
   - Creates tag `v0.2.0-beta.1`
   - Creates GitHub prerelease

## Label Reference

### Release Type (choose one)
- `release`: Create a stable release
- `prerelease`: Create a prerelease

### Version Bump (choose one)
- `major`: X.0.0 (breaking changes)
- `minor`: 0.X.0 (new features, backwards compatible)
- `patch`: 0.0.X (bug fixes)

### Prerelease Type (required if using `prerelease`)
- `alpha`: Early testing version
- `beta`: Feature complete, testing version
- `rc`: Release candidate

## Changelog Format

The CHANGELOG.md follows [Keep a Changelog](https://keepachangelog.com/) format:

```markdown
## [Unreleased]
### Added
- New features go here

### Changed
- Changes to existing functionality

### Fixed
- Bug fixes

## [1.0.0] - 2024-11-06
### Added
- Initial stable release
```

When creating a PR, add your changes to the `[Unreleased]` section. The release workflow will automatically move it to the versioned section.

## Troubleshooting

### "Must have exactly one of 'major', 'minor', or 'patch' label"
You need to specify exactly one version bump type.

### "Prerelease must have exactly one of 'alpha', 'beta', or 'rc' label"
If using `prerelease`, you must specify the prerelease type.

### "Cannot have both 'release' and 'prerelease' labels"
Remove one of these labels - you can only have one release type.

### "Stable release cannot have prerelease type labels"
Remove `alpha`, `beta`, or `rc` labels when creating a stable `release`.

## Requirements

- `GITHUB_TOKEN`: Automatically provided by GitHub Actions (no setup needed)
- Protected main branch: Recommended to prevent accidental pushes
- PR reviews: Recommended to ensure quality before releases
