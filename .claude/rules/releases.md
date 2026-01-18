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

Follow [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format. Add changes to the `[Unreleased]` section as you work. The release script will automatically move them to a versioned section.

## Release Process

### Prerequisites

1. All tests pass (`bundle exec rake`)
2. Changes documented in `[Unreleased]` section of CHANGELOG.md
3. You have push access to the repository
4. Trusted Publishing configured on RubyGems (one-time setup)

### Step 1: Prepare Release PR

```bash
bin/release 1.2.0
```

This will:
1. Create branch `release-1.2.0`
2. Update `lib/claude_agent/version.rb`
3. Update `Gemfile.lock`
4. Move `[Unreleased]` changelog entries to `[1.2.0]`
5. Commit, push, and open a PR

### Step 2: Review and Merge

- Review the release PR
- Ensure CI passes
- Merge to main

### Step 3: Publish

```bash
git checkout main && git pull
bin/publish 1.2.0
```

This will:
1. Verify you're on main with correct version
2. Create and push tag `v1.2.0`
3. Create GitHub release
4. GitHub Actions publishes to RubyGems automatically

### Workflow Diagram

```
bin/release 1.2.0
       │
       ├── Creates branch: release-1.2.0
       ├── Updates version.rb, Gemfile.lock, CHANGELOG.md
       ├── Commits and pushes
       └── Opens PR
              │
              ▼
       [Review & merge PR]
              │
              ▼
bin/publish 1.2.0
       │
       ├── Creates tag v1.2.0
       ├── Pushes tag
       └── Creates GitHub release
              │
              ▼
       [GitHub Actions]
              │
              └── Publishes to RubyGems via Trusted Publishing
```

## Setting Up Trusted Publishing (One-Time)

1. Go to [rubygems.org](https://rubygems.org) → Your gems → claude_agent → Trusted Publishers
2. Add a new publisher:
   - Repository owner: `protocollar`
   - Repository name: `claude_agent-ruby`
   - Workflow filename: `push_gem.yml`
   - Environment: `release`
3. Create a GitHub environment named `release` in your repository settings

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