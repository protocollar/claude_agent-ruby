# Release Conventions

Guidelines for versioning and releasing the claude_agent gem.

## Semantic Versioning

Follow [Semantic Versioning 2.0.0](https://semver.org/):

| Version Part | When to Increment                  | Example           |
|--------------|------------------------------------|-------------------|
| **MAJOR**    | Breaking API changes               | `1.0.0` → `2.0.0` |
| **MINOR**    | New features (backward compatible) | `1.0.0` → `1.1.0` |
| **PATCH**    | Bug fixes (backward compatible)    | `1.0.0` → `1.0.1` |

### Pre-release Versions

For beta/alpha releases, append a pre-release identifier:

```
1.0.0-alpha.1
1.0.0-beta.1
1.0.0-rc.1
```

## Changelog Format

Follow [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format:

```markdown
## [Unreleased]

## [1.2.0] - 2025-03-15

### Added
- New feature description

### Changed
- Modified behavior description

### Deprecated
- Feature scheduled for removal

### Removed
- Deleted feature description

### Fixed
- Bug fix description

### Security
- Security patch description
```

### Changelog Guidelines

1. **Maintain [Unreleased]** - Always keep an Unreleased section at the top
2. **Add entries as you work** - Don't wait until release time
3. **User-focused language** - Write for gem users, not developers
4. **Link to issues/PRs** - Reference GitHub issues when relevant
5. **Newest first** - Most recent version at top

### What to Include

| Include | Exclude |
|---------|---------|
| API additions/changes | Internal refactors |
| Bug fixes users might hit | Code style changes |
| Deprecation notices | Test-only changes |
| Breaking changes (prominent) | Documentation typos |
| Security fixes | Dependency updates (minor) |

## Release Process

### Prerequisites

Before releasing:

1. All tests pass (`bundle exec rake`)
2. CHANGELOG.md has entry for new version
3. No uncommitted changes
4. On `main` branch (or confirm if not)

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
3. Updates `lib/claude_agent/version.rb`
4. Updates `Gemfile.lock`
5. Commits with message "Release vX.Y.Z"
6. Creates annotated tag `vX.Y.Z`
7. Pushes commit and tag to remote
8. Builds and publishes gem to RubyGems

### Post-Release

After running `bin/release`:

1. Create GitHub release at the new tag
2. Add `## [Unreleased]` section to CHANGELOG.md

## Version Bumping Guidelines

### When to Bump MAJOR (Breaking)

- Removing public methods/classes
- Changing method signatures (required params)
- Changing return types
- Renaming public constants
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
- Internal refactoring (no API change)

## Example Release Workflow

```bash
# 1. Ensure tests pass
bundle exec rake

# 2. Update CHANGELOG.md
# Add entry under [Unreleased], then rename to version:
## [1.2.0] - 2025-03-15

### Added
- New `Client#foo` method for bar functionality

### Fixed
- Resolved timeout issue in subprocess transport

# 3. Commit changelog
git add CHANGELOG.md
git commit -m "docs: update changelog for 1.2.0"

# 4. Release
bin/release 1.2.0

# 5. Add new Unreleased section
# Edit CHANGELOG.md to add:
## [Unreleased]

# 6. Commit
git add CHANGELOG.md
git commit -m "docs: add unreleased section"
git push
```

## Gem Metadata

The gemspec includes these URIs for RubyGems.org:

```ruby
spec.metadata["source_code_uri"] = spec.homepage
spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
```

This enables the "Changelog" link on the RubyGems.org gem page.
