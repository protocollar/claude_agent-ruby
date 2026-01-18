# Release Conventions

Guidelines for versioning and releasing the claude_agent gem.

## Semantic Versioning

Follow [Semantic Versioning 2.0.0](https://semver.org/):

| Version Part | When to Increment                  | Example           |
|--------------|------------------------------------|-------------------|
| **MAJOR**    | Breaking API changes               | `1.0.0` → `2.0.0` |
| **MINOR**    | New features (backward compatible) | `1.0.0` → `1.1.0` |
| **PATCH**    | Bug fixes (backward compatible)    | `1.0.0` → `1.0.1` |

## Changelog Format

Follow [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format. Maintain an `[Unreleased]` section at the top for work in progress.

## Release Process

### Prerequisites

1. All tests pass (`bundle exec rake`)
2. CHANGELOG.md has entry for the new version
3. You have push access to main branch
4. You have RubyGems publish credentials configured

### Release Command

```bash
bin/release VERSION
```

Example:
```bash
bin/release 1.2.0
```

### What the Script Does

1. Validates version format (semantic versioning)
2. Checks CHANGELOG.md has entry for version
3. Checks tag doesn't already exist
4. Updates `lib/claude_agent/version.rb`
5. Updates `Gemfile.lock`
6. Commits with message "Bump version for X.Y.Z"
7. Pushes to current branch
8. Creates and pushes tag `vX.Y.Z`
9. Builds and publishes gem to RubyGems

### Example Workflow

```bash
# 1. Ensure tests pass
bundle exec rake

# 2. Update CHANGELOG.md
# Move items from [Unreleased] to new version section:
## [1.2.0] - 2025-03-15

### Added
- New feature description

# 3. Commit changelog
git add CHANGELOG.md
git commit -m "docs: update changelog for 1.2.0"
git push

# 4. Release
bin/release 1.2.0
```

### Post-Release

1. Add `## [Unreleased]` section to CHANGELOG.md if needed
2. Optionally create a GitHub release at the new tag

## Version Bumping Guidelines

### When to Bump MAJOR (Breaking)

- Removing public methods/classes
- Changing method signatures (required params)
- Changing return types
- Dropping Ruby version support

### When to Bump MINOR (Feature)

- Adding new public methods/classes
- Adding optional parameters
- New configuration options
- New message types or content blocks

### When to Bump PATCH (Fix)

- Bug fixes
- Documentation corrections
- Performance improvements (no API change)
